#!/bin/bash

# PostgreSQL Database Operations Script for Notes App
# This script helps manage PostgreSQL in Kubernetes environments

set -e

NAMESPACE=${1:-notes-app-staging}
OPERATION=${2:-status}

echo "PostgreSQL Operations for Notes App"
echo "Namespace: $NAMESPACE"
echo "Operation: $OPERATION"
echo "=================================="

case $OPERATION in
    "status")
        echo "📊 Checking PostgreSQL status..."
        kubectl get pods,svc,pvc -l app=postgres -n $NAMESPACE
        
        echo ""
        echo "🔍 PostgreSQL pod details:"
        kubectl describe pod -l app=postgres -n $NAMESPACE
        ;;
        
    "connect")
        echo "🔌 Testing PostgreSQL connectivity..."
        kubectl exec deployment/postgres-deployment -n $NAMESPACE -- pg_isready -U postgres
        
        echo ""
        echo "📋 PostgreSQL version and info:"
        kubectl exec deployment/postgres-deployment -n $NAMESPACE -- psql -U postgres -d notesdb -c "SELECT version();"
        ;;
        
    "logs")
        echo "📝 PostgreSQL logs:"
        kubectl logs deployment/postgres-deployment -n $NAMESPACE --tail=50
        ;;
        
    "shell")
        echo "🐚 Opening PostgreSQL shell..."
        kubectl exec -it deployment/postgres-deployment -n $NAMESPACE -- psql -U postgres -d notesdb
        ;;
        
    "backup")
        echo "💾 Creating database backup..."
        BACKUP_FILE="notesdb-backup-$(date +%Y%m%d-%H%M%S).sql"
        kubectl exec deployment/postgres-deployment -n $NAMESPACE -- pg_dump -U postgres notesdb > $BACKUP_FILE
        echo "Backup created: $BACKUP_FILE"
        ;;
        
    "restore")
        BACKUP_FILE=${3:-""}
        if [ -z "$BACKUP_FILE" ]; then
            echo "❌ Please provide backup file as third argument"
            exit 1
        fi
        
        echo "🔄 Restoring database from $BACKUP_FILE..."
        kubectl exec -i deployment/postgres-deployment -n $NAMESPACE -- psql -U postgres notesdb < $BACKUP_FILE
        echo "✅ Database restored successfully"
        ;;
        
    "reset")
        echo "⚠️  WARNING: This will delete all data in the database!"
        read -p "Are you sure? (yes/no): " -r
        if [[ $REPLY == "yes" ]]; then
            echo "🔄 Resetting database..."
            kubectl exec deployment/postgres-deployment -n $NAMESPACE -- psql -U postgres -c "DROP DATABASE IF EXISTS notesdb;"
            kubectl exec deployment/postgres-deployment -n $NAMESPACE -- psql -U postgres -c "CREATE DATABASE notesdb;"
            echo "✅ Database reset completed"
        else
            echo "❌ Operation cancelled"
        fi
        ;;
        
    "test-backend")
        echo "🧪 Testing backend database connection..."
        
        # Check if backend is running
        kubectl get deployment backend-deployment -n $NAMESPACE
        
        # Test health endpoints
        echo "Testing /health endpoint:"
        kubectl exec deployment/backend-deployment -n $NAMESPACE -- curl -f http://localhost:5000/health
        
        echo ""
        echo "Testing /api/health/db endpoint:"
        kubectl exec deployment/backend-deployment -n $NAMESPACE -- curl -f http://localhost:5000/api/health/db
        
        echo ""
        echo "✅ Backend database connection tests completed"
        ;;
        
    "init")
        echo "🚀 Initializing PostgreSQL for Notes App..."
        
        # Apply PostgreSQL deployment
        kubectl apply -f k8s/postgres-deployment.yaml -n $NAMESPACE
        
        # Wait for PostgreSQL to be ready
        echo "⏳ Waiting for PostgreSQL to be ready..."
        kubectl wait --for=condition=available --timeout=300s deployment/postgres-deployment -n $NAMESPACE
        
        # Verify connection
        echo "🔍 Verifying PostgreSQL is ready..."
        kubectl exec deployment/postgres-deployment -n $NAMESPACE -- pg_isready -U postgres
        
        echo "✅ PostgreSQL initialization completed"
        ;;
        
    "help")
        echo "Available operations:"
        echo "  status      - Show PostgreSQL pod and service status"
        echo "  connect     - Test PostgreSQL connectivity"
        echo "  logs        - Show PostgreSQL logs"
        echo "  shell       - Open PostgreSQL shell"
        echo "  backup      - Create database backup"
        echo "  restore     - Restore database from backup file"
        echo "  reset       - Reset database (WARNING: deletes all data)"
        echo "  test-backend- Test backend database connection"
        echo "  init        - Initialize PostgreSQL deployment"
        echo "  help        - Show this help message"
        echo ""
        echo "Usage examples:"
        echo "  $0 notes-app-staging status"
        echo "  $0 notes-app-prod connect"
        echo "  $0 notes-app-staging backup"
        echo "  $0 notes-app-staging restore backup-file.sql"
        ;;
        
    *)
        echo "❌ Unknown operation: $OPERATION"
        echo "Run '$0 help' for available operations"
        exit 1
        ;;
esac

echo ""
echo "🏁 Operation completed!"
