# Jenkins Pipeline Configuration for Forgejo

## Prerequisites

Before running this pipeline, ensure you have the following configured in Jenkins:

### 1. Required Jenkins Plugins
- Docker Pipeline Plugin
- Kubernetes Plugin
- Credentials Binding Plugin
- Pipeline Plugin

### 2. Required Credentials

#### Forgejo Registry Credentials
- **Credential ID**: `forgejo-registry-credentials`
- **Type**: Username with password
- **Username**: Your Forgejo username
- **Password**: Your Forgejo access token or password

#### Kubernetes Configuration
- **Credential ID**: `k8s-kubeconfig`
- **Type**: Secret file
- **File**: Your kubeconfig file for the target Kubernetes cluster

### 3. Environment Variables to Update

Update these variables in the Jenkinsfile for your environment:

```groovy
environment {
    FORGEJO_REGISTRY = 'your-forgejo-instance.com:3000'  // Update this
    PROJECT_NAME = 'notes-app'
    REGISTRY_CREDENTIALS = 'forgejo-registry-credentials'
    K8S_CREDENTIALS = 'k8s-kubeconfig'
    K8S_NAMESPACE = 'notes-app'
}
```

## Pipeline Features

### ✅ Branch-Based Deployment Strategy
- **develop/dev** → Staging environment (`notes-app-staging` namespace)
- **main/master** → Production environment (`notes-app-prod` namespace)
- Manual approval required for production deployments

### ✅ Image Management
- Images tagged with `BUILD_NUMBER-GIT_COMMIT_SHORT`
- Latest tags updated on successful builds
- Automatic cleanup of local images

### ✅ Kubernetes Deployment
- Separate namespaces for staging and production
- PostgreSQL deployed only if not already present
- Rolling updates with health checks
- Automatic rollback on failure

### ✅ Health Checks
- Backend API health endpoint (`/health`)
- Database connectivity check (`/api/health/db`)
- Frontend availability check

## Setup Instructions

### 1. Configure Forgejo Registry Access

Create registry credentials in Jenkins:
1. Go to Jenkins → Manage Jenkins → Manage Credentials
2. Add new Username/Password credential:
   - ID: `forgejo-registry-credentials`
   - Username: Your Forgejo username
   - Password: Your Forgejo access token

### 2. Configure Kubernetes Access

Add kubeconfig to Jenkins:
1. Go to Jenkins → Manage Jenkins → Manage Credentials
2. Add new Secret file credential:
   - ID: `k8s-kubeconfig`
   - File: Upload your kubeconfig file

### 3. Create Jenkins Pipeline Job

1. Create new Pipeline job in Jenkins
2. Configure SCM to point to your Forgejo repository
3. Set Pipeline script path to `Jenkinsfile`
4. Enable branch discovery for multi-branch pipeline

### 4. Configure Webhooks (Optional)

In your Forgejo repository:
1. Go to Settings → Webhooks
2. Add webhook pointing to: `http://your-jenkins-url/git/notifyCommit?url=your-repo-url`

## Deployment Process

### Staging Deployment (develop branch)
```bash
git checkout develop
git push origin develop
# Pipeline automatically deploys to staging
```

### Production Deployment (main branch)
```bash
git checkout main
git merge develop
git push origin main
# Pipeline requires manual approval for production
```

## Monitoring Deployment

### View Kubernetes Resources
```bash
# Staging
kubectl get pods,svc,ingress -n notes-app-staging

# Production  
kubectl get pods,svc,ingress -n notes-app-prod
```

### Check Application Logs
```bash
# Backend logs
kubectl logs deployment/backend-deployment -n notes-app-staging -f

# Frontend logs
kubectl logs deployment/frontend-deployment -n notes-app-staging -f

# PostgreSQL logs
kubectl logs deployment/postgres-deployment -n notes-app-staging -f
```

### Test Health Endpoints
```bash
# Get backend service endpoint
kubectl get svc backend-service -n notes-app-staging

# Test health endpoints
curl http://<backend-ip>:5000/health
curl http://<backend-ip>:5000/api/health/db
```

## Troubleshooting

### Common Issues

#### 1. Registry Authentication Failed
- Verify Forgejo credentials in Jenkins
- Check if access token has registry permissions
- Ensure registry URL is correct

#### 2. Kubernetes Deployment Failed
- Verify kubeconfig is valid and accessible
- Check if Jenkins has permissions to create namespaces
- Ensure cluster has sufficient resources

#### 3. Image Pull Failed
- Verify images were pushed successfully
- Check if Kubernetes has pull secrets configured
- Ensure image names match exactly

#### 4. Health Checks Failing
- Check if backend is connecting to PostgreSQL
- Verify environment variables are set correctly
- Check network policies and service discovery

### Debug Commands

```bash
# Check pipeline environment variables
echo $FORGEJO_REGISTRY
echo $BUILD_TAG

# Test Docker registry access
docker login $FORGEJO_REGISTRY

# Test Kubernetes connectivity
kubectl cluster-info
kubectl get nodes

# Check image availability
docker pull $FORGEJO_REGISTRY/notes-app-backend:latest
```

## Security Considerations

1. **Secrets Management**: Use Kubernetes secrets for sensitive data
2. **Registry Security**: Use access tokens instead of passwords
3. **Network Policies**: Implement proper network segmentation
4. **RBAC**: Configure least-privilege access for Jenkins
5. **Image Scanning**: Consider adding security scanning stages

## Customization

### Adding Tests
Add test stages before the build stage:

```groovy
stage('Test Backend') {
    steps {
        dir('backend') {
            sh 'npm ci'
            sh 'npm test'
        }
    }
}
```

### Adding Notifications
Uncomment Slack integration or add other notification methods:

```groovy
// Slack notification
slackSend(color: 'good', message: message)

// Email notification
emailext(
    subject: "Deployment Status: ${currentBuild.result}",
    body: message,
    to: "${env.CHANGE_AUTHOR_EMAIL}"
)
```

### Custom Environments
Add additional environments by modifying the deployment function:

```groovy
stage('Deploy to QA') {
    when { branch 'qa' }
    steps {
        script {
            deployToKubernetes('qa')
        }
    }
}
```
