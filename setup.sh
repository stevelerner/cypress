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
rm -f Dockerfile.app Dockerfile.cypress docker-compose.yml

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

# Add 'app' to vite.config.ts allowedHosts
RUN sed -i '/server: {/a\    allowedHosts: [".app", "app", "localhost"],' vite.config.ts || \
    sed -i 's/export default defineConfig({/export default defineConfig({\n  server: { allowedHosts: [".app", "app", "localhost"] },/' vite.config.ts

CMD ["yarn", "start"]
EOF

echo "Creating Dockerfile.cypress..."
cat > Dockerfile.cypress << 'EOF'
FROM node:20

WORKDIR /e2e

# Install Cypress system dependencies
RUN apt-get update && apt-get install -y \
    libgtk2.0-0 \
    libgtk-3-0 \
    libgbm-dev \
    libnotify-dev \
    libnss3 \
    libxss1 \
    libasound2 \
    libxtst6 \
    xauth \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

# Copy dependency files
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# Copy necessary files
COPY tsconfig.json tsconfig.tsnode.json ./
COPY cypress.config.ts vite.cypress.config.ts vite.config.ts ./
COPY cypress ./cypress
COPY src ./src
COPY backend ./backend
COPY scripts ./scripts

ENV CI=true

CMD ["npx", "cypress", "run"]
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
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:3000"]
      interval: 10s
      timeout: 5s
      retries: 10

  cypress:
    build:
      context: .
      dockerfile: Dockerfile.cypress
    depends_on:
      app:
        condition: service_healthy
    environment:
      - CYPRESS_baseUrl=http://app:3000
      - CYPRESS_apiUrl=http://app:3001
    volumes:
      - ./cypress/videos:/e2e/cypress/videos
      - ./cypress/screenshots:/e2e/cypress/screenshots
EOF

echo ""
echo "Done! Now try:"
echo "  docker compose build"
echo "  docker compose up -d app"
echo "  docker compose run --rm cypress 2>&1 | tee cypress-test-results.log"
echo ""
