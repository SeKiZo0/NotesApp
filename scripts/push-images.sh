#!/bin/bash
# Manual push script to fix the registry issue

echo "🔄 Pushing images to registry..."

# Tag and push frontend image
docker tag notes-app-frontend:latest 192.168.1.150:3000/notes-app-frontend:latest
docker push 192.168.1.150:3000/notes-app-frontend:latest

# Tag and push backend image  
docker tag notes-app-backend:latest 192.168.1.150:3000/notes-app-backend:latest
docker push 192.168.1.150:3000/notes-app-backend:latest

echo "✅ Images pushed successfully!"
echo "You can now deploy to Kubernetes with 'latest' tags"
