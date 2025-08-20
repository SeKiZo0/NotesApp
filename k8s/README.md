# Kubernetes Deployment Guide

## Overview
The backend is now properly configured to connect to PostgreSQL with enhanced security and reliability.

## Key Improvements Made

### 1. Security Enhancements
- **Secrets Management**: Database password moved from ConfigMap to Secret
- **Base64 Encoding**: Sensitive data properly encoded
- **Separation of Concerns**: Non-sensitive config in ConfigMap, sensitive in Secrets

### 2. Connection Reliability
- **Init Container**: Waits for PostgreSQL service before starting backend
- **Enhanced Health Checks**: Uses `/api/health/db` endpoint to verify database connectivity
- **Proper Timeouts**: Added failure thresholds and timeout configurations
- **SubPath Mount**: PostgreSQL data stored in subdirectory to avoid permission issues

### 3. Configuration Details

#### Backend Environment Variables:
```yaml
ConfigMap (backend-config):
- NODE_ENV: production
- PORT: 5000
- DB_HOST: postgres-service  # Points to PostgreSQL service
- DB_PORT: 5432
- DB_NAME: notesdb
- DB_USER: postgres

Secret (backend-secrets):
- DB_PASSWORD: [base64 encoded password]
```

#### PostgreSQL Configuration:
```yaml
ConfigMap (postgres-config):
- POSTGRES_DB: notesdb
- POSTGRES_USER: postgres

Secret (postgres-secrets):
- POSTGRES_PASSWORD: [base64 encoded password]
```

## Deployment Order

1. **PostgreSQL** (postgres-deployment.yaml)
   - Creates database with persistent storage
   - Exposes service on port 5432

2. **Backend** (backend-deployment.yaml)
   - Waits for PostgreSQL to be ready
   - Connects using service discovery
   - Creates tables automatically on startup

3. **Frontend** (frontend-deployment.yaml)
   - Serves static files via nginx
   - Connects to backend API

## Quick Deploy

```bash
# Deploy everything
cd k8s
chmod +x deploy.sh
./deploy.sh

# Or deploy manually
kubectl apply -f postgres-deployment.yaml
kubectl apply -f backend-deployment.yaml
kubectl apply -f frontend-deployment.yaml
```

## Verify Connection

```bash
# Check if backend can connect to database
kubectl exec deployment/backend-deployment -- curl -f http://localhost:5000/api/health/db

# Check PostgreSQL directly
kubectl exec deployment/postgres-deployment -- pg_isready -U postgres

# View logs
kubectl logs deployment/backend-deployment
kubectl logs deployment/postgres-deployment
```

## Troubleshooting

### Backend Can't Connect to PostgreSQL
1. Check if PostgreSQL service is running:
   ```bash
   kubectl get svc postgres-service
   ```

2. Verify PostgreSQL pod is ready:
   ```bash
   kubectl get pods -l app=postgres
   ```

3. Check backend logs:
   ```bash
   kubectl logs deployment/backend-deployment
   ```

4. Test connection manually:
   ```bash
   kubectl exec deployment/backend-deployment -- nc -z postgres-service 5432
   ```

### Database Connection Refused
1. Check PostgreSQL configuration:
   ```bash
   kubectl describe configmap postgres-config
   kubectl describe secret postgres-secrets
   ```

2. Verify environment variables in backend:
   ```bash
   kubectl exec deployment/backend-deployment -- env | grep DB_
   ```

## Production Considerations

### Security
- Change default password before production deployment
- Use external secret management (HashiCorp Vault, AWS Secrets Manager)
- Enable TLS for database connections

### High Availability
- Configure PostgreSQL replication
- Use StatefulSet for PostgreSQL in production
- Implement database backups

### Monitoring
- Add Prometheus metrics
- Configure alerting for database connectivity
- Monitor connection pool metrics

## Custom Configuration

To use your own PostgreSQL server, update the backend ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
data:
  DB_HOST: "your-postgres-host"
  DB_PORT: "5432"
  DB_NAME: "your-database"
  DB_USER: "your-username"
  # Add DB_PASSWORD to Secret instead
```
