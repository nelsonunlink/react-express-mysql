#!/bin/bash

# ==============================================================================
# Minikube Deployment Script
# ==============================================================================
# This script automates the deployment of the React + Express + MySQL application
# to a local Minikube Kubernetes cluster.
#
# Prerequisites:
#   - Minikube installed
#   - kubectl installed
#   - Docker installed
#
# Usage: ./scripts/deploy-to-minikube.sh
# ==============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# ==============================================================================
# Step 1: Check Prerequisites
# ==============================================================================
print_step "Checking prerequisites..."

# Check Minikube
if ! command -v minikube &> /dev/null; then
    print_error "Minikube is not installed. Please install it first."
    echo "  Visit: https://minikube.sigs.k8s.io/docs/start/"
    exit 1
fi
print_success "Minikube found: $(minikube version --short)"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install it first."
    echo "  Visit: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi
print_success "kubectl found: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"

# Check Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install it first."
    echo "  Visit: https://docs.docker.com/get-docker/"
    exit 1
fi
print_success "Docker found: $(docker --version)"

# ==============================================================================
# Step 2: Start Minikube
# ==============================================================================
print_step "Starting Minikube..."

if minikube status | grep -q "Running"; then
    print_success "Minikube is already running"
else
    minikube start --cpus=2 --memory=4096
    print_success "Minikube started"
fi

# Enable Ingress addon
print_step "Enabling Ingress addon..."
minikube addons enable ingress
print_success "Ingress addon enabled"

# ==============================================================================
# Step 3: Configure Docker to use Minikube's daemon
# ==============================================================================
print_step "Configuring Docker to use Minikube's daemon..."
eval $(minikube docker-env)
print_success "Docker configured to use Minikube"

# ==============================================================================
# Step 4: Build Docker Images
# ==============================================================================
print_step "Building Docker images..."

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

echo "Building backend image..."
docker build -t react-mysql-backend:latest -f Dockerfile.backend .
print_success "Backend image built"

echo "Building frontend image..."
docker build -t react-mysql-frontend:latest -f Dockerfile.frontend .
print_success "Frontend image built"

# ==============================================================================
# Step 5: Apply Kubernetes Manifests
# ==============================================================================
print_step "Applying Kubernetes manifests..."

# Apply in order
kubectl apply -f k8s/1-mysql-secret.yaml
kubectl apply -f k8s/2-mysql-pv-pvc.yaml
kubectl apply -f k8s/2.5-mysql-init-configmap.yaml
kubectl apply -f k8s/3-mysql-deployment.yaml
kubectl apply -f k8s/4-mysql-service.yaml

print_success "MySQL resources created"

# Wait for MySQL to be ready
print_step "Waiting for MySQL to be ready..."
kubectl wait --for=condition=ready pod -l app=mysql --timeout=120s
print_success "MySQL is ready"

kubectl apply -f k8s/5-backend-configmap.yaml
kubectl apply -f k8s/6-backend-deployment.yaml
kubectl apply -f k8s/7-backend-service.yaml

print_success "Backend resources created"

kubectl apply -f k8s/8-frontend-deployment.yaml
kubectl apply -f k8s/9-frontend-service.yaml

print_success "Frontend resources created"

kubectl apply -f k8s/10-ingress.yaml

print_success "Ingress created"

# ==============================================================================
# Step 6: Wait for All Pods to be Ready
# ==============================================================================
print_step "Waiting for all pods to be ready..."

kubectl wait --for=condition=ready pod -l app=backend --timeout=120s
print_success "Backend pods are ready"

kubectl wait --for=condition=ready pod -l app=frontend --timeout=120s
print_success "Frontend pods are ready"

# ==============================================================================
# Step 7: Display Access Instructions
# ==============================================================================
echo ""
echo "============================================================"
echo -e "${GREEN}Deployment Complete!${NC}"
echo "============================================================"
echo ""

MINIKUBE_IP=$(minikube ip)

echo "Add the following line to your /etc/hosts file:"
echo -e "  ${YELLOW}${MINIKUBE_IP} myapp.local${NC}"
echo ""
echo "You can do this by running:"
echo -e "  ${BLUE}echo '${MINIKUBE_IP} myapp.local' | sudo tee -a /etc/hosts${NC}"
echo ""
echo "Then access the application at:"
echo -e "  ${GREEN}http://myapp.local${NC}"
echo ""
echo "============================================================"
echo "Useful Commands:"
echo "============================================================"
echo "  View pods:        kubectl get pods"
echo "  View services:    kubectl get services"
echo "  View ingress:     kubectl get ingress"
echo "  View backend logs: kubectl logs -l app=backend"
echo "  View frontend logs: kubectl logs -l app=frontend"
echo "  View MySQL logs:  kubectl logs -l app=mysql"
echo ""
echo "To delete all resources:"
echo "  kubectl delete -f k8s/"
echo ""
