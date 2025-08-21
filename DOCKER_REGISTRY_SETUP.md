# Docker Registry Configuration for Jenkins

## Problem
The Jenkins pipeline fails at the "Push Images" stage with the error:
```
❌ Push failed - Docker daemon needs configuration
```

This happens because the Docker daemon on the Jenkins server isn't configured to work with the insecure Docker registry at `192.168.1.150:3000`.

## Root Cause
Docker, by default, only allows pushes to HTTPS registries or localhost. When using an HTTP registry (like `192.168.1.150:3000`), you must explicitly configure Docker to allow "insecure registries".

## Solution 1: Configure Docker Daemon (Recommended)

### Step 1: Access Jenkins Server
```bash
ssh [username]@192.168.1.153
```

### Step 2: Edit Docker Daemon Configuration
```bash
sudo nano /etc/docker/daemon.json
```

### Step 3: Add Insecure Registry Configuration
Add this exact content to `/etc/docker/daemon.json`:
```json
{
  "insecure-registries": ["192.168.1.150:3000"]
}
```

If the file already exists with other settings, merge them:
```json
{
  "insecure-registries": ["192.168.1.150:3000"],
  "other-existing-setting": "value"
}
```

### Step 4: Restart Docker Service
```bash
sudo systemctl restart docker
```

### Step 5: Restart Jenkins Service
```bash
sudo systemctl restart jenkins
```

### Step 6: Verify Configuration
```bash
docker info | grep -A5 "Insecure Registries"
```

You should see:
```
Insecure Registries:
 192.168.1.150:3000
 127.0.0.0/8
```

### Step 7: Test Manual Push (Optional)
```bash
# Test that manual push works
docker pull nginx:alpine
docker tag nginx:alpine 192.168.1.150:3000/test:latest
docker push 192.168.1.150:3000/test:latest
docker rmi 192.168.1.150:3000/test:latest
```

### Step 8: Re-run Jenkins Pipeline
The pipeline should now complete successfully.

## Solution 2: Set Up HTTPS/TLS (More Secure)

If you prefer a more secure approach, configure the Docker registry with HTTPS:

### Step 1: Generate SSL Certificates
```bash
# On registry server (192.168.1.150)
sudo openssl req -newkey rsa:4096 -nodes -sha256 -keyout /etc/ssl/private/registry.key -x509 -days 365 -out /etc/ssl/certs/registry.crt
```

### Step 2: Update Registry Configuration
Update your Docker registry to use HTTPS in `docker-compose.yml`:
```yaml
version: '3.8'
services:
  registry:
    image: registry:2
    ports:
      - "443:5000"
    environment:
      REGISTRY_HTTP_TLS_CERTIFICATE: /certs/registry.crt
      REGISTRY_HTTP_TLS_KEY: /certs/registry.key
    volumes:
      - /etc/ssl/certs/registry.crt:/certs/registry.crt
      - /etc/ssl/private/registry.key:/certs/registry.key
```

### Step 3: Update Pipeline
Change the registry URL in Jenkinsfile:
```groovy
DOCKER_REGISTRY = 'https://192.168.1.150'
```

## Troubleshooting

### Issue: "Connection refused"
**Cause**: Registry service isn't running
**Solution**: 
```bash
# Check registry status
docker ps | grep registry
# Or restart registry
docker-compose up -d
```

### Issue: "Certificate verify failed"
**Cause**: TLS certificate issues
**Solution**: Either fix certificates or use insecure registry configuration

### Issue: "No such host"
**Cause**: DNS resolution problems
**Solution**: 
```bash
# Test connectivity
ping 192.168.1.150
curl http://192.168.1.150:3000/v2/
```

### Issue: Jenkins pipeline still fails after configuration
**Cause**: Jenkins service wasn't restarted
**Solution**:
```bash
sudo systemctl restart jenkins
# Wait 2-3 minutes for Jenkins to fully restart
```

## Security Considerations

- **Insecure Registry**: Data transmitted in plain text, vulnerable to man-in-the-middle attacks
- **HTTPS Registry**: Encrypted transmission, recommended for production
- **Network Security**: Ensure registry is only accessible within your trusted network

## Testing the Fix

After implementing the solution, you can verify it works by:

1. Running the Jenkins pipeline again
2. Checking the "Push Images" stage completes successfully
3. Verifying images appear in the registry:
   ```bash
   curl http://192.168.1.150:3000/v2/_catalog
   ```

## Related Files
- `Jenkinsfile` - Contains the pipeline configuration
- `docker-compose.yml` - Registry service configuration
- `/etc/docker/daemon.json` - Docker daemon configuration on Jenkins server
