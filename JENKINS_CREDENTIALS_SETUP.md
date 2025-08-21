# Jenkins Credentials Setup for Registry Authentication

## Overview

The enhanced Jenkinsfile uses proper Jenkins credentials management for authenticating with the Docker registry. This is more secure than anonymous access and allows for better access control.

## Required Jenkins Credentials

### 1. Docker Registry Credentials
- **Credential Type**: Username with password
- **ID**: `forgejo-registry-credentials`
- **Username**: Your Forgejo/registry username
- **Password**: Your Forgejo/registry password

### 2. Kubernetes Configuration
- **Credential Type**: Kubeconfig file
- **ID**: `k8s-kubeconfig`
- **File**: Your kubeconfig file for the Kubernetes cluster

## Setting Up Registry Credentials

### Option A: Create Registry User (Recommended)

If using Forgejo with built-in registry:

1. **Create a dedicated user for Jenkins:**
   ```bash
   # On Forgejo server, create a new user account:
   # Username: jenkins-ci
   # Email: jenkins@yourcompany.com
   # Password: [generate secure password]
   ```

2. **Grant registry access:**
   - Go to Forgejo admin panel
   - Navigate to user management
   - Ensure the user has appropriate repository access

### Option B: Use Existing User Credentials

If you have existing Forgejo credentials:
- Use your Forgejo username and password
- Ensure the user has push access to the repository

## Adding Credentials to Jenkins

### Step 1: Access Jenkins Credentials
1. Open Jenkins web interface: `http://192.168.1.153:8080`
2. Go to **Manage Jenkins** → **Manage Credentials**
3. Click on **(global)** domain
4. Click **Add Credentials**

### Step 2: Add Docker Registry Credentials
1. **Kind**: Username with password
2. **Scope**: Global
3. **Username**: Your Forgejo username (e.g., `jenkins-ci`)
4. **Password**: Your Forgejo password
5. **ID**: `forgejo-registry-credentials` (must match exactly)
6. **Description**: `Forgejo Docker Registry Access`
7. Click **OK**

### Step 3: Add Kubernetes Credentials
1. **Kind**: Kubeconfig file
2. **Scope**: Global
3. **ID**: `k8s-kubeconfig` (must match exactly)
4. **Description**: `Kubernetes Cluster Access`
5. **File**: Upload your kubeconfig file
6. Click **OK**

## Testing Registry Authentication

### From Jenkins Server

1. **SSH to Jenkins server:**
   ```bash
   ssh [user]@192.168.1.153
   ```

2. **Test manual login:**
   ```bash
   docker login 192.168.1.150:3000
   # Enter the same credentials you added to Jenkins
   ```

3. **Test push:**
   ```bash
   docker pull hello-world
   docker tag hello-world 192.168.1.150:3000/test:latest
   docker push 192.168.1.150:3000/test:latest
   ```

4. **Verify in registry:**
   ```bash
   curl http://192.168.1.150:3000/v2/_catalog
   # Should show: {"repositories":["test"]}
   ```

## Registry Server Configuration

### For Forgejo Built-in Registry

Ensure your Forgejo configuration allows Docker registry access:

```ini
[packages]
ENABLED = true

[packages.registry]
ENABLED = true
```

### For Standalone Docker Registry with Authentication

Create `docker-compose.yml` on registry server:

```yaml
version: '3.8'
services:
  registry:
    image: registry:2
    container_name: docker-registry
    restart: unless-stopped
    ports:
      - "3000:5000"
    environment:
      REGISTRY_AUTH: htpasswd
      REGISTRY_AUTH_HTPASSWD_REALM: Registry Realm
      REGISTRY_AUTH_HTPASSWD_PATH: /auth/htpasswd
      REGISTRY_STORAGE_DELETE_ENABLED: true
    volumes:
      - ./auth:/auth
      - registry-data:/var/lib/registry

volumes:
  registry-data:
```

Create authentication file:
```bash
# Install htpasswd
sudo apt-get install apache2-utils

# Create auth directory
mkdir auth

# Create user (replace with your credentials)
htpasswd -Bbn jenkins-ci [password] > auth/htpasswd

# Start registry
docker-compose up -d
```

## Troubleshooting

### Issue: "Authentication Required"
**Solution**: Verify credentials are correct
```bash
# Test manual login
docker login 192.168.1.150:3000
```

### Issue: "Credentials Not Found" in Jenkins
**Solution**: 
- Check credential ID matches exactly: `forgejo-registry-credentials`
- Verify credential scope is set to "Global"
- Ensure Jenkins has restarted after adding credentials

### Issue: "Access Denied" 
**Solution**: 
- Verify user has push access to the repository
- Check if registry requires specific permissions

### Issue: "Connection Refused"
**Solution**:
- Verify registry is running: `docker ps | grep registry`
- Check network connectivity: `curl http://192.168.1.150:3000/v2/`
- Verify Docker daemon is configured for insecure registry

## Security Best Practices

1. **Use dedicated service account** for Jenkins registry access
2. **Limit permissions** to only required repositories
3. **Regularly rotate passwords** for service accounts
4. **Monitor registry access logs** for suspicious activity
5. **Consider using HTTPS** for production environments

## Expected Pipeline Behavior

With proper credentials configured:

1. ✅ Registry connectivity test passes
2. ✅ Authentication succeeds during push stage
3. ✅ Images are pushed successfully
4. ✅ Pipeline continues to deployment stages

The pipeline will provide detailed feedback about authentication status and any issues that occur.
