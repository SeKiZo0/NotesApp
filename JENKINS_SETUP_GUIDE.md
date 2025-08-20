# Jenkins Pipeline Setup Guide

## Required Jenkins Plugins

Ensure the following plugins are installed in your Jenkins instance:

1. **Docker Pipeline Plugin** - For Docker build operations
2. **Kubernetes CLI Plugin** - For kubectl commands  
3. **Credentials Plugin** - For managing secrets
4. **Pipeline Plugin** - For pipeline support
5. **Git Plugin** - For repository integration
6. **Blue Ocean** (optional) - For better pipeline visualization

## Required Credentials

Configure the following credentials in Jenkins (Manage Jenkins → Manage Credentials):

### 1. Forgejo Git Access (`forgejo-git-credentials`)
- **Type**: Username with password
- **Scope**: Global
- **ID**: `forgejo-git-credentials`
- **Username**: Your Forgejo username
- **Password**: Your Forgejo password or access token

### 2. Docker Registry Access (`docker-registry-credentials`)
- **Type**: Username with password  
- **Scope**: Global
- **ID**: `docker-registry-credentials`
- **Username**: Your Docker registry username
- **Password**: Your Docker registry password

### 3. Kubernetes Configuration (`kubernetes-config`)
- **Type**: Secret text
- **Scope**: Global
- **ID**: `kubernetes-config`
- **Secret**: Base64 encoded kubeconfig content

#### How to get the kubeconfig content:
```bash
# Get your kubeconfig content
cat ~/.kube/config

# Or if using a specific kubeconfig file
cat /path/to/your/kubeconfig

# Encode it to base64 (required for Jenkins secret text)
cat ~/.kube/config | base64 -w 0
```

Copy the base64 encoded string and paste it as the secret value.

## Environment Setup

### Kubernetes Cluster Requirements

Your Kubernetes cluster should have:

1. **kubectl access** configured
2. **Docker registry access** from cluster nodes
3. **Namespace creation permissions**
4. **PostgreSQL storage** capabilities (PVC support)

### Required Kubernetes Namespaces

The pipeline will automatically create these namespaces:
- `notes-staging` - For staging deployments  
- `notes-app-prod` - For production deployments

### Docker Registry Configuration

Update the Jenkinsfile environment variables if using a different registry:

```groovy
environment {
    DOCKER_REPO = '192.168.1.150:3000'  // Change to your registry
    DOCKER_REPO_FRONTEND = "${DOCKER_REPO}/notes-app-frontend"
    DOCKER_REPO_BACKEND = "${DOCKER_REPO}/notes-app-backend"
    // ... other variables
}
```

## Pipeline Behavior

### Branch-based Deployment

- **Feature branches**: Deploy to staging only
- **Main/master branch**: Deploy to staging first, then require manual approval for production

### Security Scanning

The pipeline includes:
- **Trivy vulnerability scanning** for both frontend and backend Docker images
- **npm audit** for dependency vulnerabilities
- **Build fails** on HIGH or CRITICAL vulnerabilities

### Manual Production Approval

Production deployments require manual approval. The pipeline will pause and wait for approval before deploying to production.

## Troubleshooting

### Common Issues

1. **No such DSL method 'kubeconfigFile'**
   - Install the Kubernetes CLI plugin
   - Or use the `string` credential type as implemented in this pipeline

2. **Docker build failures**
   - Ensure Docker is available on Jenkins agents
   - Check Docker registry credentials

3. **Kubernetes deployment failures**
   - Verify kubeconfig credential is correct
   - Check cluster connectivity from Jenkins
   - Ensure sufficient permissions in cluster

4. **Database connection issues**
   - Verify PostgreSQL secrets are properly applied
   - Check PVC provisioning in your cluster
   - Review network policies

### Debug Commands

Run these commands in your Kubernetes cluster to debug issues:

```bash
# Check pipeline deployment status
kubectl get pods -n notes-staging
kubectl get pods -n notes-app-prod

# Check services and ingress
kubectl get svc,ingress -n notes-staging

# View pod logs
kubectl logs -l app=backend -n notes-staging
kubectl logs -l app=frontend -n notes-staging

# Test database connectivity
kubectl exec deployment/postgres-deployment -n notes-staging -- pg_isready -U postgres
```

## Pipeline Stages

1. **Checkout** - Clone code from Forgejo
2. **Test Backend** - Run npm ci and audit  
3. **Test Frontend** - Run npm ci and audit
4. **Build Docker Images** - Build and tag images
5. **Security Scan** - Scan images with Trivy
6. **Push Docker Images** - Push to registry (main branch only)
7. **Deploy to Staging** - Deploy to staging environment
8. **Deploy to Production** - Deploy to production (main branch + manual approval)
9. **Database Setup Verification** - Verify PostgreSQL connectivity
10. **Run Health Checks** - Verify application health

## Manual Testing

After deployment, verify the application:

```bash
# Port forward to test locally
kubectl port-forward svc/frontend-service 8080:80 -n notes-staging

# Test backend API
kubectl port-forward svc/backend-service 5000:5000 -n notes-staging
curl http://localhost:5000/health
curl http://localhost:5000/api/notes
```

Visit `http://localhost:8080` to access the Notes application.
