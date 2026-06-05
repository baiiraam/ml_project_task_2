# CI/CD Pipeline for FastAPI Service

## TLDR

```bash
# Test locally
docker build -t task2:test .
docker run -d -p 8000:8000 task2:test
curl http://localhost:8000/health

# Push to GitHub (triggers CI/CD on pr)
git add .
git commit -m "Task 2: FastAPI service with CI/CD"
git push origin main
```

## What It Does

A complete CI/CD pipeline for a FastAPI Python service that:
- **Lints** the Dockerfile with Hadolint
- **Builds** and **pushes** the Docker image to Docker Hub (tagged with commit-sha)
- **Deploys** to Kubernetes using Helm
- **Tests** the deployed service endpoints

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           GitHub Actions                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐               │
│  │  Lint    │───►│  Build   │───►│  Push    │───►│  Deploy  │               │
│  │ Hadolint │    │  Image   │    │  to DH   │    │  Helm    │               │
│  └──────────┘    └──────────┘    └──────────┘    └────┬─────┘               │
│                                                       │                     │
└───────────────────────────────────────────────────────┼─────────────────────┘
                                                        │
                                                        ▼
                                              ┌──────────────────┐
                                              │   Kind Cluster   │
                                              │   (in CI)        │
                                              │ ┌──────────────┐ │
                                              │ │ FastAPI Pod  │ │
                                              │ │ Port 8000    │ │
                                              │ └──────────────┘ │
                                              │ ┌──────────────┐ │
                                              │ │ Service      │ │
                                              │ │ ClusterIP    │ │
                                              │ └──────────────┘ │
                                              └──────────────────┘
```

## Prerequisites

## Prerequisites

### For Local Development

| Tool | Version | Check Command |
|------|---------|---------------|
| Docker | 20.10+ | `docker --version` |
| Python | 3.12+ | `python --version` |
| Git | 2.40+ | `git --version` |
| Hadolint | Latest | `./hadolint.exe Dockerfile` |

### For CI/CD (Automatically provided by GitHub Actions)

- kubectl 1.28+
- Helm 3.14+
- Kind cluster

## Project Structure

```
task-2/
├── .github/workflows/
│   └── ci.yml                 # CI/CD pipeline (lint → build → deploy → test)
├── helm/
│   ├── Chart.yaml             # Helm chart metadata
│   ├── values.yaml            # Configurable values
│   └── templates/
│       ├── deployment.yaml    # Kubernetes Deployment with probes
│       └── service.yaml       # Kubernetes Service (ClusterIP)
├── src/
│   └── app.py                 # FastAPI app (/ and /health)
├── Dockerfile                 # Multi-stage, non-root user, healthcheck
├── requirements.txt           # Minimal dependencies (fastapi + uvicorn)
└── .dockerignore              # Files excluded from Docker build
```

## Quick Start

### 1. Test Locally

```bash
# Build the Docker image
docker build -t task2:test .

# Run the container
docker run -d --name task2-test -p 8000:8000 task2:test

# Test the endpoints
curl http://localhost:8000/
curl http://localhost:8000/health

# Expected output:
# {"message":"Hello, World!"}
# {"message":"ok"}

# Stop and remove
docker stop task2-test && docker rm task2-test
```

### 2. Test Helm Locally

```bash
# Template rendering test
helm template ./helm

# Install locally (requires a Kubernetes cluster)
helm install my-python-service ./helm

# Test port-forward
kubectl port-forward service/python-service 8000:8000

# In another terminal
curl http://localhost:8000/health

# Uninstall
helm uninstall my-python-service
```

### 3. Push to GitHub

```bash
git add .
git commit -m "Task 2: FastAPI service with CI/CD"
git push origin main
```

## CI/CD Pipeline Details

### Pipeline Stages

| Stage | What it does | File Reference |
|-------|--------------|----------------|
| **Lint** | Runs Hadolint on Dockerfile | `ci.yml` → `lint` job |
| **Build** | Builds Docker image | `ci.yml` → `build` job |
| **Push** | Pushes to Docker Hub | `ci.yml` → `docker/build-push-action` |
| **Deploy** | Creates Kind cluster, deploys with Helm | `ci.yml` → `deploy` job |
| **Test** | Tests `/` and `/health` endpoints | `ci.yml` → `Test the Application` |

### CI/CD Triggers

| Event | Description | Jobs that run |
|-------|-------------|---------------|
| Push to `main` | Code is merged/pushed to main branch | Lint + Build + Push + Deploy + Test |
| Pull Request to `main` | PR is opened or updated | Lint only (security: no image push) |
| Manual (workflow_dispatch) | Triggered from GitHub UI | Lint + Build + Push + Deploy + Test |

### Image Tags

Each push to `main` branch creates two tags:

| Tag | Format | Example | Purpose |
|-----|--------|---------|---------|
| Latest | `latest` | `latest` | Convenience reference |
| Commit-SHA | `${{ github.sha }}` | `a1b2c3d4e5f6...` | Unique, traceable build |

### Helm Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `replicaCount` | `1` | Number of pods |
| `image.repository` | `docker.io/baiiraam/ml_project_task_2` | Docker image repo |
| `image.tag` | `latest` | Image tag (overridden in CI) |
| `service.type` | `ClusterIP` | Service type |
| `service.port` | `8000` | Service port |
| `resources.requests.cpu` | `100m` | Minimum CPU |
| `resources.requests.memory` | `128Mi` | Minimum memory |
| `resources.limits.cpu` | `200m` | Maximum CPU |
| `resources.limits.memory` | `256Mi` | Maximum memory |

## Files Explained

### Dockerfile

```dockerfile
FROM python:3.12-alpine          # Small base image

# Create non-root user (security best practice)
RUN addgroup -g 1000 -S appgroup && \
    adduser -u 1000 -S appuser -G appgroup

WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir fastapi uvicorn

# Copy application code
COPY --chown=appuser:appgroup src/ ./src/

# Switch to non-root user
USER appuser

EXPOSE 8000

# Healthcheck for Kubernetes
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

# Run the application
CMD ["uvicorn", "src.app:app", "--host", "0.0.0.0", "--port", "8000"]
```

### FastAPI App (src/app.py)

```python
from fastapi import FastAPI

app = FastAPI()

@app.get('/')
def get_root():
    return {"message": "Hello, World!"}

@app.get('/health')
def get_health():
    return {"message": "ok"}
```

### requirements.txt

```txt
fastapi==0.136.3
uvicorn==0.48.0
```

## Verification

Run the verification script to check all requirements:

```bash
chmod +x verify_task2.sh
./verify_task2.sh
```

### Expected Output

```
==========================================
Task 2 Requirements Verification
==========================================

1. FastAPI service with /health:
✓ Health endpoint exists

2. Dockerfile exists:
✓ Dockerfile found

3. Hadolint in CI:
✓ Hadolint configured

4. Build in CI:
✓ Build action configured

5. Commit-sha tagging:
✓ Commit-sha tag configured

6. Push to registry:
✓ Registry push configured

7. Helm deploy in CI:
✓ Helm deploy configured

8. Helm Deployment template:
✓ Deployment template exists

9. Helm Service template:
✓ Service template exists

10. Resource requests/limits:
✓ Resources configured

11. Configurable image repo/tag:
✓ Image configurable

12. CI tests deployment:
✓ CI tests configured

==========================================
Verification Complete
==========================================
```

## Monitoring CI/CD

### GitHub Actions

1. Go to your repository on GitHub
2. Click **Actions** tab
3. See the workflow run:

```
CI/CD Pipeline
├── Lint Dockerfile (passed)
├── Build and Push Image (passed)
└── Deploy with Helm (passed)
```

### Docker Hub

Check your image at your docker hub.

Expected tags:
- `latest`
- `<commit-sha>` (e.g., `a1b2c3d4e5f6...`)

## Troubleshooting

### Docker build fails

```bash
# Check Dockerfile syntax
./hadolint.exe Dockerfile

# Build with verbose output
docker build --no-cache -t task2:test . --progress=plain
```

### Container won't start

```bash
# Run in foreground to see errors
docker run --rm -p 8000:8000 task2:test

# Check logs if running in background
docker logs task2-test
```

### Port already in use

```bash
# Find process using port 8000
netstat -ano | findstr :8000

# Use different port
docker run -d -p 8001:8000 task2:test
```

### Helm deployment fails

```bash
# Validate Helm chart
helm lint ./helm

# Template rendering
helm template ./helm --debug

# Check Kubernetes connection
kubectl cluster-info
```

## GitHub Secrets Required

| Secret | Purpose |
|--------|---------|
| `DOCKER_USERNAME` | Docker Hub username |
| `DOCKER_PASSWORD` | Docker Hub password or token |

Add them in: `Settings` → `Secrets and variables` → `Actions`

## Cleanup

```bash
# Remove local Docker image
docker rmi task2:test

# Uninstall Helm release
helm uninstall my-python-service

# Delete Kind cluster (if created locally)
kind delete cluster --name kind-cluster
```