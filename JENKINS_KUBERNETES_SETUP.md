# Jenkins Kubernetes Credentials Setup Guide

## Problem Solution
The Jenkins pipeline was failing with the error:
```
No such DSL method 'kubeconfigFile' found
```

This indicates that the **Kubernetes CLI Plugin** is not installed in Jenkins.

## Solution Options

### Option 1: Install Kubernetes CLI Plugin (Recommended)
1. Go to Jenkins → **Manage Jenkins** → **Manage Plugins**
2. Click on the **Available** tab
3. Search for "**Kubernetes CLI**"
4. Check the box next to "**Kubernetes CLI Plugin**"
5. Click **Install without restart** or **Download now and install after restart**

After installation, change the Jenkinsfile back to use `kubeconfigFile`:
```groovy
withCredentials([kubeconfigFile(credentialsId: K8S_CREDENTIALS, variable: 'KUBECONFIG')]) {
    // kubectl commands here
}
```

### Option 2: Use Secret Text Credential (Current Implementation)
If you cannot install the plugin, the Jenkinsfile has been updated to use a different approach:

#### Step 1: Create Secret Text Credential
1. Go to Jenkins → **Manage Jenkins** → **Manage Credentials**
2. Select the appropriate domain (usually "Global")
3. Click **Add Credentials**
4. Select **Secret text** as the credential type
5. Set the following:
   - **Secret**: Paste your entire kubeconfig file content
   - **ID**: `k8s-kubeconfig` (must match the Jenkinsfile)
   - **Description**: Kubernetes Cluster Access

#### Step 2: Get Your Kubeconfig Content
Depending on your Kubernetes setup:

**For k3s:**
```bash
sudo cat /etc/rancher/k3s/k3s.yaml
```

**For standard Kubernetes:**
```bash
cat ~/.kube/config
```

**For microk8s:**
```bash
microk8s config
```

**For cloud providers (GKE, EKS, AKS):**
```bash
# After setting up cloud CLI tools
cat ~/.kube/config
```

#### Step 3: Important Notes
- Make sure the server URL in your kubeconfig points to an IP address accessible from Jenkins
- If using k3s, change `127.0.0.1` to your actual server IP
- The kubeconfig should have sufficient permissions to create namespaces and deploy applications

## How the Updated Jenkinsfile Works

The updated Jenkinsfile now:
1. Gets the kubeconfig content from Jenkins secret text credential
2. Writes it to a temporary `.kubeconfig` file in the workspace
3. Sets the `KUBECONFIG` environment variable to point to this file
4. Runs kubectl commands using this configuration

```groovy
withCredentials([string(credentialsId: K8S_CREDENTIALS, variable: 'KUBECONFIG_CONTENT')]) {
    // Write kubeconfig content to temporary file
    writeFile file: '.kubeconfig', text: env.KUBECONFIG_CONTENT
    env.KUBECONFIG = "${env.WORKSPACE}/.kubeconfig"
    
    sh """
        kubectl get nodes
        # Other kubectl commands...
    """
}
```

## Testing the Setup

After setting up the credentials, test the connection:

1. Go to Jenkins → **Manage Jenkins** → **Script Console**
2. Run this test script:
```groovy
withCredentials([string(credentialsId: 'k8s-kubeconfig', variable: 'KUBECONFIG_CONTENT')]) {
    writeFile file: '/tmp/test-kubeconfig', text: env.KUBECONFIG_CONTENT
    def result = sh(script: 'KUBECONFIG=/tmp/test-kubeconfig kubectl cluster-info', returnStatus: true)
    if (result == 0) {
        println "✅ Kubernetes connection successful!"
    } else {
        println "❌ Kubernetes connection failed!"
    }
    sh 'rm -f /tmp/test-kubeconfig'
}
```

## Troubleshooting

### Common Issues:

1. **"kubectl: command not found"**
   - Install kubectl on the Jenkins agent
   - Or use a Docker container with kubectl

2. **"Unable to connect to the server"**
   - Check if the server URL in kubeconfig is accessible from Jenkins
   - Verify network connectivity between Jenkins and Kubernetes

3. **Permission denied errors**
   - Ensure the kubeconfig user has sufficient permissions
   - Consider creating a dedicated service account for Jenkins

4. **Certificate issues**
   - Verify certificate-authority-data in kubeconfig is correct
   - Check if certificates are valid and not expired

## Next Steps

1. Set up the credentials using Option 1 or Option 2
2. Test the connection using the test script
3. Run the Jenkins pipeline to verify deployment works
4. Monitor the build logs for any remaining issues

## Security Best Practices

- Use a dedicated service account for Jenkins with minimal required permissions
- Regularly rotate the kubeconfig credentials
- Consider using short-lived tokens instead of long-lived certificates
- Restrict Jenkins access to specific namespaces only
