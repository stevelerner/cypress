#!/bin/bash
# Docker Cleanup Script for Cypress Real World App
# Run this from the cypress-realworld-app directory

set -e

echo "Docker Cleanup for Cypress Real World App"
echo "=========================================="
echo ""

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo "Error: package.json not found. Run this script from the cypress-realworld-app directory."
    exit 1
fi

echo "Step 1: Stopping and removing containers..."
docker compose down -v 2>/dev/null || true
docker stop cypress-rwa-app 2>/dev/null || true
docker stop cypress-rwa-tests 2>/dev/null || true
docker rm cypress-rwa-app 2>/dev/null || true
docker rm cypress-rwa-tests 2>/dev/null || true

echo "Step 2: Removing Docker images..."
docker rmi cypress-realworld-app-app 2>/dev/null || true
docker rmi cypress-realworld-app-cypress 2>/dev/null || true
docker images | grep cypress-realworld-app | awk '{print $3}' | xargs docker rmi -f 2>/dev/null || true

echo "Step 3: Cleaning Docker build cache..."
docker builder prune -f

echo "Step 4: Removing generated configuration files..."
rm -f Dockerfile.app
rm -f Dockerfile.cypress
rm -f docker-compose.yml

echo "Step 5: Removing Cypress artifacts..."
rm -rf cypress/videos
rm -rf cypress/screenshots

echo ""
echo "Cleanup complete!"
echo ""
echo "Next steps:"
echo "1. Run: ./setup.sh"
echo "2. Verify Node version in Dockerfile.cypress:"
echo "   head -1 Dockerfile.cypress"
echo "   (should show: FROM node:22)"
echo "3. Build: docker compose build --no-cache"
echo ""

