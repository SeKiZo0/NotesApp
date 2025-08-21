# External PostgreSQL Configuration Guide

## 🎯 **Why Use External PostgreSQL?**

✅ **Simpler Setup**: No Kubernetes deployment needed
✅ **Better Performance**: Dedicated database server
✅ **Easier Backup**: Standard database backup procedures
✅ **Less Resource Usage**: No database pods in Kubernetes
✅ **More Reliable**: Separate from application lifecycle

## 📋 **Prerequisites**

You need a PostgreSQL server accessible from your Kubernetes cluster. Options:

### Option A: Install PostgreSQL on a Dedicated Server
```bash
# On Ubuntu/Debian server (e.g., 192.168.1.202):
sudo apt update
sudo apt install postgresql postgresql-contrib

# Configure PostgreSQL
sudo -u postgres psql -c "CREATE DATABASE notesdb;"
sudo -u postgres psql -c "CREATE USER notesuser WITH PASSWORD 'your_secure_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE notesdb TO notesuser;"
```

### Option B: Use Docker PostgreSQL on a Server
```bash
# On any server with Docker:
docker run -d \
  --name postgres-notes \
  --restart unless-stopped \
  -e POSTGRES_DB=notesdb \
  -e POSTGRES_USER=notesuser \
  -e POSTGRES_PASSWORD=your_secure_password \
  -p 5432:5432 \
  -v postgres_data:/var/lib/postgresql/data \
  postgres:15
```

### Option C: Use Existing Database Server
If you already have a PostgreSQL server, just create the database and user.

## 🔧 **Configuration Steps**

### Step 1: Update Backend Environment Variables

The backend needs these environment variables:
```bash
DB_HOST=192.168.1.202        # Your PostgreSQL server IP
DB_PORT=5432                 # PostgreSQL port
DB_NAME=notesdb              # Database name
DB_USER=notesuser            # Database user
DB_PASSWORD=your_secure_password  # Database password
```

### Step 2: Update Jenkinsfile

We need to modify the Jenkinsfile to:
1. Skip PostgreSQL deployment in Kubernetes
2. Use external database connection
3. Install kubectl on Jenkins (or use Docker-based approach)

### Step 3: Configure Network Access

Ensure your Kubernetes cluster can reach the PostgreSQL server:
- Open port 5432 on the PostgreSQL server
- Configure PostgreSQL to accept connections from Kubernetes nodes
- Update `postgresql.conf` and `pg_hba.conf` if needed

## 📝 **Updated Configuration Files**

### Backend Deployment (k8s/backend-deployment.yaml)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-deployment
  namespace: notes-app-staging
spec:
  replicas: 2
  selector:
    matchLabels:
      app: notes-app-backend
  template:
    metadata:
      labels:
        app: notes-app-backend
    spec:
      containers:
      - name: backend
        image: 192.168.1.150:3000/notes-app-backend:latest
        ports:
        - containerPort: 5000
        env:
        - name: DB_HOST
          value: "192.168.1.202"  # Your PostgreSQL server IP
        - name: DB_PORT
          value: "5432"
        - name: DB_NAME
          value: "notesdb"
        - name: DB_USER
          value: "notesuser"
        - name: DB_PASSWORD
          value: "your_secure_password"  # Use secrets in production
        - name: PORT
          value: "5000"
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
```

## 🔒 **Security Best Practices**

### Use Kubernetes Secrets (Recommended)
Instead of hardcoding passwords, use Kubernetes secrets:

```bash
# Create secret for database credentials
kubectl create secret generic postgres-credentials \
  --from-literal=host=192.168.1.202 \
  --from-literal=port=5432 \
  --from-literal=database=notesdb \
  --from-literal=username=notesuser \
  --from-literal=password=your_secure_password \
  -n notes-app-staging
```

Then reference in deployment:
```yaml
env:
- name: DB_HOST
  valueFrom:
    secretKeyRef:
      name: postgres-credentials
      key: host
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: postgres-credentials
      key: password
# ... other env vars from secret
```

## 🧪 **Testing Connection**

Test connectivity from a Kubernetes pod:
```bash
# Run a test pod
kubectl run postgres-test --image=postgres:15 --rm -it --restart=Never -- bash

# Inside the pod, test connection
psql -h 192.168.1.202 -U notesuser -d notesdb
```

## ✅ **Benefits Summary**

- **No kubectl installation needed** on Jenkins for database setup
- **Simpler pipeline** - just deploy apps, not database
- **Better separation of concerns** - data persistence separate from apps
- **Easier scaling** - database independent of Kubernetes scaling
- **Standard backup procedures** - use regular PostgreSQL backup tools

---

**Next Step**: Choose your PostgreSQL setup method and update the configuration!
