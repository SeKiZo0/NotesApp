#!/bin/bash

# Notes App Kubernetes Deployment Script
# This script deploys the notes application to Kubernetes

set -e

NAMESPACE=${1:-notes-app}
echo "Deploying Notes App to namespace: $NAMESPACE"

# Create namespace if it doesn't exist
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "📦 Deploying PostgreSQL database..."
kubectl apply -f postgres-deployment.yaml -n $NAMESPACE

echo "⏳ Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=300s

echo "🚀 Deploying backend API..."
kubectl apply -f backend-deployment.yaml -n $NAMESPACE

echo "⏳ Waiting for backend to be ready..."
kubectl wait --for=condition=ready pod -l app=backend -n $NAMESPACE --timeout=300s

echo "🌐 Deploying frontend..."
kubectl apply -f frontend-deployment.yaml -n $NAMESPACE

echo "⏳ Waiting for frontend to be ready..."
kubectl wait --for=condition=ready pod -l app=frontend -n $NAMESPACE --timeout=300s

echo "✅ Deployment complete!"
echo ""
echo "🔍 Checking service status..."
kubectl get pods,svc,ingress -n $NAMESPACE

echo ""
echo "📋 To access the application:"
echo "1. Frontend: http://notes-app.local (add to /etc/hosts: <INGRESS_IP> notes-app.local)"
echo "2. Backend API: http://api.notes-app.local"
echo ""
echo "📊 To monitor the deployment:"
echo "kubectl logs -f deployment/backend-deployment -n $NAMESPACE"
echo "kubectl logs -f deployment/postgres-deployment -n $NAMESPACE"
echo ""
echo "🧹 To clean up:"
echo "kubectl delete namespace $NAMESPACE"
