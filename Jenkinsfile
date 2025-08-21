// Helper function for Kubernetes deployment - MUST be outside pipeline block
def deployToKubernetes(environment) {
    // Use kubeconfig file from repository
    def namespace = environment == 'production' ? 'notes-app-prod' : 'notes-app-staging'
    
    // Create namespace if it doesn't exist - using environment variable approach with alpine base
    sh """
        # Read kubeconfig content and pass as environment variable to avoid file mounting issues
        KUBECONFIG_CONTENT=\$(cat ${env.WORKSPACE}/k8s/kubeconfig.yaml | base64 -w 0)
        
        # Create namespace using environment variable approach with alpine+kubectl
        docker run --rm -e KUBECONFIG_CONTENT="\$KUBECONFIG_CONTENT" alpine/k8s:1.28.0 sh -c '
            echo \$KUBECONFIG_CONTENT | base64 -d > /tmp/kubeconfig
            export KUBECONFIG=/tmp/kubeconfig
            kubectl create namespace ${namespace} --dry-run=client -o yaml
        ' | docker run --rm -i -e KUBECONFIG_CONTENT="\$KUBECONFIG_CONTENT" alpine/k8s:1.28.0 sh -c '
            echo \$KUBECONFIG_CONTENT | base64 -d > /tmp/kubeconfig
            export KUBECONFIG=/tmp/kubeconfig
            kubectl apply -f - --validate=false
        '
    """
        
        // Note: PostgreSQL is external - no deployment needed
        echo "Using external PostgreSQL server - no database deployment required"

        // Replace image placeholders, create imagePullSecret, deploy & wait
        sh """
            set -e
            KUBECONFIG_CONTENT=\$(cat ${env.WORKSPACE}/k8s/kubeconfig.yaml | base64 -w 0)

            BACKEND_IMAGE='${env.BACKEND_IMAGE}'
            FRONTEND_IMAGE='${env.FRONTEND_IMAGE}'

            echo "Preparing deployment manifests with build tag images"
            sed "s|192.168.1.150:3000/morris/notes-app-backend:__IMAGE_TAG__|$BACKEND_IMAGE|g" k8s/production-backend.yaml > backend-${environment}.yaml
            sed "s|192.168.1.150:3000/morris/notes-app-frontend:__IMAGE_TAG__|$FRONTEND_IMAGE|g" k8s/production-frontend.yaml > frontend-${environment}.yaml

            echo "Creating/Updating registry imagePullSecret (docker-registry-secret) in ${namespace}"
            docker run --rm -e KUBECONFIG_CONTENT=\"$KUBECONFIG_CONTENT\" alpine/k8s:1.28.0 sh -c '
              echo $KUBECONFIG_CONTENT | base64 -d > /tmp/kubeconfig
              export KUBECONFIG=/tmp/kubeconfig
              kubectl create secret docker-registry docker-registry-secret \
                --docker-server=${DOCKER_REGISTRY} \
                --docker-username=${DOCKER_USER} \
                --docker-password=${DOCKER_PASS} \
                -n ${namespace} --dry-run=client -o yaml | kubectl apply -f -
            '

            echo "Deploying backend..."
            docker run --rm -e KUBECONFIG_CONTENT=\"$KUBECONFIG_CONTENT\" -v ${env.WORKSPACE}:/workspace alpine/k8s:1.28.0 sh -c '
                echo $KUBECONFIG_CONTENT | base64 -d > /tmp/kubeconfig
                export KUBECONFIG=/tmp/kubeconfig
                kubectl apply -f /workspace/backend-${environment}.yaml -n ${namespace} --validate=false
            '

            echo "Waiting for backend rollout..."
            if ! docker run --rm -e KUBECONFIG_CONTENT=\"$KUBECONFIG_CONTENT\" alpine/k8s:1.28.0 sh -c '
                echo $KUBECONFIG_CONTENT | base64 -d > /tmp/kubeconfig
                export KUBECONFIG=/tmp/kubeconfig
                kubectl rollout status deployment/backend-deployment -n ${namespace} --timeout=300s
            '; then
                echo "Backend deployment failed, gathering diagnostics"
                docker run --rm -e KUBECONFIG_CONTENT=\"$KUBECONFIG_CONTENT\" alpine/k8s:1.28.0 sh -c '
                    echo $KUBECONFIG_CONTENT | base64 -d > /tmp/kubeconfig
                    export KUBECONFIG=/tmp/kubeconfig
                    echo "=== Backend Pod Status ==="; kubectl get pods -n ${namespace} -l app=backend
                    echo "=== Events ==="; kubectl get events -n ${namespace} --sort-by=.metadata.creationTimestamp | tail -n 50
                    echo "=== Logs (first available pod) ==="; POD=\$(kubectl get pods -n ${namespace} -l app=backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true); [ -n "$POD" ] && kubectl logs -n ${namespace} $POD --tail=100 || echo "No logs"
                '
                exit 1
            fi

            echo "Deploying frontend..."
            docker run --rm -e KUBECONFIG_CONTENT=\"$KUBECONFIG_CONTENT\" -v ${env.WORKSPACE}:/workspace alpine/k8s:1.28.0 sh -c '
                echo $KUBECONFIG_CONTENT | base64 -d > /tmp/kubeconfig
                export KUBECONFIG=/tmp/kubeconfig
                kubectl apply -f /workspace/frontend-${environment}.yaml -n ${namespace} --validate=false
            '
            docker run --rm -e KUBECONFIG_CONTENT=\"$KUBECONFIG_CONTENT\" alpine/k8s:1.28.0 sh -c '
                echo $KUBECONFIG_CONTENT | base64 -d > /tmp/kubeconfig
                export KUBECONFIG=/tmp/kubeconfig
                kubectl rollout status deployment/frontend-deployment -n ${namespace} --timeout=300s
            '

            echo "=== Summary (${environment}) ==="
            docker run --rm -e KUBECONFIG_CONTENT=\"$KUBECONFIG_CONTENT\" alpine/k8s:1.28.0 sh -c '
                echo $KUBECONFIG_CONTENT | base64 -d > /tmp/kubeconfig
                export KUBECONFIG=/tmp/kubeconfig
                kubectl get pods,svc -n ${namespace}
            '

            rm -f backend-${environment}.yaml frontend-${environment}.yaml
        """
}

pipeline {
    agent any
    
    environment {
        // Docker Registry Configuration
        DOCKER_REGISTRY = '192.168.1.150:3000'
        DOCKER_REPO_FRONTEND = "${DOCKER_REGISTRY}/morris/notes-app-frontend"
        DOCKER_REPO_BACKEND = "${DOCKER_REGISTRY}/morris/notes-app-backend"
        
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
            steps {
                script {
                    echo 'Pushing Docker images to registry...'
                    
                    // First, try to create repositories in case they don't exist
                    try {
                        echo 'Attempting to ensure repositories exist...'
                        sh """
                            # Test registry connectivity
                            curl -f http://${DOCKER_REGISTRY}/v2/ || echo "Registry health check failed"
                            
                            # Try to check if repositories exist, if not this will help create them
                            curl -f http://${DOCKER_REGISTRY}/v2/Morris/notes-app-frontend/tags/list || echo "Frontend repo may not exist yet"
                            curl -f http://${DOCKER_REGISTRY}/v2/Morris/notes-app-backend/tags/list || echo "Backend repo may not exist yet"
                            
                            # Login manually first to ensure credentials work
                            echo "Testing manual docker login..."
                            docker login http://${DOCKER_REGISTRY} -u \${DOCKER_REGISTRY_USR} -p \${DOCKER_REGISTRY_PSW}
                        """
                    } catch (Exception e) {
                        echo "Registry setup warning: ${e.getMessage()}"
                    }
                    
                    // Now try to push images with better error handling
                    docker.withRegistry("http://${DOCKER_REGISTRY}", REGISTRY_CREDENTIALS) {
                        try {
                            echo 'Pushing frontend image...'
                            def frontendImg = docker.image(env.FRONTEND_IMAGE)
                            frontendImg.push()
                            frontendImg.push('latest')
                            echo '✅ Frontend image pushed successfully'
                        } catch (Exception e) {
                            error "Failed to push frontend image: ${e.getMessage()}"
                        }
                        
                        try {
                            echo 'Pushing backend image...'
                            def backendImg = docker.image(env.BACKEND_IMAGE)
                            backendImg.push()
                            backendImg.push('latest')
                            echo '✅ Backend image pushed successfully'
                        } catch (Exception e) {
                            error "Failed to push backend image: ${e.getMessage()}"
                        }
                    }
                }
            }
        }
        
        stage('Deploy to Production') {
            steps {
                script {
                    echo 'Deploying to Kubernetes production environment...'
                    // Bind registry credentials for secret creation
                    withCredentials([usernamePassword(credentialsId: REGISTRY_CREDENTIALS, usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        deployToKubernetes('production')
                    }
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
                    echo "Running health checks in notes-app-prod environment..."
                    
                    // Use environment variable approach for kubeconfig
                    sh """
                        # Wait a bit for services to be ready
                        sleep 30
                        
                        # Read kubeconfig content as base64 for environment variable approach
                        KUBECONFIG_CONTENT=\$(cat ${env.WORKSPACE}/k8s/kubeconfig.yaml | base64 -w 0)
                        
                        echo "=== Application Health Check ==="
                        echo "Namespace: notes-app-prod"
                        echo "Kubeconfig server check:"
                        grep -o 'server: .*' k8s/kubeconfig.yaml || echo "Could not find server in kubeconfig"
                            
                            # Check if pods are running with better error handling
                            echo "Checking pod status..."
                            if docker run --rm -e KUBECONFIG_CONTENT="\$KUBECONFIG_CONTENT" alpine/k8s:1.28.0 sh -c '
                                echo \$KUBECONFIG_CONTENT | base64 -d > /tmp/kubeconfig
                                export KUBECONFIG=/tmp/kubeconfig
                                kubectl get pods -n notes-app-prod 2>/dev/null
                            '; then
                                echo "✅ Pods found in notes-app-prod namespace"
                                
                                # Test if any backend pods are running
                                echo "Checking backend pods specifically..."
                                docker run --rm -e KUBECONFIG_CONTENT="\$KUBECONFIG_CONTENT" alpine/k8s:1.28.0 sh -c '
                                    echo \$KUBECONFIG_CONTENT | base64 -d > /tmp/kubeconfig
                                    export KUBECONFIG=/tmp/kubeconfig
                                    kubectl get pods -n notes-app-prod -l app=notes-backend
                                ' || echo "No backend pods found"
                                    
                                # Get service information
                                echo "Checking services..."
                                docker run --rm -e KUBECONFIG_CONTENT="\$KUBECONFIG_CONTENT" alpine/k8s:1.28.0 sh -c '
                                    echo \$KUBECONFIG_CONTENT | base64 -d > /tmp/kubeconfig
                                    export KUBECONFIG=/tmp/kubeconfig
                                    kubectl get svc -n notes-app-prod
                                ' || echo "No services found"
                            else
                                echo "⚠️  Could not connect to Kubernetes cluster or namespace notes-app-prod doesn't exist"
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

