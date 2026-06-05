#!/bin/bash

echo "=========================================="
echo "Task 2 Requirements Verification"
echo "=========================================="

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
    else
        echo -e "${RED}✗ $1${NC}"
    fi
}

echo -e "\n1. FastAPI service with /health:"
grep -q "/health" src/app.py && check "Health endpoint exists" || check "Missing health endpoint"

echo -e "\n2. Dockerfile exists:"
[ -f "Dockerfile" ] && check "Dockerfile found" || check "Dockerfile missing"

echo -e "\n3. Hadolint in CI:"
grep -q "hadolint/hadolint-action" .github/workflows/ci.yml && check "Hadolint configured" || check "Hadolint missing"

echo -e "\n4. Build in CI:"
grep -q "docker/build-push-action" .github/workflows/ci.yml && check "Build action configured" || check "Build action missing"

echo -e "\n5. Commit-sha tagging:"
grep -q "github.sha" .github/workflows/ci.yml && check "Commit-sha tag configured" || check "Commit-sha tag missing"

echo -e "\n6. Push to registry:"
grep -q "DOCKER_USERNAME" .github/workflows/ci.yml && check "Registry push configured" || check "Registry push missing"

echo -e "\n7. Helm deploy in CI:"
grep -q "helm upgrade" .github/workflows/ci.yml && check "Helm deploy configured" || check "Helm deploy missing"

echo -e "\n8. Helm Deployment template:"
grep -q "kind: Deployment" helm/templates/deployment.yaml && check "Deployment template exists" || check "Deployment template missing"

echo -e "\n9. Helm Service template:"
grep -q "kind: Service" helm/templates/service.yaml && check "Service template exists" || check "Service template missing"

echo -e "\n10. Resource requests/limits:"
grep -q "requests:" helm/values.yaml && grep -q "limits:" helm/values.yaml && check "Resources configured" || check "Resources missing"

echo -e "\n11. Configurable image repo/tag:"
# More flexible check
if grep -q "image:" helm/values.yaml && grep -q "repository:" helm/values.yaml && grep -q "tag:" helm/values.yaml; then
    check "Image configurable"
else
    # Check deployment.yaml for template variables
    if grep -q "{{ .Values.image.repository }}" helm/templates/deployment.yaml && grep -q "{{ .Values.image.tag }}" helm/templates/deployment.yaml; then
        check "Image configurable"
    else
        check "Image not configurable"
    fi
fi

echo -e "\n12. CI tests deployment:"
grep -q "Test the Application" .github/workflows/ci.yml && check "CI tests configured" || check "CI tests missing"

echo -e "\n=========================================="
echo "Verification Complete"
echo "=========================================="