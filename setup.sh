#!/bin/bash
# Cypress Demo Setup - Step 1: Just get app running in Docker

set -e

echo "Step 1: Basic Docker setup"
echo ""

if [ ! -f "package.json" ]; then
    echo "Error: Run this from cypress-realworld-app directory"
    exit 1
fi

# Remove existing Docker files
echo "Cleaning up old Docker files..."
rm -f Dockerfile.app docker-compose.yml

echo "Creating Dockerfile.app..."
cat > Dockerfile.app << 'EOF'
FROM node:20

WORKDIR /app

COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

COPY . .

EXPOSE 3000 3001

# Override start:react to use --host flag for Docker
RUN sed -i 's/"start:react": "vite"/"start:react": "vite --host"/' package.json

CMD ["yarn", "start"]
EOF

echo "Creating docker-compose.yml..."
cat > docker-compose.yml << 'EOF'
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.app
    ports:
      - "3000:3000"
      - "3001:3001"
    environment:
      - VITE_HOST=0.0.0.0
EOF

echo ""
echo "Done! Now try:"
echo "  docker compose build"
echo "  docker compose up app"
echo ""
