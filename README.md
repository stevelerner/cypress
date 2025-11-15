# Cypress Cloud Demo with Real World App

Docker-based setup for demonstrating Cypress Cloud features including Recorded Runs, Test Replay, and Branch Review using the Cypress Real World App.

This repository contains setup scripts and documentation to configure the Cypress Real World App with Docker and Cypress Cloud integration.

## Repository Structure

This is a setup/configuration repository containing:
- `setup.sh` - Automated setup script
- `clean.sh` - Docker cleanup script
- `README.md` - This documentation

You will copy both scripts into your fork of the Cypress Real World App repository to configure it.

## Prerequisites

- macOS (tested on Ventura 13.0+)
- Docker Desktop for Mac (version 4.0+)
- Git
- GitHub account
- Cypress Cloud account

Note: This setup is specifically designed for macOS with Docker Desktop for Mac.

## Setup

### 1. Fork and Clone the Cypress Real World App

First, fork and clone the actual application repository (this is separate from this setup repository):

```bash
# Fork https://github.com/cypress-io/cypress-realworld-app on GitHub
# Then clone your fork
git clone https://github.com/YOUR_USERNAME/cypress-realworld-app.git
```

### 2. Copy Setup and Cleanup Scripts

Copy both scripts from this repository into your cloned cypress-realworld-app directory:

```bash
# If both repositories are in /Volumes/external/code/
cp /Volumes/external/code/cypress/setup.sh /Volumes/external/code/cypress-realworld-app/
cp /Volumes/external/code/cypress/clean.sh /Volumes/external/code/cypress-realworld-app/

# Navigate to your cypress-realworld-app directory
cd /Volumes/external/code/cypress-realworld-app

# Make scripts executable
chmod +x setup.sh clean.sh

# Run the setup script
./setup.sh
```

Adjust the paths above based on where you cloned both repositories.

This creates:
- Docker configuration files
- GitHub Actions workflow
- Example test files
- Environment configuration template

Note: The setup script uses bash, which is the default shell on macOS.

### 3. Verify Docker Desktop

Ensure Docker Desktop for Mac is running:

```bash
# Check Docker is running
docker info

# Verify Docker Compose is available
docker compose version
```

You should see Docker Desktop icon in your menu bar with a green indicator.

### 4. Configure Cypress Cloud

Create a project at https://cloud.cypress.io and obtain your credentials.

Edit `.env` with your preferred text editor:
```bash
# Using TextEdit
open -e .env

# Or use nano
nano .env

# Or use vim
vim .env
```

Add your credentials:
```bash
CYPRESS_RECORD_KEY=your_record_key
CYPRESS_PROJECT_ID=your_project_id
```

Update `cypress.config.ts`:
```typescript
export default defineConfig({
  projectId: 'your_project_id',
  // ... rest of config
})
```

### 5. Configure GitHub Repository Secrets

In your GitHub repository, go to Settings > Secrets and variables > Actions, then:

1. Click the "Secrets" tab (not Variables)
2. Click "New repository secret" button
3. Add these two repository secrets:

- Name: `CYPRESS_RECORD_KEY`
  - Value: Your Cypress Cloud record key (sensitive authentication data)
  
- Name: `CYPRESS_PROJECT_ID`
  - Value: Your Cypress Cloud project ID

Note: Use **repository secrets**, not environment secrets. Repository secrets are accessible to all workflows in the repo, which is what we need for this setup.

## Usage

### Build Docker Images

```bash
docker compose build
```

### Start Application

```bash
docker compose up -d app
```

Application will be available at http://localhost:3000

Open in your default browser:
```bash
open http://localhost:3000
```

### Run Tests Locally

```bash
# Run tests without recording
docker compose run --rm cypress

# Run tests with Cypress Cloud recording
docker compose run --rm cypress --record

# Run specific test file
docker compose run --rm cypress --spec "cypress/e2e/ui/auth.cy.ts"
```

### View Logs

```bash
docker compose logs -f app
```

### Stop Services

```bash
docker compose down
```

## Docker Configuration

### Application Container

Built from `Dockerfile.app`:
- Node.js 22 Alpine base image
- Installs dependencies with Yarn
- Builds application
- Exposes ports 3000 (frontend) and 3001 (backend)
- Starts both backend and frontend services

### Cypress Container

Built from `Dockerfile.cypress`:
- Node.js 22 base image (Debian-based for better compatibility)
- Installs Cypress system dependencies
- Installs Cypress via yarn/npm
- Copies test files and configuration
- Runs headless by default
- Mounts volumes for videos and screenshots

### Service Dependencies

The docker-compose configuration includes:
- Health checks for the application service
- Dependent startup for Cypress service
- Volume mounts for test artifacts
- Environment variable injection

## GitHub Actions CI

The workflow in `.github/workflows/cypress-tests.yml`:
- Triggers on push and pull requests
- Builds and starts the application
- Waits for services to be ready
- Runs Cypress tests with recording enabled
- Uploads screenshots on failure

## Test Examples

### Flaky Test Demonstration

The `cypress/e2e/demo/notifications-flaky.cy.ts` file includes examples of:

**Test without proper wait (flaky):**
```typescript
it('should display notification count', () => {
  cy.getBySel('sidenav-notifications').click()
  cy.get('[data-test*="notification-list-item"]')
    .should('have.length.greaterThan', 0)
})
```

**Test with proper wait (fixed):**
```typescript
it('should display notification count', () => {
  cy.intercept('GET', '/notifications*').as('getNotifications')
  cy.getBySel('sidenav-notifications').click()
  cy.wait('@getNotifications')
  cy.get('[data-test*="notification-list-item"]')
    .should('have.length.greaterThan', 0)
})
```

## Cypress Cloud Features

### Recorded Runs

All test runs are recorded to Cypress Cloud when using the `--record` flag. This provides:
- Test execution history
- Performance metrics
- Failure analytics
- Screenshot and video artifacts

### Test Replay

Available for recorded runs, Test Replay provides:
- DOM snapshots at each test step
- Network request inspection
- Console log capture
- Time-travel debugging interface

### Branch Review

Integrates with GitHub pull requests to display:
- Test results per branch
- Commit-specific test runs
- Historical comparison
- PR status checks

## Troubleshooting

### Build fails or shows old Node version

If you're getting Node version errors or stale builds:

```bash
# Run the cleanup script
./clean.sh

# Verify cleanup worked
docker images | grep cypress-realworld-app
# Should show nothing

# Re-run setup
./setup.sh

# Verify Dockerfile has Node 22
head -1 Dockerfile.cypress
# Should show: FROM node:22

# Build fresh
docker compose build --no-cache
```

### Docker Desktop not running

If you see "Cannot connect to the Docker daemon":

1. Open Docker Desktop from Applications
2. Wait for the whale icon in menu bar to show green indicator
3. Try the command again

### Application fails to start

View logs and rebuild:

```bash
docker compose logs app
docker compose down
docker compose build --no-cache app
docker compose up app
```

Common causes on Mac:
- Insufficient memory allocated to Docker Desktop (check Preferences > Resources)
- File sharing permissions (ensure project directory is accessible)

### Tests fail to record to Cypress Cloud

Verify environment variables are loaded:
```bash
docker compose run --rm cypress env | grep CYPRESS
```

Check that `.env` file contains valid credentials.

Common causes:
- `.env` file not in the correct directory
- Network restrictions blocking cloud.cypress.io
- Invalid or expired record key

### Port conflicts

Check for processes using ports 3000 or 3001:
```bash
# Check what's using the ports
lsof -i :3000
lsof -i :3001

# Kill process by PID if needed
kill -9 <PID>
```

Alternatively, you can modify ports in `docker-compose.yml` to use different host ports.

### Docker Desktop performance issues

If builds or tests are slow:

1. Increase Docker Desktop resources:
   - Open Docker Desktop Preferences
   - Go to Resources > Advanced
   - Increase CPUs to 4+ and Memory to 8GB+
   - Click "Apply & Restart"

2. Enable VirtioFS for better file sharing:
   - Docker Desktop Preferences > Experimental Features
   - Enable "VirtioFS accelerated directory sharing"

### File permission issues

If you encounter permission errors with mounted volumes:

```bash
# Check Docker Desktop file sharing settings
# Ensure your project directory is under an allowed path
# Default allowed: /Users, /Volumes, /private, /tmp

# Reset Docker Desktop if needed
docker system prune -a --volumes
```

### Network issues in Docker

Ensure Docker Desktop has network access:
- Check macOS Firewall settings
- Verify Docker Desktop can access external networks
- Test with: `docker run --rm alpine ping -c 3 google.com`

## Project Structure

```
cypress-realworld-app/
├── Dockerfile.app
├── Dockerfile.cypress
├── docker-compose.yml
├── .env
├── .github/
│   └── workflows/
│       └── cypress-tests.yml
├── cypress/
│   ├── e2e/
│   │   └── demo/
│   │       └── notifications-flaky.cy.ts
│   └── support/
└── cypress.config.ts
```

## Commands Reference

```bash
# Check service status
docker compose ps

# View application logs
docker compose logs -f app

# View Cypress logs
docker compose logs cypress

# Run tests with recording
docker compose run --rm cypress --record

# Run specific spec file
docker compose run --rm cypress --spec "path/to/spec.cy.ts"

# Rebuild containers
docker compose build --no-cache

# Remove all containers and volumes
docker compose down -v
```

## Additional Resources

- Cypress Real World App: https://github.com/cypress-io/cypress-realworld-app
- Cypress Cloud Documentation: https://docs.cypress.io/cloud
- Test Replay: https://docs.cypress.io/cloud/features/test-replay
- Branch Review: https://docs.cypress.io/cloud/features/branch-review
- GitHub Actions Integration: https://docs.cypress.io/guides/continuous-integration/github-actions

