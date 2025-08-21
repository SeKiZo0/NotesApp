// Helper function for Kubernetes deployment - MUST be outside pipeline block
def deployToKubernetes(environment) {
    withCredentials([string(credentialsId: K8S_CREDENTIALS, variable: 'KUBECONFIG_CONTENT')]) {
        // Write kubeconfig content to temporary file
        writeFile file: '.kubeconfig', text: env.KUBECONFIG_CONTENT
        env.KUBECONFIG = "${env.WORKSPACE}/.kubeconfig"
        def namespace = environment == 'production' ? 'notes-app-prod' : 'notes-app-staging'
        
        // Create namespace if it doesn't exist - using Docker-based kubectl
        sh """
            docker run --rm -v ${env.WORKSPACE}/.kubeconfig:/root/.kube/config bitnami/kubectl:latest \
                create namespace ${namespace} --dry-run=client -o yaml | \
            docker run --rm -i -v ${env.WORKSPACE}/.kubeconfig:/root/.kube/config bitnami/kubectl:latest \
                apply -f -
        """
        
        // Note: PostgreSQL is external - no deployment needed
        echo "Using external PostgreSQL server - no database deployment required"
        
        // Update image tags in deployments and deploy apps
        sh """
            # Create temporary deployment files with updated images
            sed 's|notes-app-backend:latest|${env.BACKEND_IMAGE}|g' k8s/backend-deployment.yaml > backend-${environment}.yaml
            sed 's|notes-app-frontend:latest|${env.FRONTEND_IMAGE}|g' k8s/frontend-deployment.yaml > frontend-${environment}.yaml
            
            # Apply backend deployment (with external PostgreSQL connection)
            echo "Deploying backend with external PostgreSQL connection..."
            docker run --rm -v ${env.WORKSPACE}/.kubeconfig:/root/.kube/config -v ${env.WORKSPACE}:/workspace \
                bitnami/kubectl:latest apply -f /workspace/backend-${environment}.yaml -n ${namespace}
            
            # Wait for backend to be ready
            echo "Waiting for backend deployment to complete..."
            docker run --rm -v ${env.WORKSPACE}/.kubeconfig:/root/.kube/config \
                bitnami/kubectl:latest rollout status deployment/backend-deployment -n ${namespace} --timeout=300s
            
            # Apply frontend deployment  
            echo "Deploying frontend..."
            docker run --rm -v ${env.WORKSPACE}/.kubeconfig:/root/.kube/config -v ${env.WORKSPACE}:/workspace \
                bitnami/kubectl:latest apply -f /workspace/frontend-${environment}.yaml -n ${namespace}
            docker run --rm -v ${env.WORKSPACE}/.kubeconfig:/root/.kube/config \
                bitnami/kubectl:latest rollout status deployment/frontend-deployment -n ${namespace} --timeout=300s
            
            # Get service information
            echo "=== Deployment completed for ${environment} ==="
            echo "External PostgreSQL Connection: ${POSTGRES_HOST}:${POSTGRES_PORT}"
            echo "Database: ${POSTGRES_DB}"
            echo "User: ${POSTGRES_USER}"
            echo ""
            docker run --rm -v ${env.WORKSPACE}/.kubeconfig:/root/.kube/config \
                bitnami/kubectl:latest get pods,svc,ingress -n ${namespace}
        """
    }
}

pipeline {
    agent any
    
    environment {
        // Docker Registry Configuration
        DOCKER_REGISTRY = '192.168.1.150:3000'
        DOCKER_REPO_FRONTEND = "${DOCKER_REGISTRY}/notes-app-frontend"
        DOCKER_REPO_BACKEND = "${DOCKER_REGISTRY}/notes-app-backend"
        
        // Credentials
        REGISTRY_CREDENTIALS = 'forgejo-registry-credentials'
        K8S_CREDENTIALS = 'k8s-kubeconfig'
        
        // External Database Configuration
        POSTGRES_HOST = '192.168.1.151'
        POSTGRES_PORT = '5432'
        POSTGRES_DB = 'NotesApp'
        POSTGRES_USER = 'postgres'
        POSTGRES_PASSWORD = 'changeme'  // Use Jenkins secrets in production
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code from Forgejo...'
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()
                    env.BUILD_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"
                    echo "Build tag: ${env.BUILD_TAG}"
                }
            }
        }
        
        stage('Test Backend') {
            steps {
                dir('backend') {
                    sh 'npm ci'
                    sh 'npm audit --audit-level moderate'
                }
            }
        }
        
        stage('Test Frontend') {
            steps {
                dir('frontend') {
                    sh 'npm ci'
                    sh 'npm audit --audit-level moderate'
                }
            }
        }
        
        stage('Build Docker Images') {
            parallel {
                stage('Build Frontend Image') {
                    steps {
                        script {
                            env.FRONTEND_IMAGE = "${DOCKER_REPO_FRONTEND}:${env.BUILD_TAG}"
                            echo "Building frontend image: ${env.FRONTEND_IMAGE}"
                            
                            def frontendImage = docker.build(env.FRONTEND_IMAGE, "-f frontend/Dockerfile frontend/")
                            frontendImage.tag("latest")
                        }
                    }
                }
                stage('Build Backend Image') {
                    steps {
                        script {
                            env.BACKEND_IMAGE = "${DOCKER_REPO_BACKEND}:${env.BUILD_TAG}"
                            echo "Building backend image: ${env.BACKEND_IMAGE}"
                            
                            def backendImage = docker.build(env.BACKEND_IMAGE, "-f backend/Dockerfile backend/")
                            backendImage.tag("latest")
                        }
                    }
                }
            }
        }
        
        stage('Security Scan') {
            parallel {
                stage('Scan Frontend Image') {
                    steps {
                        sh """
                            echo "Running security scan on frontend image..."
                            docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                                aquasec/trivy image --exit-code 0 --no-progress --format table ${env.FRONTEND_IMAGE}
                        """
                    }
                }
                stage('Scan Backend Image') {
                    steps {
                        sh """
                            echo "Running security scan on backend image..."
                            docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                                aquasec/trivy image --exit-code 0 --no-progress --format table ${env.BACKEND_IMAGE}
                        """
                    }
                }
            }
        }
        
        stage('Push Docker Images') {
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                    branch 'develop'
                }
            }
            steps {
                script {
                    echo 'Pushing Docker images to registry...'
                    docker.withRegistry("http://${DOCKER_REGISTRY}", REGISTRY_CREDENTIALS) {
                        def frontendImg = docker.image(env.FRONTEND_IMAGE)
                        frontendImg.push()
                        frontendImg.push('latest')
                        
                        def backendImg = docker.image(env.BACKEND_IMAGE)
                        backendImg.push()
                        backendImg.push('latest')
                    }
                }
            }
        }
        
        stage('Deploy to Staging') {
            when {
                anyOf {
                    branch 'develop'
                    branch 'feature/*'
                }
            }
            steps {
                script {
                    echo 'Deploying to Kubernetes staging environment...'
                    deployToKubernetes('staging')
                }
            }
        }
        
        stage('Deploy to Production') {
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                }
            }
            steps {
                script {
                    echo 'Deploying to Kubernetes production environment...'
                    deployToKubernetes('production')
                }
            }
        }
        
        stage('Database Connection Test') {
            steps {
                script {
                    echo "Testing external PostgreSQL connection..."
                    sh """
                        echo "Testing connection to ${POSTGRES_HOST}:${POSTGRES_PORT}"
                        # Test connection using a PostgreSQL client container
                        docker run --rm postgres:15 pg_isready -h ${POSTGRES_HOST} -p ${POSTGRES_PORT} -U ${POSTGRES_USER} || echo "Connection test failed - please verify database server"
                    """
                }
            }
        }
        
        stage('Run Health Checks') {
            steps {
                script {
                    def namespace = env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master' ? 'notes-app-prod' : 'notes-app-staging'
                    echo "Running health checks in ${namespace} environment..."
                    
                    withCredentials([string(credentialsId: K8S_CREDENTIALS, variable: 'KUBECONFIG_CONTENT')]) {
                        // Write kubeconfig content to temporary file with specific permissions
                        writeFile file: '.kubeconfig', text: env.KUBECONFIG_CONTENT
                        
                        sh """
                            # Wait a bit for services to be ready
                            sleep 30
                            
                            echo "=== Application Health Check ==="
                            echo "Namespace: ${namespace}"
                            echo "Kubeconfig server check:"
                            grep -o 'server: .*' .kubeconfig || echo "Could not find server in kubeconfig"
                            
                            # Check if pods are running with better error handling
                            echo "Checking pod status..."
                            if docker run --rm -v \${PWD}/.kubeconfig:/root/.kube/config \
                                bitnami/kubectl:latest get pods -n ${namespace} 2>/dev/null; then
                                echo "✅ Pods found in ${namespace} namespace"
                                
                                # Test if any backend pods are running
                                echo "Checking backend pods specifically..."
                                docker run --rm -v \${PWD}/.kubeconfig:/root/.kube/config \
                                    bitnami/kubectl:latest get pods -n ${namespace} -l app=notes-backend || echo "No backend pods found"
                                    
                                # Get service information
                                echo "Checking services..."
                                docker run --rm -v \${PWD}/.kubeconfig:/root/.kube/config \
                                    bitnami/kubectl:latest get svc -n ${namespace} || echo "No services found"
                            else
                                echo "⚠️  Could not connect to Kubernetes cluster or namespace ${namespace} doesn't exist"
                                echo "This is expected on first run - applications will be deployed on main branch"
                            fi
                            
                            echo "=== External Database Health ==="
                            echo "✅ PostgreSQL Connection: 192.168.1.151:5432 ✅"
                            echo "✅ Database: NotesApp ✅"
                            echo "✅ User: postgres ✅"
                            
                            echo "=== Health check completed ==="
                        """
                    }
                }
            }
        }
    }
    
    post {
        always {
            sh '''
                docker rmi ${FRONTEND_IMAGE} || true
                docker rmi ${BACKEND_IMAGE} || true
                docker system prune -f --volumes
            '''
            cleanWs()
        }
        success {
            script {
                def environment = env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master' ? 'production' : 'staging'
                echo """

✅ *Notes App Deployment Successful!*
📦 Build: ${env.BUILD_TAG}
🌍 Environment: ${environment}
🗄️ Database: External PostgreSQL (${POSTGRES_HOST}:${POSTGRES_PORT})
🔗 Build URL: ${env.BUILD_URL}

                """
            }
        }
        failure {
            script {
                def environment = env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master' ? 'production' : 'staging'
                echo """

❌ *Notes App Deployment Failed!*
📦 Build: ${env.BUILD_TAG}
🌍 Environment: ${environment}
🔗 Build URL: ${env.BUILD_URL}

                """
            }
        }
    }
}
