# Docker Registry Troubleshooting Guide

## Current Issue: Registry Returns 401 Unauthorized

Based on the error logs, the Docker registry at `192.168.1.150:3000` is returning authentication errors. Here's how to fix it:

## 🔍 Root Cause Analysis

The registry is running but configured to require authentication, while the Jenkins pipeline expects anonymous access.

## 🛠️ Solution Options

### Option 1: Configure Registry for Anonymous Access (Recommended)

#### Step 1: Check Registry Configuration
SSH to the registry server (`192.168.1.150`) and check the current setup:

```bash
ssh [user]@192.168.1.150

# Check if registry is running
docker ps | grep registry

# Check docker-compose configuration
cat docker-compose.yml
```

#### Step 2: Update Registry Configuration

Create or update `docker-compose.yml` on the registry server:

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
      # Allow anonymous access
      REGISTRY_AUTH: ""
      REGISTRY_STORAGE_DELETE_ENABLED: true
      # Optional: Configure storage
      REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY: /var/lib/registry
    volumes:
      - registry-data:/var/lib/registry
    networks:
      - registry-net

volumes:
  registry-data:

networks:
  registry-net:
    driver: bridge
```

#### Step 3: Restart Registry
```bash
# Stop current registry
docker-compose down

# Start with new configuration
docker-compose up -d

# Verify it's running
docker ps | grep registry
```

#### Step 4: Test Registry Access
```bash
# Test anonymous access
curl http://192.168.1.150:3000/v2/

# Should return: {} (empty JSON, not an error)
```

### Option 2: Add Authentication to Jenkins

If you prefer to keep authentication enabled:

#### Step 1: Create Registry Credentials
On the registry server, create an htpasswd file:

```bash
# Install htpasswd if not available
sudo apt-get update && sudo apt-get install apache2-utils

# Create credentials directory
mkdir -p ~/registry-auth

# Create user (replace 'jenkins' and 'password' with your preferred credentials)
htpasswd -Bbn jenkins password > ~/registry-auth/htpasswd
```

#### Step 2: Update Registry Configuration
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
      - ~/registry-auth:/auth
      - registry-data:/var/lib/registry

volumes:
  registry-data:
```

#### Step 3: Add Credentials to Jenkins
1. Go to Jenkins → Manage Jenkins → Manage Credentials
2. Add new Username/Password credential:
   - ID: `docker-registry-credentials`
   - Username: `jenkins` (or whatever you chose)
   - Password: `password` (or whatever you chose)

#### Step 4: Update Jenkinsfile
The current Jenkinsfile will automatically try to authenticate if credentials are available.

## 🔧 Quick Fix Commands

### For Anonymous Access (Easiest):
```bash
# On registry server (192.168.1.150)
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  registry:
    image: registry:2
    container_name: docker-registry
    restart: unless-stopped
    ports:
      - "3000:5000"
    environment:
      REGISTRY_AUTH: ""
      REGISTRY_STORAGE_DELETE_ENABLED: true
    volumes:
      - registry-data:/var/lib/registry

volumes:
  registry-data:
EOF

# Restart registry
docker-compose down
docker-compose up -d

# Test
curl http://localhost:3000/v2/
```

### Test Push from Jenkins Server:
```bash
# On Jenkins server (192.168.1.153)
docker pull hello-world
docker tag hello-world 192.168.1.150:3000/test:latest
docker push 192.168.1.150:3000/test:latest

# Should succeed without errors
```

## 🔍 Verification Steps

After applying the fix:

1. **Test Registry API Access:**
   ```bash
   curl http://192.168.1.150:3000/v2/
   # Should return: {}
   ```

2. **Test Manual Push:**
   ```bash
   docker pull nginx:alpine
   docker tag nginx:alpine 192.168.1.150:3000/test:latest
   docker push 192.168.1.150:3000/test:latest
   # Should succeed
   ```

3. **List Registry Contents:**
   ```bash
   curl http://192.168.1.150:3000/v2/_catalog
   # Should show: {"repositories":["test"]}
   ```

4. **Run Jenkins Pipeline:**
   The pipeline should now complete successfully through the "Push Images" stage.

## 🚨 Common Issues

### Issue: "Connection refused"
**Solution:** Registry container is not running
```bash
docker-compose up -d
```

### Issue: "No route to host"
**Solution:** Firewall blocking port 3000
```bash
# Check if port is open
sudo ufw status
sudo ufw allow 3000/tcp
```

### Issue: "Certificate verify failed" 
**Solution:** Registry not configured for HTTP
- Ensure using HTTP (not HTTPS) URLs
- Docker daemon configured for insecure registry (already done)

### Issue: Registry still returns 401
**Solution:** Clear Docker login cache
```bash
docker logout 192.168.1.150:3000
rm -f ~/.docker/config.json
```

## 🎯 Expected Result

After fixing the registry configuration:
- ✅ `curl http://192.168.1.150:3000/v2/` returns `{}`
- ✅ Manual `docker push` succeeds
- ✅ Jenkins pipeline completes successfully
- ✅ Images appear in registry catalog

The registry will accept anonymous pushes and the Jenkins pipeline will work without authentication issues.
