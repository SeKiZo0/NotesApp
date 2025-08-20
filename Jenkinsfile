// Helper function for Kubernetes deployment - MUST be outside pipeline block
def deployToKubernetes(environment) {
    withCredentials([string(credentialsId: K8S_CREDENTIALS, variable: 'KUBECONFIG_CONTENT')]) {
        def namespace = environment == 'production' ? 'notes-app-prod' : 'notes-app-staging'
        
        // Setup kubeconfig with validation
        sh """
            echo "Setting up kubeconfig for deployment to ${environment}..."
            mkdir -p ~/.kube
            
            # Validate kubeconfig content exists
            if [ -z "\$KUBECONFIG_CONTENT" ]; then
                echo "ERROR: KUBECONFIG_CONTENT is empty. Please check kubernetes-config credential."
                exit 1
            fi
            
            # Decode and validate base64 content
            echo "Decoding kubeconfig content..."
            if ! echo "\$KUBECONFIG_CONTENT" | base64 -d > ~/.kube/config 2>/dev/null; then
                echo "ERROR: Failed to decode kubeconfig. Please ensure the credential contains valid base64 content."
                echo "To create valid content: cat ~/.kube/config | base64 -w 0"
                exit 1
            fi
            
            chmod 600 ~/.kube/config
            
            # Validate kubeconfig format
            if ! kubectl config view --minify >/dev/null 2>&1; then
                echo "ERROR: Invalid kubeconfig format after decoding."
                exit 1
            fi
            
            echo "Kubeconfig setup completed successfully"
        """
        
        // Create namespace if it doesn't exist
        sh "kubectl create namespace ${namespace} --dry-run=client -o yaml | kubectl apply -f -"
        
        // Deploy PostgreSQL (only if not exists)
        sh """
            if ! kubectl get deployment postgres-deployment -n ${namespace} > /dev/null 2>&1; then
                echo "Deploying PostgreSQL to ${environment}..."
                
                # Apply PostgreSQL deployment with secrets
                kubectl apply -f k8s/postgres-deployment.yaml -n ${namespace}
                
                # Wait for PostgreSQL to be ready
                echo "Waiting for PostgreSQL to be available..."
                kubectl wait --for=condition=available --timeout=300s deployment/postgres-deployment -n ${namespace}
                
                # Verify PostgreSQL is accepting connections
                echo "Verifying PostgreSQL connectivity..."
                kubectl exec deployment/postgres-deployment -n ${namespace} -- pg_isready -U postgres
                
                echo "PostgreSQL deployment completed successfully"
            else
                echo "PostgreSQL already deployed in ${environment}"
                
                # Still verify it's healthy
                kubectl exec deployment/postgres-deployment -n ${namespace} -- pg_isready -U postgres
            fi
        """
        
        // Update image tags in deployments
        sh """
            # Create temporary deployment files with updated images
            sed 's|notes-app-backend:latest|${env.BACKEND_IMAGE}|g' k8s/backend-deployment.yaml > backend-${environment}.yaml
            sed 's|notes-app-frontend:latest|${env.FRONTEND_IMAGE}|g' k8s/frontend-deployment.yaml > frontend-${environment}.yaml
            
            # Apply backend deployment (this includes the PostgreSQL connection config)
            echo "Deploying backend with PostgreSQL connection..."
            kubectl apply -f backend-${environment}.yaml -n ${namespace}
            
            # Wait for backend to be ready (it will wait for PostgreSQL via init container)
            echo "Waiting for backend deployment to complete..."
            kubectl rollout status deployment/backend-deployment -n ${namespace} --timeout=300s
            
            # Verify backend can connect to PostgreSQL
            echo "Verifying backend-PostgreSQL connectivity..."
            sleep 15  # Give backend time to initialize
            kubectl exec deployment/backend-deployment -n ${namespace} -- curl -f http://localhost:5000/health
            
            # Apply frontend deployment  
            echo "Deploying frontend..."
            kubectl apply -f frontend-${environment}.yaml -n ${namespace}
            kubectl rollout status deployment/frontend-deployment -n ${namespace} --timeout=300s
            
            # Get service information
            echo "=== Deployment completed for ${environment} ==="
            echo "PostgreSQL Connection Details:"
            echo "  Host: postgres-service.${namespace}.svc.cluster.local"
            echo "  Port: 5432"
            echo "  Database: notesdb"
            echo "  User: postgres"
            echo ""
            kubectl get pods,svc,ingress -n ${namespace}
        """
    }
}

pipeline {
    agent any
    
    environment {
        FORGEJO_REGISTRY = '192.168.1.150:3000'
        PROJECT_NAME = 'notes-app'
        DOCKER_REPO_FRONTEND = "${FORGEJO_REGISTRY}/${PROJECT_NAME}-frontend"
        DOCKER_REPO_BACKEND = "${FORGEJO_REGISTRY}/${PROJECT_NAME}-backend"
        REGISTRY_CREDENTIALS = 'forgejo-registry-credentials'
        K8S_CREDENTIALS = 'k8s-kubeconfig'
        K8S_NAMESPACE = 'notes-app'
        
        // PostgreSQL Configuration
        POSTGRES_DB = 'notesdb'
        POSTGRES_USER = 'postgres'
        POSTGRES_SERVICE = 'postgres-service'
        POSTGRES_PORT = '5432'
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
                    // Add actual tests here when available
                    // sh 'npm test'
                }
            }
        }
        
        stage('Test Frontend') {
            steps {
                dir('frontend') {
                    sh 'npm ci'
                    sh 'npm audit --audit-level moderate'
                    // Add frontend tests here when available
                    // sh 'npm test'
                }
            }
        }
        
        stage('Build Docker Images') {
            parallel {
                stage('Build Frontend Image') {
                    steps {
                        script {
                            echo "Building frontend image: ${DOCKER_REPO_FRONTEND}:${BUILD_TAG}"
                            def frontendImage = docker.build(
                                "${DOCKER_REPO_FRONTEND}:${BUILD_TAG}",
                                "-f Dockerfile.frontend ."
                            )
                            frontendImage.tag("latest")
                            env.FRONTEND_IMAGE = "${DOCKER_REPO_FRONTEND}:${BUILD_TAG}"
                        }
                    }
                }
                stage('Build Backend Image') {
                    steps {
                        script {
                            echo "Building backend image: ${DOCKER_REPO_BACKEND}:${BUILD_TAG}"
                            def backendImage = docker.build(
                                "${DOCKER_REPO_BACKEND}:${BUILD_TAG}",
                                "-f Dockerfile.backend ."
                            )
                            backendImage.tag("latest")
                            env.BACKEND_IMAGE = "${DOCKER_REPO_BACKEND}:${BUILD_TAG}"
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
                            docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                            aquasec/trivy image --exit-code 0 --no-progress \
                            --format table ${DOCKER_REPO_FRONTEND}:${BUILD_TAG}
                        """
                    }
                }
                stage('Scan Backend Image') {
                    steps {
                        sh """
                            docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                            aquasec/trivy image --exit-code 0 --no-progress \
                            --format table ${DOCKER_REPO_BACKEND}:${BUILD_TAG}
                        """
                    }
                }
            }
        }
        
        stage('Push Docker Images') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                    branch 'master'
                }
            }
            steps {
                script {
                    echo 'Pushing images to Forgejo registry...'
                    docker.withRegistry("https://${FORGEJO_REGISTRY}", REGISTRY_CREDENTIALS) {
                        // Push frontend
                        def frontendImg = docker.image("${DOCKER_REPO_FRONTEND}:${BUILD_TAG}")
                        frontendImg.push()
                        frontendImg.push('latest')
                        
                        // Push backend
                        def backendImg = docker.image("${DOCKER_REPO_BACKEND}:${BUILD_TAG}")
                        backendImg.push()
                        backendImg.push('latest')
                        
                        echo "Images pushed successfully:"
                        echo "Frontend: ${DOCKER_REPO_FRONTEND}:${BUILD_TAG}"
                        echo "Backend: ${DOCKER_REPO_BACKEND}:${BUILD_TAG}"
                    }
                }
            }
        }
        
        stage('Deploy to Staging') {
            when {
                anyOf {
                    branch 'develop'
                    branch 'dev'
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
                    // Manual approval for production deployment
                    input message: 'Deploy to production?', ok: 'Deploy',
                          submitterParameter: 'DEPLOYER'
                    
                    echo 'Deploying to Kubernetes production environment...'
                    deployToKubernetes('production')
                }
            }
        }
        
        stage('Database Setup Verification') {
            steps {
                script {
                    def environment = env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master' ? 'production' : 'staging'
                    def namespace = environment == 'production' ? 'notes-app-prod' : 'notes-app-staging'
                    
                    echo "Verifying database setup in ${environment}..."
                    
                    withCredentials([string(credentialsId: K8S_CREDENTIALS, variable: 'KUBECONFIG_CONTENT')]) {
                        // Setup kubeconfig with validation
                        sh """
                            echo "Setting up kubeconfig for database verification..."
                            mkdir -p ~/.kube
                            
                            # Validate kubeconfig content exists
                            if [ -z "\$KUBECONFIG_CONTENT" ]; then
                                echo "ERROR: KUBECONFIG_CONTENT is empty. Please check kubernetes-config credential."
                                exit 1
                            fi
                            
                            # Decode and validate base64 content
                            echo "Decoding kubeconfig content..."
                            if ! echo "\$KUBECONFIG_CONTENT" | base64 -d > ~/.kube/config 2>/dev/null; then
                                echo "ERROR: Failed to decode kubeconfig. Please ensure the credential contains valid base64 content."
                                echo "To create valid content: cat ~/.kube/config | base64 -w 0"
                                exit 1
                            fi
                            
                            chmod 600 ~/.kube/config
                            
                            # Validate kubeconfig format
                            if ! kubectl config view --minify >/dev/null 2>&1; then
                                echo "ERROR: Invalid kubeconfig format after decoding."
                                exit 1
                            fi
                            
                            echo "Kubeconfig setup completed successfully"
                        """
                        sh """
                            # Verify PostgreSQL is running and ready
                            echo "Checking PostgreSQL status..."
                            kubectl get pods -l app=postgres -n ${namespace}
                            
                            # Test PostgreSQL connectivity
                            echo "Testing PostgreSQL connectivity..."
                            kubectl exec deployment/postgres-deployment -n ${namespace} -- psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "SELECT version();"
                            
                            # Verify backend database connection
                            echo "Testing backend database connection..."
                            kubectl exec deployment/backend-deployment -n ${namespace} -- curl -f http://localhost:5000/health
                            
                            # Show database connection details
                            echo "=== Database Connection Summary ==="
                            echo "Environment: ${environment}"
                            echo "Namespace: ${namespace}"
                            echo "PostgreSQL Service: ${POSTGRES_SERVICE}.${namespace}.svc.cluster.local:${POSTGRES_PORT}"
                            echo "Database Name: ${POSTGRES_DB}"
                            echo "Database User: ${POSTGRES_USER}"
                            echo "Backend connects via: ${POSTGRES_SERVICE}:${POSTGRES_PORT}"
                        """
                    }
                }
            }
        }
        
        stage('Run Health Checks') {
            steps {
                script {
                    def namespace = env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master' ? 'notes-app-prod' : 'notes-app-staging'
                    echo "Running health checks in ${namespace} environment..."
                    
                    withCredentials([string(credentialsId: K8S_CREDENTIALS, variable: 'KUBECONFIG_CONTENT')]) {
                        // Setup kubeconfig with validation
                        sh """
                            echo "Setting up kubeconfig for health checks..."
                            mkdir -p ~/.kube
                            
                            # Validate kubeconfig content exists
                            if [ -z "\$KUBECONFIG_CONTENT" ]; then
                                echo "ERROR: KUBECONFIG_CONTENT is empty. Please check kubernetes-config credential."
                                exit 1
                            fi
                            
                            # Decode and validate base64 content
                            echo "Decoding kubeconfig content..."
                            if ! echo "\$KUBECONFIG_CONTENT" | base64 -d > ~/.kube/config 2>/dev/null; then
                                echo "ERROR: Failed to decode kubeconfig. Please ensure the credential contains valid base64 content."
                                echo "To create valid content: cat ~/.kube/config | base64 -w 0"
                                exit 1
                            fi
                            
                            chmod 600 ~/.kube/config
                            
                            # Validate kubeconfig format
                            if ! kubectl config view --minify >/dev/null 2>&1; then
                                echo "ERROR: Invalid kubeconfig format after decoding."
                                exit 1
                            fi
                            
                            echo "Kubeconfig setup completed successfully"
                        """
                        sh """
                            # Wait a bit for services to be ready
                            sleep 30
                            
                            # Check backend health
                            kubectl exec -n ${namespace} deployment/backend-deployment -- \
                                curl -f http://localhost:5000/health || exit 1
                            
                            # Check if frontend is serving content
                            kubectl exec -n ${namespace} deployment/frontend-deployment -- \
                                curl -f http://localhost:80/ || exit 1
                            
                            echo "All health checks passed!"
                        """
                    }
                }
            }
        }
    }
    
    post {
        always {
            // Clean up docker images and workspace
            sh """
                docker rmi ${DOCKER_REPO_FRONTEND}:${BUILD_TAG} || true
                docker rmi ${DOCKER_REPO_BACKEND}:${BUILD_TAG} || true
                docker system prune -f --volumes
            """
            cleanWs()
        }
        
        success {
            script {
                def environment = env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master' ? 'production' : 'staging'
                def message = """
✅ *Notes App Deployment Successful!*
📦 Build: ${BUILD_TAG}
🌍 Environment: ${environment}
🐳 Images:
  • Frontend: ${DOCKER_REPO_FRONTEND}:${BUILD_TAG}
  • Backend: ${DOCKER_REPO_BACKEND}:${BUILD_TAG}
🚀 Deployed by: ${env.DEPLOYER ?: env.BUILD_USER ?: 'Jenkins'}
"""
                echo message
                
                // Uncomment below if you have Slack integration
                // slackSend(color: 'good', message: message)
            }
        }
        
        failure {
            script {
                def environment = env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master' ? 'production' : 'staging'
                def message = """
❌ *Notes App Deployment Failed!*
📦 Build: ${BUILD_TAG}
🌍 Environment: ${environment}
🔗 Build URL: ${env.BUILD_URL}
"""
                echo message
                
                // Uncomment below if you have Slack integration
                // slackSend(color: 'danger', message: message)
            }
        }
    }
}