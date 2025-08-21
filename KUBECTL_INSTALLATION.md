# Installing kubectl on Jenkins Server

## 🎯 **Problem**
Jenkins pipeline fails with: `kubectl: not found`

## 📋 **Solution: Install kubectl on Jenkins Server**

### Method 1: Direct Installation on Jenkins Server

SSH to your Jenkins server (192.168.1.153) and run:

```bash
# Download kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Make it executable
chmod +x kubectl

# Move to system PATH
sudo mv kubectl /usr/local/bin/

# Verify installation
kubectl version --client
```

### Method 2: Using Package Manager (Debian/Ubuntu)

```bash
# Update package index
sudo apt-get update

# Install required packages
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

# Add Kubernetes GPG key
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add Kubernetes repository
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update package index
sudo apt-get update

# Install kubectl
sudo apt-get install -y kubectl
```

### Method 3: Docker-based kubectl (Alternative)

If you don't want to install kubectl directly, modify the Jenkinsfile to use Docker:

```groovy
// Instead of: kubectl get pods
// Use: docker run --rm -v ${WORKSPACE}/.kubeconfig:/root/.kube/config bitnami/kubectl:latest get pods
```

## 🔧 **Verification Steps**

After installation, verify kubectl works:

```bash
# Test kubectl installation
kubectl version --client

# Test with your kubeconfig (as jenkins user)
sudo -u jenkins kubectl --kubeconfig=/path/to/kubeconfig get nodes
```

## ⚠️ **Important Notes**

1. **User Permissions**: Ensure the jenkins user can execute kubectl
2. **PATH Issues**: kubectl must be in the system PATH
3. **Alternative**: Consider using external PostgreSQL instead (much simpler!)

---

**Recommendation**: Use external PostgreSQL for simpler setup and better reliability.
