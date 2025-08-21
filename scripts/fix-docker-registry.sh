#!/bin/bash

# Quick Fix Script for Docker Registry Configuration
# Run this script on the Jenkins server (192.168.1.153) to fix the insecure registry issue

set -e

REGISTRY_HOST="192.168.1.150:3000"
DAEMON_CONFIG="/etc/docker/daemon.json"

echo "🔧 Docker Registry Configuration Fix Script"
echo "==========================================="
echo ""
echo "This script will configure Docker to work with insecure registry: $REGISTRY_HOST"
echo "Target file: $DAEMON_CONFIG"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   echo "   Usage: sudo bash fix-docker-registry.sh"
   exit 1
fi

# Backup existing daemon.json if it exists
if [ -f "$DAEMON_CONFIG" ]; then
    echo "📋 Backing up existing daemon.json..."
    cp "$DAEMON_CONFIG" "${DAEMON_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "✅ Backup created: ${DAEMON_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Check if daemon.json exists and has content
if [ -f "$DAEMON_CONFIG" ] && [ -s "$DAEMON_CONFIG" ]; then
    echo "📝 Existing configuration found. Checking for insecure-registries..."
    
    # Check if insecure-registries already exists
    if grep -q "insecure-registries" "$DAEMON_CONFIG"; then
        echo "🔍 Found existing insecure-registries configuration"
        
        # Check if our registry is already included
        if grep -q "$REGISTRY_HOST" "$DAEMON_CONFIG"; then
            echo "✅ Registry $REGISTRY_HOST is already configured!"
            echo "🔄 Restarting services anyway to ensure changes are applied..."
        else
            echo "➕ Adding $REGISTRY_HOST to existing insecure-registries"
            # This is complex with JSON manipulation, so we'll recreate the file
            # First, let's read the current insecure registries
            python3 -c "
import json
import sys

try:
    with open('$DAEMON_CONFIG', 'r') as f:
        config = json.load(f)
    
    if 'insecure-registries' not in config:
        config['insecure-registries'] = []
    
    if '$REGISTRY_HOST' not in config['insecure-registries']:
        config['insecure-registries'].append('$REGISTRY_HOST')
    
    with open('$DAEMON_CONFIG', 'w') as f:
        json.dump(config, f, indent=2)
    
    print('✅ Configuration updated successfully')
except Exception as e:
    print(f'❌ Error updating configuration: {e}')
    sys.exit(1)
"
        fi
    else
        echo "➕ Adding insecure-registries to existing configuration"
        python3 -c "
import json
import sys

try:
    with open('$DAEMON_CONFIG', 'r') as f:
        config = json.load(f)
    
    config['insecure-registries'] = ['$REGISTRY_HOST']
    
    with open('$DAEMON_CONFIG', 'w') as f:
        json.dump(config, f, indent=2)
    
    print('✅ Configuration updated successfully')
except Exception as e:
    print(f'❌ Error updating configuration: {e}')
    sys.exit(1)
"
    fi
else
    echo "📝 Creating new daemon.json configuration..."
    cat > "$DAEMON_CONFIG" << EOF
{
  "insecure-registries": ["$REGISTRY_HOST"]
}
EOF
    echo "✅ Configuration file created"
fi

echo ""
echo "📋 Current daemon.json content:"
echo "================================"
cat "$DAEMON_CONFIG"
echo "================================"
echo ""

# Validate JSON syntax
echo "🔍 Validating JSON syntax..."
if python3 -m json.tool "$DAEMON_CONFIG" > /dev/null 2>&1; then
    echo "✅ JSON syntax is valid"
else
    echo "❌ JSON syntax error! Restoring backup..."
    if [ -f "${DAEMON_CONFIG}.backup.*" ]; then
        cp "${DAEMON_CONFIG}.backup."* "$DAEMON_CONFIG"
    fi
    exit 1
fi

# Test registry connectivity
echo "🌐 Testing registry connectivity..."
if curl -f "http://$REGISTRY_HOST/v2/" > /dev/null 2>&1; then
    echo "✅ Registry is accessible"
else
    echo "⚠️  Warning: Cannot connect to registry. Please verify it's running."
fi

# Restart Docker service
echo "🔄 Restarting Docker service..."
systemctl restart docker

echo "⏳ Waiting for Docker to start..."
sleep 5

# Verify Docker is running
if systemctl is-active --quiet docker; then
    echo "✅ Docker service is running"
else
    echo "❌ Docker service failed to start! Check logs: journalctl -u docker"
    exit 1
fi

# Restart Jenkins service
echo "🔄 Restarting Jenkins service..."
systemctl restart jenkins

echo "⏳ Waiting for Jenkins to start..."
sleep 10

# Verify Jenkins is running
if systemctl is-active --quiet jenkins; then
    echo "✅ Jenkins service is running"
else
    echo "❌ Jenkins service failed to start! Check logs: journalctl -u jenkins"
    exit 1
fi

# Verify configuration
echo ""
echo "🔍 Verifying Docker configuration..."
echo "Insecure registries configured:"
docker info 2>/dev/null | grep -A10 "Insecure Registries:" | head -5

echo ""
echo "🎉 Configuration complete!"
echo ""
echo "📋 Summary:"
echo "  ✅ Docker daemon configured for insecure registry: $REGISTRY_HOST"
echo "  ✅ Docker service restarted"
echo "  ✅ Jenkins service restarted"
echo ""
echo "🚀 You can now re-run your Jenkins pipeline!"
echo ""
echo "💡 To test manually:"
echo "   docker pull nginx:alpine"
echo "   docker tag nginx:alpine $REGISTRY_HOST/test:latest"
echo "   docker push $REGISTRY_HOST/test:latest"
