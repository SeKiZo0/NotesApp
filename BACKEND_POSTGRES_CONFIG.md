# PostgreSQL Configuration for External Database

## Backend Configuration Updates

Your backend needs to be updated to connect to the external PostgreSQL server. Here are the required changes:

### 1. Environment Variables in Kubernetes Deployment

Update your `k8s/backend-deployment.yaml` to include PostgreSQL connection environment variables:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: notes-backend
  template:
    metadata:
      labels:
        app: notes-backend
    spec:
      containers:
      - name: backend
        image: notes-app-backend:latest
        ports:
        - containerPort: 5000
        env:
        - name: NODE_ENV
          value: "production"
        - name: PORT
          value: "5000"
        - name: POSTGRES_HOST
          value: "192.168.1.202"  # Your external PostgreSQL server IP
        - name: POSTGRES_PORT
          value: "5432"
        - name: POSTGRES_DB
          value: "notesdb"
        - name: POSTGRES_USER
          value: "notesuser"
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        resources:
          limits:
            memory: "256Mi"
            cpu: "200m"
          requests:
            memory: "128Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  selector:
    app: notes-backend
  ports:
  - port: 5000
    targetPort: 5000
  type: ClusterIP
```

### 2. Create PostgreSQL Secret

Create a Kubernetes secret for the database password:

```bash
kubectl create secret generic postgres-secret \
  --from-literal=password=your_secure_password \
  -n notes-app-staging

kubectl create secret generic postgres-secret \
  --from-literal=password=your_secure_password \
  -n notes-app-prod
```

### 3. Backend Code Configuration

Update your `backend/server.js` to use environment variables:

```javascript
const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');

const app = express();
const port = process.env.PORT || 5000;

// PostgreSQL connection configuration
const pool = new Pool({
  host: process.env.POSTGRES_HOST || 'localhost',
  port: process.env.POSTGRES_PORT || 5432,
  database: process.env.POSTGRES_DB || 'notesdb',
  user: process.env.POSTGRES_USER || 'notesuser',
  password: process.env.POSTGRES_PASSWORD || 'defaultpassword',
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Test database connection on startup
async function testConnection() {
  try {
    const client = await pool.connect();
    console.log('✅ Connected to PostgreSQL database successfully');
    
    // Create tables if they don't exist
    await client.query(`
      CREATE TABLE IF NOT EXISTS notes (
        id SERIAL PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        content TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    
    client.release();
  } catch (err) {
    console.error('❌ Database connection error:', err);
    process.exit(1);
  }
}

// Middleware
app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    const client = await pool.connect();
    await client.query('SELECT NOW()');
    client.release();
    res.json({ 
      status: 'healthy', 
      database: 'connected',
      timestamp: new Date().toISOString()
    });
  } catch (err) {
    res.status(500).json({ 
      status: 'unhealthy', 
      database: 'disconnected',
      error: err.message 
    });
  }
});

// Routes
app.use('/api/notes', require('./routes/notes'));

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

// Start server
async function startServer() {
  await testConnection();
  app.listen(port, () => {
    console.log(`🚀 Server running on port ${port}`);
    console.log(`📊 Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`🗄️ Database: ${process.env.POSTGRES_HOST}:${process.env.POSTGRES_PORT}/${process.env.POSTGRES_DB}`);
  });
}

startServer();

module.exports = app;
```

### 4. Update Package.json Dependencies

Make sure your `backend/package.json` includes the PostgreSQL driver:

```json
{
  "name": "notes-backend",
  "version": "1.0.0",
  "description": "Notes app backend API",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.3",
    "cors": "^2.8.5"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
```

### 5. Database Migration Script

Create `scripts/init-db.sql` for database initialization:

```sql
-- Create database and user (run as PostgreSQL admin)
CREATE DATABASE notesdb;
CREATE USER notesuser WITH ENCRYPTED PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE notesdb TO notesuser;

-- Connect to notesdb and create tables
\c notesdb;

CREATE TABLE IF NOT EXISTS notes (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Grant permissions
GRANT ALL PRIVILEGES ON TABLE notes TO notesuser;
GRANT USAGE, SELECT ON SEQUENCE notes_id_seq TO notesuser;

-- Insert sample data
INSERT INTO notes (title, content) VALUES 
('Welcome Note', 'Welcome to your notes app!'),
('Getting Started', 'This is your first note. You can edit or delete it.');
```

## Next Steps

1. **Replace current Jenkinsfile**: Copy `Jenkinsfile.external-postgres` to `Jenkinsfile`
2. **Set up external PostgreSQL**: Follow the `EXTERNAL_POSTGRES_SETUP.md` guide
3. **Update backend code**: Implement the configuration changes above
4. **Create Kubernetes secrets**: Run the kubectl commands to create database secrets
5. **Test the pipeline**: Run a new build to deploy with external database

This approach eliminates the need for kubectl on Jenkins while providing a more robust, production-ready database solution.
