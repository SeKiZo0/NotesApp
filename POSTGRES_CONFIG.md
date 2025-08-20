# PostgreSQL Configuration for Notes App

## Overview

The Notes App uses PostgreSQL as its primary database with the following configuration:

### 📋 Database Details
- **Database Name**: `notesdb`
- **Database User**: `postgres`
- **Database Password**: Stored in Kubernetes Secret (base64: `cGFzc3dvcmQ=` = "password")
- **Port**: `5432`
- **Service Name**: `postgres-service`

### 🔗 Connection Details

#### From Backend Application:
```bash
Host: postgres-service
Port: 5432
Database: notesdb
User: postgres
Password: [from Kubernetes secret]
```

#### Full Service DNS (within cluster):
```bash
postgres-service.{namespace}.svc.cluster.local:5432
```

## 🏗️ Kubernetes Configuration

### ConfigMap (postgres-config)
```yaml
POSTGRES_DB: notesdb
POSTGRES_USER: postgres
```

### Secret (postgres-secrets)
```yaml
POSTGRES_PASSWORD: cGFzc3dvcmQ=  # base64 encoded 'password'
```

### Backend Environment Variables
```yaml
DB_HOST: postgres-service
DB_PORT: 5432
DB_NAME: notesdb
DB_USER: postgres
DB_PASSWORD: [from secret]
```

## 🚀 Jenkins Pipeline Integration

The Jenkins pipeline handles PostgreSQL deployment and verification:

### 1. PostgreSQL Deployment
```groovy
// Deploys PostgreSQL only if not already exists
if ! kubectl get deployment postgres-deployment -n ${namespace}; then
    kubectl apply -f k8s/postgres-deployment.yaml -n ${namespace}
    kubectl wait --for=condition=available deployment/postgres-deployment -n ${namespace}
fi
```

### 2. Connection Verification
```groovy
// Tests PostgreSQL connectivity
kubectl exec deployment/postgres-deployment -n ${namespace} -- pg_isready -U postgres

// Tests backend database connection
kubectl exec deployment/backend-deployment -n ${namespace} -- curl -f http://localhost:5000/api/health/db
```

### 3. Database Health Checks
The pipeline includes a dedicated stage for database verification:
- PostgreSQL pod status
- Database connectivity test
- Backend API database health check
- Connection summary

## 🛠️ Database Operations

### Using the Helper Script
```bash
# Check PostgreSQL status
./scripts/postgres-ops.sh notes-app-staging status

# Test connectivity
./scripts/postgres-ops.sh notes-app-staging connect

# View logs
./scripts/postgres-ops.sh notes-app-staging logs

# Open database shell
./scripts/postgres-ops.sh notes-app-staging shell

# Create backup
./scripts/postgres-ops.sh notes-app-staging backup

# Test backend connection
./scripts/postgres-ops.sh notes-app-staging test-backend
```

### Manual Commands
```bash
# Check PostgreSQL pod
kubectl get pods -l app=postgres -n notes-app-staging

# Test PostgreSQL connectivity
kubectl exec deployment/postgres-deployment -n notes-app-staging -- pg_isready -U postgres

# Connect to database
kubectl exec -it deployment/postgres-deployment -n notes-app-staging -- psql -U postgres -d notesdb

# View PostgreSQL logs
kubectl logs deployment/postgres-deployment -n notes-app-staging

# Test backend health
kubectl exec deployment/backend-deployment -n notes-app-staging -- curl -f http://localhost:5000/api/health/db
```

## 🔧 Database Schema

The backend automatically creates the required table on startup:

```sql
CREATE TABLE IF NOT EXISTS notes (
    id UUID PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Backend Can't Connect to PostgreSQL
**Symptoms:**
- Backend health check fails: `/api/health/db` returns 500
- Backend logs show connection errors

**Solutions:**
```bash
# Check if PostgreSQL service exists
kubectl get svc postgres-service -n notes-app-staging

# Verify PostgreSQL is ready
kubectl exec deployment/postgres-deployment -n notes-app-staging -- pg_isready -U postgres

# Check backend environment variables
kubectl exec deployment/backend-deployment -n notes-app-staging -- env | grep DB_

# Verify secrets are mounted correctly
kubectl describe secret backend-secrets -n notes-app-staging
```

#### 2. PostgreSQL Pod Not Starting
**Symptoms:**
- PostgreSQL pod in CrashLoopBackOff
- Database connection timeouts

**Solutions:**
```bash
# Check pod status and events
kubectl describe pod -l app=postgres -n notes-app-staging

# View PostgreSQL logs
kubectl logs deployment/postgres-deployment -n notes-app-staging

# Check persistent volume
kubectl get pvc postgres-pvc -n notes-app-staging

# Verify secrets
kubectl get secret postgres-secrets -n notes-app-staging -o yaml
```

#### 3. Password Authentication Failed
**Symptoms:**
- `FATAL: password authentication failed` in logs
- Backend can't authenticate to database

**Solutions:**
```bash
# Verify password secret
kubectl get secret postgres-secrets -n notes-app-staging -o yaml
echo "cGFzc3dvcmQ=" | base64 -d  # Should output: password

# Verify backend secret
kubectl get secret backend-secrets -n notes-app-staging -o yaml

# Check if secrets match
kubectl exec deployment/postgres-deployment -n notes-app-staging -- env | grep POSTGRES_PASSWORD
kubectl exec deployment/backend-deployment -n notes-app-staging -- env | grep DB_PASSWORD
```

#### 4. Init Container Fails
**Symptoms:**
- Backend pod stuck in Init state
- "Waiting for postgres..." message

**Solutions:**
```bash
# Check init container logs
kubectl logs deployment/backend-deployment -n notes-app-staging -c wait-for-postgres

# Test network connectivity
kubectl exec deployment/backend-deployment -n notes-app-staging -c wait-for-postgres -- nc -z postgres-service 5432

# Verify service discovery
kubectl exec deployment/backend-deployment -n notes-app-staging -c wait-for-postgres -- nslookup postgres-service
```

## 🔒 Security Considerations

### Production Recommendations

1. **Change Default Password**
   ```bash
   # Create new password secret
   echo -n "your-secure-password" | base64
   # Update both postgres-secrets and backend-secrets
   ```

2. **Use External Secret Management**
   - HashiCorp Vault
   - AWS Secrets Manager
   - Azure Key Vault
   - Google Secret Manager

3. **Enable TLS**
   - Configure PostgreSQL with SSL certificates
   - Update connection strings to use SSL

4. **Network Policies**
   ```yaml
   # Only allow backend to access PostgreSQL
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: postgres-network-policy
   spec:
     podSelector:
       matchLabels:
         app: postgres
     ingress:
     - from:
       - podSelector:
           matchLabels:
             app: backend
   ```

## 📊 Monitoring

### Key Metrics to Monitor
- PostgreSQL connection count
- Database size and growth
- Query performance
- Backup status
- Disk usage

### Health Check Endpoints
- Backend: `GET /api/health/db`
- PostgreSQL: `pg_isready -U postgres`

### Backup Strategy
```bash
# Automated backup (add to Jenkins pipeline)
kubectl exec deployment/postgres-deployment -n notes-app-prod -- pg_dump -U postgres notesdb > backup-$(date +%Y%m%d).sql

# Store in external storage (S3, GCS, etc.)
```

## 🔄 Environment-Specific Configuration

### Staging Environment
- Namespace: `notes-app-staging`
- Smaller resource limits
- Development data

### Production Environment
- Namespace: `notes-app-prod`
- Higher resource limits
- Production data
- Backup schedule
- Monitoring alerts

### Environment Variables by Stage
The Jenkins pipeline automatically sets the correct PostgreSQL connection details for each environment using the same service name but different namespaces.
