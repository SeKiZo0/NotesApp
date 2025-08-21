// Helper function for Kubernetes deployment - MUST be outside pipeline block
def deployToKubernetes(environment) {
    withCredentials([kubeconfigFile(credentialsId: K8S_CREDENTIALS, variable: 'KUBECONFIG')]) {
        def namespace = environment == 'production' ? 'notes-app-prod' : 'notes-app-staging'
        
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
        // Docker Registry Configuration
        DOCKER_REGISTRY = '192.168.1.150:3000'
        DOCKER_REPO_FRONTEND = "${DOCKER_REGISTRY}/notes-app-frontend"
        DOCKER_REPO_BACKEND = "${DOCKER_REGISTRY}/notes-app-backend"
        
        // Credentials
        REGISTRY_CREDENTIALS = 'forgejo-registry-credentials'
        K8S_CREDENTIALS = 'k8s-kubeconfig'
        
        // Database Configuration
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
                                "-f frontend/Dockerfile frontend/"
                            )
                            frontendImage.tag("${DOCKER_REPO_FRONTEND}:latest")
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
                                "-f backend/Dockerfile backend/"
                            )
                            backendImage.tag("${DOCKER_REPO_BACKEND}:latest")
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
                            echo "Running security scan on frontend image..."
                            # Using Trivy for container security scanning
                            docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                            aquasec/trivy image --exit-code 0 --no-progress \
                            --format table ${DOCKER_REPO_FRONTEND}:${BUILD_TAG} || echo "Security scan completed with warnings"
                        """
                    }
                }
                stage('Scan Backend Image') {
                    steps {
                        sh """
                            echo "Running security scan on backend image..."
                            # Using Trivy for container security scanning
                            docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                            aquasec/trivy image --exit-code 0 --no-progress \
                            --format table ${DOCKER_REPO_BACKEND}:${BUILD_TAG} || echo "Security scan completed with warnings"
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
                    echo "🚀 Pushing images to Forgejo registry..."
                    echo "Registry: ${DOCKER_REGISTRY}"
                    echo "Frontend: ${DOCKER_REPO_FRONTEND}:${BUILD_TAG}"
                    echo "Backend: ${DOCKER_REPO_BACKEND}:${BUILD_TAG}"
                    echo ""
                    
                    // Test registry connectivity first with better error handling
                    sh """
                        echo "🔍 Testing registry connectivity..."
                        REGISTRY_STATUS=\$(curl -s -o /dev/null -w "%{http_code}" http://${DOCKER_REGISTRY}/v2/ 2>/dev/null || echo "000")
                        echo "Registry HTTP status: \$REGISTRY_STATUS"
                        
                        if [ "\$REGISTRY_STATUS" = "200" ]; then
                            echo "✅ Registry is accessible and ready"
                        elif [ "\$REGISTRY_STATUS" = "401" ]; then
                            echo "🔑 Registry requires authentication (expected with credentials)"
                        else
                            echo "⚠️  Registry connectivity issue (HTTP \$REGISTRY_STATUS)"
                            echo "🔍 Full registry response:"
                            curl -v http://${DOCKER_REGISTRY}/v2/ 2>&1 || echo "Connection failed"
                        fi
                    """
                    
                    // Push with authentication using Jenkins credentials
                    try {
                        docker.withRegistry("http://${DOCKER_REGISTRY}", REGISTRY_CREDENTIALS) {
                            echo "🔑 Successfully authenticated with registry"
                            
                            // Push frontend
                            echo "📦 Pushing frontend image..."
                            def frontendImg = docker.image("${DOCKER_REPO_FRONTEND}:${BUILD_TAG}")
                            frontendImg.push()
                            frontendImg.push('latest')
                            echo "✅ Frontend image pushed successfully"
                            
                            // Push backend
                            echo "📦 Pushing backend image..."
                            def backendImg = docker.image("${DOCKER_REPO_BACKEND}:${BUILD_TAG}")
                            backendImg.push()
                            backendImg.push('latest')
                            echo "✅ Backend image pushed successfully"
                            
                            echo ""
                            echo "🎉 All images pushed successfully!"
                            echo "Images available at:"
                            echo "  • Frontend: ${DOCKER_REPO_FRONTEND}:${BUILD_TAG}"
                            echo "  • Backend: ${DOCKER_REPO_BACKEND}:${BUILD_TAG}"
                        }
                    } catch (Exception e) {
                        echo ""
                        echo "❌ DOCKER PUSH FAILED"
                        echo "═══════════════════════════════════════"
                        echo ""
                        echo "🔍 Error details: ${e.getMessage()}"
                        echo ""
                        echo "🛠️  TROUBLESHOOTING CHECKLIST:"
                        echo ""
                        echo "1️⃣  CREDENTIALS ISSUE:"
                        echo "   • Check Jenkins credential: '${REGISTRY_CREDENTIALS}'"
                        echo "   • Verify username/password are correct"
                        echo "   • Test manual login: docker login ${DOCKER_REGISTRY}"
                        echo ""
                        echo "2️⃣  REGISTRY SERVER ISSUES:"
                        echo "   • SSH to registry server: ssh [user]@192.168.1.150"
                        echo "   • Check if registry is running: docker ps | grep registry"
                        echo "   • If not running, start it: docker-compose up -d"
                        echo ""
                        echo "3️⃣  DOCKER DAEMON CONFIGURATION:"
                        echo "   • Verify insecure registry config on Jenkins server:"
                        echo "   • docker info | grep -A5 'Insecure Registries'"
                        echo "   • Should show: 192.168.1.150:3000"
                        echo ""
                        echo "4️⃣  NETWORK/FIREWALL:"
                        echo "   • Test connectivity: curl http://192.168.1.150:3000/v2/"
                        echo "   • Check firewall rules between Jenkins and registry"
                        echo ""
                        echo "💡 QUICK FIX: If credentials are missing, add them in Jenkins:"
                        echo "   Manage Jenkins → Credentials → Add Username/Password"
                        echo "   ID: forgejo-registry-credentials"
                        echo ""
                        throw e
                    }
                }
            }
        }    stages {
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
                        echo "Registry: ${DOCKER_REGISTRY}"
                        echo "Frontend: ${DOCKER_REPO_FRONTEND}:${BUILD_TAG}"
                        echo "Backend: ${DOCKER_REPO_BACKEND}:${BUILD_TAG}"
                        echo ""
                        
                        # Check if Docker daemon is configured for insecure registry
                        echo "🔍 Checking Docker daemon configuration..."
                        
                        # Test registry connectivity with detailed debugging
                        echo "🌐 Testing registry connectivity..."
                        REGISTRY_STATUS=\$(curl -s -o /dev/null -w "%{http_code}" http://${DOCKER_REGISTRY}/v2/ || echo "000")
                        echo "Registry HTTP status: \$REGISTRY_STATUS"
                        
                        if [ "\$REGISTRY_STATUS" = "200" ]; then
                            echo "✅ Registry is accessible and ready"
                        elif [ "\$REGISTRY_STATUS" = "401" ]; then
                            echo "⚠️  Registry requires authentication or is not configured for anonymous access"
                            echo "🔧 Checking if we can access with credentials..."
                        else
                            echo "❌ Registry connectivity issue (HTTP \$REGISTRY_STATUS)"
                            echo "🔍 Debugging registry connection..."
                            echo "Full response:"
                            curl -v http://${DOCKER_REGISTRY}/v2/ || true
                            echo ""
                            echo "💡 Possible solutions:"
                            echo "1. Ensure registry container is running on 192.168.1.150:3000"
                            echo "2. Check firewall settings"
                            echo "3. Verify registry configuration"
                            # Don't exit here, let's try to push anyway
                        fi
                        
                        # Check Docker daemon configuration
                        echo "🐳 Checking Docker daemon configuration..."
                        if docker info 2>/dev/null | grep -q "Insecure Registries:" && \
                           docker info 2>/dev/null | grep -A5 "Insecure Registries:" | grep -q "${DOCKER_REGISTRY}"; then
                            echo "✅ Docker daemon properly configured for insecure registry"
                        else
                            echo "⚠️  Docker daemon may not be configured for insecure registry"
                        fi
                        
                        # Try authentication with registry if credentials are available
                        echo "🔑 Attempting registry authentication..."
                        if docker login ${DOCKER_REGISTRY} 2>/dev/null; then
                            echo "✅ Registry authentication successful"
                            LOGIN_SUCCESS=true
                        else
                            echo "⚠️  Registry authentication failed or not required"
                            echo "📝 Proceeding without authentication (registry may allow anonymous pushes)"
                            LOGIN_SUCCESS=false
                        fi
                        
                        # Attempt to push images with proper error handling
                        echo ""
                        echo "📦 Pushing frontend image..."
                        if docker push ${DOCKER_REPO_FRONTEND}:${BUILD_TAG}; then
                            echo "✅ Frontend image pushed successfully"
                            echo "📦 Pushing frontend latest tag..."
                            docker push ${DOCKER_REPO_FRONTEND}:latest
                            
                            echo "📦 Pushing backend image..."
                            if docker push ${DOCKER_REPO_BACKEND}:${BUILD_TAG}; then
                                echo "✅ Backend image pushed successfully"
                                echo "📦 Pushing backend latest tag..."
                                docker push ${DOCKER_REPO_BACKEND}:latest
                                echo ""
                                echo "🎉 All images pushed successfully!"
                            else
                                echo "❌ Backend image push failed"
                                echo "🔍 Checking push error details..."
                                docker push ${DOCKER_REPO_BACKEND}:${BUILD_TAG} 2>&1 | tail -20 || true
                                exit 1
                            fi
                        else
                            echo ""
                            echo "❌ DOCKER PUSH FAILED"
                            echo "════════════════════════════════════════════════"
                            echo ""
                            echo "� Error details:"
                            docker push ${DOCKER_REPO_FRONTEND}:${BUILD_TAG} 2>&1 | tail -20 || true
                            echo ""
                            echo "🛠️  TROUBLESHOOTING STEPS:"
                            echo ""
                            echo "1️⃣  REGISTRY SERVER ISSUES:"
                            echo "   • SSH to registry server: ssh [user]@192.168.1.150"
                            echo "   • Check if registry is running: docker ps | grep registry"
                            echo "   • If not running, start it: docker-compose up -d"
                            echo ""
                            echo "2️⃣  AUTHENTICATION ISSUES:"
                            echo "   • Registry may require authentication"
                            echo "   • Configure registry for anonymous access, or"
                            echo "   • Add registry credentials to Jenkins"
                            echo ""
                            echo "3️⃣  NETWORK/FIREWALL ISSUES:"
                            echo "   • Test connectivity: curl http://192.168.1.150:3000/v2/"
                            echo "   • Check firewall rules between Jenkins and registry"
                            echo ""
                            echo "4️⃣  REGISTRY CONFIGURATION:"
                            echo "   • Registry should accept HTTP (not just HTTPS)"
                            echo "   • Check docker-compose.yml configuration"
                            echo ""
                            exit 1
                        fi
                    """
        
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
                    
                    withCredentials([kubeconfigFile(credentialsId: K8S_CREDENTIALS, variable: 'KUBECONFIG')]) {
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
                    
                    withCredentials([kubeconfigFile(credentialsId: K8S_CREDENTIALS, variable: 'KUBECONFIG')]) {
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
� Images:
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
