# Notes App

A full-stack notes application with vanilla JavaScript frontend, Node.js backend, PostgreSQL database, and Kubernetes deployment.

## 🏗️ Architecture

```
Frontend (Static Files) -> Backend API (Node.js/Express) -> PostgreSQL Database
```

## 📁 Project Structure

```
notes-app/
├── frontend/                    # Static frontend files
│   ├── package.json            # Frontend dependencies
│   ├── index.html              # Main HTML file
│   ├── style.css               # Responsive styles
│   └── script.js               # JavaScript application logic
├── backend/                     # Node.js API server
│   ├── package.json            # Backend dependencies
│   ├── server.js               # Express server setup
│   ├── .env.example            # Environment variables template
│   └── routes/
│       └── notes.js            # Notes CRUD API routes
├── k8s/                        # Kubernetes manifests
│   ├── postgres-deployment.yaml # PostgreSQL database
│   ├── backend-deployment.yaml  # Backend API
│   ├── frontend-deployment.yaml # Frontend web server
│   ├── deploy.sh               # Deployment script
│   └── README.md               # K8s deployment guide
├── scripts/                    # Utility scripts
│   └── postgres-ops.sh         # PostgreSQL operations
├── Dockerfile.frontend         # Frontend container
├── Dockerfile.backend          # Backend container
├── docker-compose.yml          # Local development
├── Jenkinsfile                 # CI/CD pipeline (Forgejo)
├── JENKINS_SETUP.md            # Jenkins configuration guide
├── POSTGRES_CONFIG.md          # PostgreSQL documentation
└── README.md                   # This file
```

## ✨ Features

- ✅ Create, read, update, delete notes
- ✅ Responsive web interface with modern design
- ✅ RESTful API with full CRUD operations
- ✅ PostgreSQL persistence with connection pooling
- ✅ Docker containerization with multi-stage builds
- ✅ Kubernetes deployment with health checks
- ✅ CI/CD pipeline with Forgejo integration
- ✅ Security scanning and vulnerability checks
- ✅ Environment-specific deployments (staging/production)
- ✅ Database health monitoring

## 🚀 Quick Start

### Using Docker Compose (Recommended)

```bash
# Clone the repository
git clone <your-repo-url>
cd notes-app

# Start the entire stack
docker-compose up -d

# Access the application
open http://localhost:3000
```

### Using Kubernetes

```bash
# Deploy to Kubernetes
cd k8s
chmod +x deploy.sh
./deploy.sh notes-app

# Access via ingress (configure DNS first)
open http://notes-app.local
```

## 💻 Local Development

### Prerequisites

- Node.js 18+
- PostgreSQL 15+
- Docker (optional)

### Backend Setup

1. **Navigate to backend directory:**
   ```bash
   cd backend
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Set up environment variables:**
   ```bash
   # Copy and edit environment file
   cp .env.example .env
   
   # Edit .env with your database details:
   DB_HOST=localhost
   DB_PORT=5432
   DB_NAME=notesdb
   DB_USER=postgres
   DB_PASSWORD=password
   PORT=5000
   NODE_ENV=development
   ```

4. **Start PostgreSQL and create database:**
   ```sql
   -- Connect to PostgreSQL
   psql -U postgres
   
   -- Create database
   CREATE DATABASE notesdb;
   ```

5. **Start the backend server:**
   ```bash
   # Development mode with auto-reload
   npm run dev
   
   # Or production mode
   npm start
   ```

   The backend will be available at: http://localhost:5000

### Frontend Setup

1. **Navigate to frontend directory:**
   ```bash
   cd frontend
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Start the development server:**
   ```bash
   npm start
   ```

4. **Open browser to:** http://localhost:3000

The frontend will automatically connect to the backend API.

## 🐳 Docker Development

### Build Images

```bash
# Build frontend image
docker build -f Dockerfile.frontend -t notes-app-frontend .

# Build backend image
docker build -f Dockerfile.backend -t notes-app-backend .
```

### Run with Docker Compose

The project includes a complete `docker-compose.yml` file:

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down

# Rebuild and start
docker-compose up -d --build
```

Services:
- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:5000
- **PostgreSQL**: localhost:5432

## ☸️ Kubernetes Deployment

### Prerequisites

- Kubernetes cluster (local or cloud)
- kubectl configured
- NGINX Ingress Controller (for ingress)

### Quick Deploy

```bash
# Use the deployment script
cd k8s
chmod +x deploy.sh
./deploy.sh notes-app

# Or deploy manually
kubectl apply -f postgres-deployment.yaml
kubectl apply -f backend-deployment.yaml
kubectl apply -f frontend-deployment.yaml
```

### Configure Local Access

For local development with ingress:

```bash
# Add to /etc/hosts (Linux/Mac) or C:\Windows\System32\drivers\etc\hosts (Windows)
127.0.0.1 notes-app.local
127.0.0.1 api.notes-app.local
```

### Access Points

- **Frontend**: http://notes-app.local
- **Backend API**: http://api.notes-app.local
- **Direct Services**: Use `kubectl port-forward`

## 🔌 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET    | `/api/notes` | Get all notes |
| GET    | `/api/notes/:id` | Get specific note |
| POST   | `/api/notes` | Create new note |
| PUT    | `/api/notes/:id` | Update note |
| DELETE | `/api/notes/:id` | Delete note |
| GET    | `/health` | Backend health check |
| GET    | `/api/health/db` | Database connectivity check |

### Example API Usage

```bash
# Get all notes
curl http://localhost:5000/api/notes

# Create a note
curl -X POST http://localhost:5000/api/notes \
  -H "Content-Type: application/json" \
  -d '{"title": "My Note", "content": "Note content here"}'

# Health check
curl http://localhost:5000/health
```

## 🔄 CI/CD Pipeline

The project includes a comprehensive Jenkins pipeline with Forgejo integration:

### Pipeline Stages

1. **Code Checkout** - Get latest code from Forgejo
2. **Testing** - Run tests and security audits
3. **Build** - Create Docker images with proper tagging
4. **Security Scan** - Vulnerability scanning with Trivy
5. **Push** - Push images to Forgejo registry
6. **Deploy** - Deploy to staging/production environments
7. **Database Verification** - Verify PostgreSQL connectivity
8. **Health Checks** - Comprehensive application health tests

### Branch Strategy

- **develop/dev** → Staging environment (`notes-app-staging`)
- **main/master** → Production environment (`notes-app-prod`) with manual approval

### Configuration

See [JENKINS_SETUP.md](JENKINS_SETUP.md) for detailed setup instructions.

Required Jenkins credentials:
- `forgejo-registry-credentials` - Forgejo registry access
- `k8s-kubeconfig` - Kubernetes cluster access

### Common Pipeline Issues

#### Docker Registry Push Failures

If you encounter this error:
```
❌ Push failed - Docker daemon needs configuration
```

This is because the Docker daemon on Jenkins isn't configured for the insecure registry. 

**Quick Fix:**
1. SSH to Jenkins server: `ssh [username]@192.168.1.153`
2. Run the provided fix script: `sudo bash scripts/fix-docker-registry.sh`

**Manual Fix:**
See [DOCKER_REGISTRY_SETUP.md](DOCKER_REGISTRY_SETUP.md) for detailed instructions.

The issue occurs because Docker requires explicit configuration to push to HTTP registries (non-HTTPS).

## 📊 Monitoring and Observability

### Health Checks

- **Backend**: `GET /health` - Application health
- **Database**: `GET /api/health/db` - PostgreSQL connectivity
- **Kubernetes**: Liveness and readiness probes configured

### Logging

```bash
# Application logs
kubectl logs -f deployment/backend-deployment -n notes-app
kubectl logs -f deployment/frontend-deployment -n notes-app

# PostgreSQL logs
kubectl logs -f deployment/postgres-deployment -n notes-app

# Docker Compose logs
docker-compose logs -f backend
```

### Database Operations

Use the included PostgreSQL operations script:

```bash
# Check database status
./scripts/postgres-ops.sh notes-app status

# Test connectivity
./scripts/postgres-ops.sh notes-app connect

# Create backup
./scripts/postgres-ops.sh notes-app backup

# Open database shell
./scripts/postgres-ops.sh notes-app shell
```

## 🔒 Security

- **Container Security**: Non-root user, minimal base images
- **Network Security**: CORS configuration, security headers
- **Secrets Management**: Kubernetes Secrets for sensitive data
- **Vulnerability Scanning**: Automated security scans in CI/CD
- **Input Validation**: Server-side validation for all API endpoints

## 🌐 Production Considerations

### Database

- **Managed Service**: Use AWS RDS, Google Cloud SQL, or Azure Database
- **Backups**: Automated daily backups with retention policy
- **Connection Pooling**: Configured in the backend application
- **Monitoring**: Database performance and connection metrics

### Scaling

- **Horizontal Pod Autoscaler**: Configure HPA for backend pods
- **Cluster Autoscaler**: Automatic node scaling
- **Load Balancing**: NGINX Ingress with proper load balancing
- **Caching**: Consider Redis for session storage and caching

### Security

- **HTTPS/TLS**: SSL certificates for all external endpoints
- **Authentication**: Implement user authentication and authorization
- **Network Policies**: Kubernetes network segmentation
- **Regular Updates**: Keep dependencies and base images updated

### Monitoring

- **Metrics**: Prometheus and Grafana for application metrics
- **Logging**: Centralized logging with ELK stack
- **Alerting**: Configure alerts for system and application issues
- **Tracing**: Distributed tracing with Jaeger

## 🛠️ Troubleshooting

### Common Issues

1. **Backend can't connect to PostgreSQL**
   ```bash
   # Check PostgreSQL status
   kubectl get pods -l app=postgres
   
   # Test connectivity
   kubectl exec deployment/backend-deployment -- curl -f http://localhost:5000/api/health/db
   ```

2. **Frontend can't reach backend**
   ```bash
   # Check backend service
   kubectl get svc backend-service
   
   # Port forward for testing
   kubectl port-forward svc/backend-service 5000:5000
   ```

3. **Docker build issues**
   ```bash
   # Clean Docker cache
   docker system prune -a
   
   # Rebuild with no cache
   docker-compose build --no-cache
   ```

### Debug Commands

```bash
# Check all resources
kubectl get all -n notes-app

# Describe problematic pods
kubectl describe pod <pod-name> -n notes-app

# Check events
kubectl get events -n notes-app --sort-by='.lastTimestamp'
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes with proper tests
4. Commit your changes: `git commit -am 'Add some feature'`
5. Push to the branch: `git push origin feature/your-feature`
6. Submit a pull request

### Development Guidelines

- Follow existing code style and conventions
- Add tests for new functionality
- Update documentation as needed
- Ensure all health checks pass

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📚 Additional Documentation

- [Jenkins Setup Guide](JENKINS_SETUP.md) - Detailed CI/CD configuration
- [PostgreSQL Configuration](POSTGRES_CONFIG.md) - Database setup and operations
- [Kubernetes Deployment Guide](k8s/README.md) - K8s deployment details

---

**Built with ❤️ using Node.js, PostgreSQL, and Kubernetes**
#   N o t e s A p p 
 
 