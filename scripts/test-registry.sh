#!/bin/bash
# Test script to verify registry connectivity

echo "🔍 Testing registry connectivity..."

# Test if registry is accessible
echo "Testing registry endpoint..."
curl -v http://192.168.1.150:3000/v2/ || echo "Registry endpoint test failed"

echo ""
echo "🔧 Testing Docker login..."
docker login http://192.168.1.150:3000 -u Morris -p changeme

echo ""
echo "🐳 Testing with a simple image..."
# Pull a small test image
docker pull hello-world:latest

# Tag it for our registry
docker tag hello-world:latest 192.168.1.150:3000/test-repo:latest

# Try to push
echo "Attempting test push..."
docker push 192.168.1.150:3000/test-repo:latest

echo ""
echo "✅ If the above succeeded, the registry is working!"
echo "❌ If it failed, there's a registry configuration issue."
