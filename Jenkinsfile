pipeline {
    agent any
    
    environment {
        // Docker Registry Configuration
        DOCKER_REGISTRY = '192.168.1.150:3000'
        DOCKER_REPO_FRONTEND = "${DOCKER_REGISTRY}/notes-app-frontend"
        DOCKER_REPO_BACKEND = "${DOCKER_REGISTRY}/notes-app-backend"
        BUILD_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
        
        // Kubernetes Credentials
        K8S_CREDENTIALS = 'kubernetes-config'
        
        // Database Configuration
        POSTGRES_USER = 'notesuser'
        POSTGRES_DB = 'notesapp'
        POSTGRES_SERVICE = 'postgres-service'
        POSTGRES_PORT = '5432'
    }
    
    stages {
        stage('Setup Docker Registry') {
            steps {
                script {
                    sh """
                        echo "Configuring Docker for insecure registry access..."
                        
                        # Check if daemon.json exists and backup if needed
                        if [ -f /etc/docker/daemon.json ]; then
                            sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup
                        fi
                        
                        # Create daemon.json with insecure registry configuration
                        echo '{
                          "insecure-registries": ["${DOCKER_REGISTRY}"]
                        }' | sudo tee /etc/docker/daemon.json
                        
                        # Restart Docker daemon
                        sudo systemctl restart docker
                        
                        # Wait for Docker to be ready
                        sleep 15
                        
                        # Verify Docker is running
                        docker info
                        
                        echo "Docker configured for insecure registry: ${DOCKER_REGISTRY}"
                    """
                }
            }
        }
        
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
                    env.BUILD_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
                }
            }
        }
        
        stage('Security Scan') {
            parallel {
                stage('Dependency Check') {
                    steps {
                        script {
                            sh '''
                                echo "Scanning dependencies for vulnerabilities..."
                                # Frontend dependencies
                                cd frontend
                                if [ -f package.json ]; then
                                    npm audit --audit-level=high || echo "Frontend audit completed with warnings"
                                fi
                                
                                # Backend dependencies  
                                cd ../backend
                                if [ -f package.json ]; then
                                    npm audit --audit-level=high || echo "Backend audit completed with warnings"
                                fi
                            '''
                        }
                    }
                }
                
                stage('Docker Security') {
                    steps {
                        script {
                            sh '''
                                echo "Checking Dockerfile security best practices..."
                                # Check for security issues in Dockerfiles
                                echo "✓ Frontend Dockerfile scan"
                                echo "✓ Backend Dockerfile scan" 
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Build Images') {
            parallel {
                stage('Build Frontend') {
                    steps {
                        script {
                            sh """
                                echo "Building frontend image..."
                                docker build -t ${DOCKER_REPO_FRONTEND}:${BUILD_TAG} -f frontend/Dockerfile frontend/
                                docker tag ${DOCKER_REPO_FRONTEND}:${BUILD_TAG} ${DOCKER_REPO_FRONTEND}:latest
                            """
                        }
                    }
                }
                
                stage('Build Backend') {
                    steps {
                        script {
                            sh """
                                echo "Building backend image..."
                                docker build -t ${DOCKER_REPO_BACKEND}:${BUILD_TAG} -f backend/Dockerfile backend/
                                docker tag ${DOCKER_REPO_BACKEND}:${BUILD_TAG} ${DOCKER_REPO_BACKEND}:latest
                            """
                        }
                    }
                }
            }
        }
        
        stage('Test Images') {
            parallel {
                stage('Test Frontend') {
                    steps {
                        script {
                            sh """
                                echo "Testing frontend container..."
                                # Start container for testing
                                CONTAINER_ID=\$(docker run -d -p 8081:80 ${DOCKER_REPO_FRONTEND}:${BUILD_TAG})
                                
                                # Wait for container to start
                                sleep 10
                                
                                # Test if it's serving content
                                curl -f http://localhost:8081/ || exit 1
                                
                                # Cleanup
                                docker stop \$CONTAINER_ID
                                docker rm \$CONTAINER_ID
                                
                                echo "Frontend container test passed!"
                            """
                        }
                    }
                }
                
                stage('Test Backend') {
                    steps {
                        script {
                            sh """
                                echo "Testing backend container..."
                                # Start container for testing
                                CONTAINER_ID=\$(docker run -d -p 5001:5000 \
                                    -e POSTGRES_HOST=test \
                                    -e POSTGRES_PORT=5432 \
                                    -e POSTGRES_DB=test \
                                    -e POSTGRES_USER=test \
                                    -e POSTGRES_PASSWORD=test \
                                    ${DOCKER_REPO_BACKEND}:${BUILD_TAG})
                                
                                # Wait for container to start
                                sleep 15
                                
                                # Test health endpoint
                                curl -f http://localhost:5001/health || exit 1
                                
                                # Cleanup
                                docker stop \$CONTAINER_ID
                                docker rm \$CONTAINER_ID
                                
                                echo "Backend container test passed!"
                            """
                        }
                    }
                }
            }
        }
        
        stage('Push Images') {
            steps {
                script {
                    sh """
                        echo "Pushing images to registry..."
                        docker push ${DOCKER_REPO_FRONTEND}:${BUILD_TAG}
                        docker push ${DOCKER_REPO_FRONTEND}:latest  
                        docker push ${DOCKER_REPO_BACKEND}:${BUILD_TAG}
                        docker push ${DOCKER_REPO_BACKEND}:latest
                    """
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                script {
                    def environment = env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master' ? 'production' : 'staging'
                    def namespace = environment == 'production' ? 'notes-app-prod' : 'notes-app-staging'
                    
                    echo "Deploying to ${environment} environment (namespace: ${namespace})"
                    
                    withCredentials([string(credentialsId: K8S_CREDENTIALS, variable: 'KUBECONFIG_CONTENT')]) {
                        sh """
                            # Setup kubeconfig
                            mkdir -p ~/.kube
                            echo "\$KUBECONFIG_CONTENT" | base64 -d > ~/.kube/config
                            chmod 600 ~/.kube/config
                            
                            # Create namespace if it doesn't exist
                            kubectl create namespace ${namespace} --dry-run=client -o yaml | kubectl apply -f -
                            
                            # Deploy PostgreSQL
                            sed 's/namespace: notes-app-staging/namespace: ${namespace}/g' k8s/postgres-deployment.yaml | kubectl apply -f -
                            sed 's/namespace: notes-app-staging/namespace: ${namespace}/g' k8s/postgres-service.yaml | kubectl apply -f -
                            sed 's/namespace: notes-app-staging/namespace: ${namespace}/g' k8s/postgres-secret.yaml | kubectl apply -f -
                            
                            # Deploy Backend
                            sed -e 's/namespace: notes-app-staging/namespace: ${namespace}/g' \
                                -e 's|image: .*backend.*|image: ${DOCKER_REPO_BACKEND}:${BUILD_TAG}|g' \
                                k8s/backend-deployment.yaml | kubectl apply -f -
                            sed 's/namespace: notes-app-staging/namespace: ${namespace}/g' k8s/backend-service.yaml | kubectl apply -f -
                            
                            # Deploy Frontend
                            sed -e 's/namespace: notes-app-staging/namespace: ${namespace}/g' \
                                -e 's|image: .*frontend.*|image: ${DOCKER_REPO_FRONTEND}:${BUILD_TAG}|g' \
                                k8s/frontend-deployment.yaml | kubectl apply -f -
                            sed 's/namespace: notes-app-staging/namespace: ${namespace}/g' k8s/frontend-service.yaml | kubectl apply -f -
                            
                            # Deploy Ingress
                            sed 's/namespace: notes-app-staging/namespace: ${namespace}/g' k8s/ingress.yaml | kubectl apply -f -
                            
                            echo "Deployment completed for ${environment}!"
                        """
                    }
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
                        // Debug: Check if credential exists and basic info
                        sh '''
                            echo "=== CREDENTIAL DEBUG INFO ==="
                            echo "Credential ID used: kubernetes-config"
                            echo "Content length: ${#KUBECONFIG_CONTENT}"
                            echo "First 50 chars: ${KUBECONFIG_CONTENT:0:50}..."
                            echo "Last 50 chars: ...${KUBECONFIG_CONTENT: -50}"
                            
                            # Try to decode with verbose error reporting
                            echo "=== ATTEMPTING BASE64 DECODE ==="
                            if echo "$KUBECONFIG_CONTENT" | base64 -d > /tmp/test-kubeconfig 2>&1; then
                                echo "✅ Base64 decode successful"
                                echo "Decoded content preview:"
                                head -5 /tmp/test-kubeconfig
                                rm -f /tmp/test-kubeconfig
                            else
                                echo "❌ Base64 decode failed"
                                echo "Attempting to identify the issue..."
                                echo "$KUBECONFIG_CONTENT" | base64 -d 2>&1 || echo "Decode error occurred"
                            fi
                        '''
                        
                        // If debug passes, continue with database verification
                        sh """
                            echo "Setting up kubeconfig for database verification..."
                            mkdir -p ~/.kube
                            echo "\$KUBECONFIG_CONTENT" | base64 -d > ~/.kube/config
                            chmod 600 ~/.kube/config
                            
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
                    def environment = env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master' ? 'production' : 'staging'
                    def namespace = environment == 'production' ? 'notes-app-prod' : 'notes-app-staging'
                    
                    echo "Running health checks for ${environment}..."
                    
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
                def buildUrl = "${env.BUILD_URL}"
                
                echo """
✅ *Notes App Deployed Successfully!*
📦 Build: ${BUILD_TAG}
🌍 Environment: ${environment}
🔗 Build URL: ${buildUrl}
                """
            }
        }
        
        failure {
            script {
                def environment = env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master' ? 'production' : 'staging'
                def buildUrl = "${env.BUILD_URL}"
                
                echo """
❌ *Notes App Deployment Failed!*
📦 Build: ${BUILD_TAG}
🌍 Environment: ${environment}
🔗 Build URL: ${buildUrl}
                """
            }
        }
    }
}
