# Jenkins Kubernetes Credential Setup - Step by Step

## 🎯 **Objective**
Set up the Jenkins credential to connect to your k3s Kubernetes cluster.

## 📋 **Steps to Follow**

### Step 1: Access Jenkins Credentials
1. Open Jenkins: `http://192.168.1.153:8080`
2. Go to **Manage Jenkins** → **Manage Credentials**
3. Click on **System** → **Global credentials (unrestricted)**

### Step 2: Create or Update the Credential
1. If `k8s-kubeconfig` credential exists:
   - Click on it → **Update**
2. If it doesn't exist:
   - Click **Add Credentials**

### Step 3: Configure the Credential
**Important:** Use these exact settings:

- **Kind**: `Secret text`
- **Scope**: `Global`
- **Secret**: Copy and paste the ENTIRE content from `kubeconfig-fixed.yaml`
- **ID**: `k8s-kubeconfig` (must match exactly)
- **Description**: `Kubernetes Cluster Access - k3s`

### Step 4: Verify the Server IP
Make sure the kubeconfig contains the correct server IP. It should be:
```
server: https://192.168.1.153:6443
```

**If your k3s server has a different IP, update it in the kubeconfig before pasting.**

### Step 5: Test the Credential
After saving, test the connection:

1. Go to **Manage Jenkins** → **Script Console**
2. Run this test script:

```groovy
withCredentials([string(credentialsId: 'k8s-kubeconfig', variable: 'KUBECONFIG_CONTENT')]) {
    writeFile file: '/tmp/test-kubeconfig', text: env.KUBECONFIG_CONTENT
    def result = sh(script: 'KUBECONFIG=/tmp/test-kubeconfig kubectl cluster-info', returnStatus: true)
    if (result == 0) {
        println "✅ Kubernetes connection successful!"
        sh 'KUBECONFIG=/tmp/test-kubeconfig kubectl get nodes'
    } else {
        println "❌ Kubernetes connection failed!"
        println "Check if kubectl is installed and the server IP is correct"
    }
    sh 'rm -f /tmp/test-kubeconfig'
}
```

### Step 6: Trigger the Pipeline
1. Go to your pipeline: **forgejo-docker-k8s-pipeline**
2. Click **Build Now**
3. Monitor the console output

## 🔧 **Troubleshooting**

### If kubectl is not found:
Install kubectl on Jenkins server:
```bash
# On Jenkins server (Debian/Ubuntu)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

### If connection times out:
1. Verify the server IP is correct
2. Check if port 6443 is accessible from Jenkins server:
   ```bash
   # Test from Jenkins server
   telnet 192.168.1.153 6443
   ```
3. Check k3s server firewall settings

### If certificate errors:
1. Verify the certificate data is complete and not truncated
2. Make sure there are no extra spaces or characters

## 📝 **Expected Pipeline Behavior**

After fixing the credential, the pipeline should:
1. ✅ Pass the "Build Docker Images" stage
2. ✅ Pass the "Security Scan" stage  
3. ✅ Now reach the "Push Docker Images" stage
4. 🔄 Potentially fail on Kubernetes deployment (which we'll fix next)

## ⚡ **Quick Fix Summary**

**Current Issue**: `kubeconfigFile` method not found
**Solution**: Use `string` credential with kubeconfig content
**Action Required**: 
1. Create/update Jenkins credential as **Secret text**
2. Use the corrected kubeconfig with proper server IP
3. Test and run the pipeline

---

**🎯 Your Next Step**: Set up the credential in Jenkins using the content from `kubeconfig-fixed.yaml`
