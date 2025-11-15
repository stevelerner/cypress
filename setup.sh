#!/bin/bash
# Cypress Cloud Demo Setup Script for macOS
# Requires Docker Desktop for Mac

set -e

echo "Cypress Cloud Demo Setup for macOS"
echo "===================================="
echo ""

# Check we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Warning: This script is designed for macOS. You appear to be on a different OS."
    echo "Continuing anyway, but some features may not work as expected."
    echo ""
fi

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo "Error: package.json not found. Run this script from the cypress-realworld-app directory."
    exit 1
fi

# Check for Docker Desktop for Mac
command -v docker >/dev/null 2>&1 || { 
    echo "Error: Docker is not installed or not in PATH."
    echo "Please install Docker Desktop for Mac from:"
    echo "https://www.docker.com/products/docker-desktop"
    exit 1
}

# Verify Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker daemon is not running."
    echo "Please start Docker Desktop for Mac from Applications."
    echo "Look for the whale icon in your menu bar."
    exit 1
fi

# Check for Docker Compose
if ! docker compose version >/dev/null 2>&1; then
    echo "Error: Docker Compose is not available."
    echo "Docker Compose should be included with Docker Desktop for Mac."
    echo "Try reinstalling Docker Desktop."
    exit 1
fi

echo "Docker Desktop for Mac detected and running"
echo ""

# Create Dockerfiles
echo "Creating Dockerfile.app..."
cat > Dockerfile.app << 'EOF'
FROM node:22-alpine

WORKDIR /app

COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

COPY . .
RUN yarn build

EXPOSE 3000 3001

CMD ["sh", "-c", "yarn start:ci & yarn start"]
EOF

echo "Creating Dockerfile.cypress..."
cat > Dockerfile.cypress << 'EOF'
FROM node:22

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

# Copy dependency files first for better caching
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# Copy all config files and source needed by Cypress
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
version: "3.9"

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.app
    container_name: cypress-rwa-app
    ports:
      - "3000:3000"
      - "3001:3001"
    environment:
      - NODE_ENV=development
      - REACT_APP_BACKEND_PORT=3001
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:3000"]
      interval: 10s
      timeout: 5s
      retries: 5

  cypress:
    build:
      context: .
      dockerfile: Dockerfile.cypress
    container_name: cypress-rwa-tests
    depends_on:
      app:
        condition: service_healthy
    environment:
      - CYPRESS_baseUrl=http://app:3000
      - CYPRESS_RECORD_KEY=${CYPRESS_RECORD_KEY}
      - CYPRESS_PROJECT_ID=${CYPRESS_PROJECT_ID}
      - API_URL=http://app:3001
      - BACKEND_ENV=test
    volumes:
      - ./cypress/videos:/e2e/cypress/videos
      - ./cypress/screenshots:/e2e/cypress/screenshots
EOF

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo "Creating .env file..."
    cat > .env << 'EOF'
# Cypress Cloud Configuration
# Get these from https://cloud.cypress.io after creating a project
CYPRESS_RECORD_KEY=your_record_key_here
CYPRESS_PROJECT_ID=your_project_id_here
EOF
    echo "Note: Edit .env file with your Cypress Cloud credentials"
else
    echo ".env file already exists, skipping"
fi

# Add .env to .gitignore if not already there
if ! grep -q "^.env$" .gitignore 2>/dev/null; then
    echo ".env" >> .gitignore
    echo "Added .env to .gitignore"
fi

# Create flaky test example
echo "Creating example test file..."
mkdir -p cypress/e2e/demo
cat > cypress/e2e/demo/notifications-flaky.cy.ts << 'EOF'
// Example: Flaky Test vs Fixed Test
// Demonstrates common timing issues and proper waiting strategies

describe('Notifications Test Examples', () => {
  beforeEach(() => {
    cy.visit('/')
    cy.database('seed')
    
    // Login
    cy.getBySel('signin-username').type('johndoe')
    cy.getBySel('signin-password').type('s3cret')
    cy.getBySel('signin-submit').click()
  })

  it('should display notification count (without wait - potentially flaky)', () => {
    cy.getBySel('sidenav-notifications').click()
    
    // This may fail if API response is slow
    cy.get('[data-test*="notification-list-item"]')
      .should('have.length.greaterThan', 0)
  })

  it('should display notification count (with wait - stable)', () => {
    // Intercept the API call
    cy.intercept('GET', '/notifications*').as('getNotifications')
    
    cy.getBySel('sidenav-notifications').click()
    
    // Wait for API response
    cy.wait('@getNotifications')
    
    // Now assertion is stable
    cy.get('[data-test*="notification-list-item"]')
      .should('have.length.greaterThan', 0)
  })
})
EOF

# Create GitHub Actions workflow
echo "Creating GitHub Actions workflow..."
mkdir -p .github/workflows
cat > .github/workflows/cypress-tests.yml << 'EOF'
name: Cypress Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  cypress-run:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'yarn'

      - name: Install dependencies
        run: yarn install --frozen-lockfile

      - name: Build application
        run: yarn build

      - name: Start application
        run: |
          yarn start:ci &
          npx wait-on http://localhost:3001/testData
          yarn start &
          npx wait-on http://localhost:3000

      - name: Run Cypress tests
        uses: cypress-io/github-action@v6
        with:
          browser: chrome
          record: true
          parallel: false
          config: baseUrl=http://localhost:3000
        env:
          CYPRESS_RECORD_KEY: ${{ secrets.CYPRESS_RECORD_KEY }}
          CYPRESS_PROJECT_ID: ${{ secrets.CYPRESS_PROJECT_ID }}
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Upload screenshots on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: cypress-screenshots
          path: cypress/screenshots
EOF

echo ""
echo "Setup complete."
echo ""
echo "Next steps:"
echo "1. Create a Cypress Cloud project at https://cloud.cypress.io"
echo "2. Edit .env file with your CYPRESS_RECORD_KEY and CYPRESS_PROJECT_ID"
echo "   You can use nano, vim, or any text editor:"
echo "   open -e .env"
echo "3. Update cypress.config.ts with your projectId"
echo "4. Build Docker images: docker compose build"
echo "5. Start the app: docker compose up -d app"
echo "6. Open http://localhost:3000 in your browser to verify"
echo "7. Run tests: docker compose run --rm cypress"
echo ""
echo "Note: Ensure Docker Desktop for Mac has sufficient resources allocated."
echo "Recommended: 4+ CPUs and 8GB+ memory (Docker Desktop Preferences > Resources)"
echo ""

