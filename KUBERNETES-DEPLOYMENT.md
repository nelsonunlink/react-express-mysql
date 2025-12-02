# Kubernetes Deployment Guide

This guide provides step-by-step instructions for deploying the React + Express + MySQL application on Minikube.

## Prerequisites

Before starting, ensure you have the following installed:

- [ ] **Minikube** - Local Kubernetes cluster (v1.25+)
- [ ] **kubectl** - Kubernetes command-line tool
- [ ] **Docker** - Container runtime

### Verify Installation

```bash
# Check Minikube version
minikube version

# Check kubectl version
kubectl version --client

# Check Docker version
docker --version
```

## Step-by-Step Deployment

### Step 1: Start Minikube

```bash
# Start Minikube with sufficient resources
minikube start --cpus=2 --memory=4096

# Enable Ingress addon (required for routing)
minikube addons enable ingress

# Verify Minikube is running
minikube status
```

### Step 2: Configure Docker to Use Minikube's Docker Daemon

This allows you to build Docker images directly into Minikube's Docker registry:

```bash
# Configure terminal to use Minikube's Docker daemon
eval $(minikube docker-env)

# Verify you're using Minikube's Docker
docker images  # Should show Minikube's images
```

> **Important**: Run this command in every new terminal session before building images.

### Step 3: Build Docker Images

```bash
# Navigate to project root
cd /path/to/react-express-mysql

# Build backend image
docker build -t react-mysql-backend:latest -f Dockerfile.backend .

# Build frontend image
docker build -t react-mysql-frontend:latest -f Dockerfile.frontend .

# Verify images were created
docker images | grep react-mysql
```

### Step 4: Apply Kubernetes Manifests

Apply manifests in order (the file names are numbered for this reason):

```bash
# Create MySQL secret
kubectl apply -f k8s/1-mysql-secret.yaml

# Create MySQL persistent volume and claim
kubectl apply -f k8s/2-mysql-pv-pvc.yaml

# Create MySQL init script ConfigMap
kubectl apply -f k8s/2.5-mysql-init-configmap.yaml

# Deploy MySQL
kubectl apply -f k8s/3-mysql-deployment.yaml
kubectl apply -f k8s/4-mysql-service.yaml

# Wait for MySQL to be ready
kubectl wait --for=condition=ready pod -l app=mysql --timeout=120s

# Deploy Backend
kubectl apply -f k8s/5-backend-configmap.yaml
kubectl apply -f k8s/6-backend-deployment.yaml
kubectl apply -f k8s/7-backend-service.yaml

# Deploy Frontend
kubectl apply -f k8s/8-frontend-deployment.yaml
kubectl apply -f k8s/9-frontend-service.yaml

# Create Ingress
kubectl apply -f k8s/10-ingress.yaml
```

### Step 5: Configure /etc/hosts

Get Minikube IP and add it to your hosts file:

```bash
# Get Minikube IP
minikube ip  # Example output: 192.168.49.2

# Add to /etc/hosts (Linux/Mac) - requires sudo
echo "$(minikube ip) myapp.local" | sudo tee -a /etc/hosts

# On Windows, edit C:\Windows\System32\drivers\etc\hosts
# Add: <minikube-ip> myapp.local
```

### Step 6: Verify Deployment

```bash
# Check all pods are running
kubectl get pods

# Expected output:
# NAME                        READY   STATUS    RESTARTS   AGE
# mysql-xxx                   1/1     Running   0          2m
# backend-xxx                 1/1     Running   0          1m
# backend-yyy                 1/1     Running   0          1m
# frontend-xxx                1/1     Running   0          30s
# frontend-yyy                1/1     Running   0          30s

# Check services
kubectl get services

# Check ingress
kubectl get ingress
```

### Step 7: Access the Application

Open your browser and navigate to:

```
http://myapp.local
```

## Verification Commands

### Check Pod Status

```bash
# List all pods with details
kubectl get pods -o wide

# Watch pods in real-time
kubectl get pods -w
```

### View Logs

```bash
# View backend logs
kubectl logs -l app=backend --tail=100

# View frontend logs
kubectl logs -l app=frontend --tail=100

# View MySQL logs
kubectl logs -l app=mysql --tail=100

# Follow logs in real-time
kubectl logs -f deployment/backend
```

### Check Resource Usage

```bash
# View resource consumption
kubectl top pods

# View node resources
kubectl top nodes
```

## Troubleshooting

### Common Issues

#### Pod Stuck in ImagePullBackOff

**Cause**: Kubernetes is trying to pull image from a remote registry instead of local.

**Solution**: 
1. Ensure you ran `eval $(minikube docker-env)` before building images
2. Verify images exist: `docker images | grep react-mysql`
3. Check `imagePullPolicy: Never` in deployment files

#### Backend Can't Connect to MySQL

**Cause**: MySQL pod not ready or wrong credentials.

**Solution**:
```bash
# Check MySQL is running
kubectl get pods -l app=mysql

# Check MySQL logs for errors
kubectl logs -l app=mysql

# Verify secret values
kubectl get secret mysql-secret -o yaml
```

#### Pod CrashLoopBackOff

**Cause**: Application error on startup.

**Solution**:
```bash
# Check logs for the crashing pod
kubectl logs <pod-name> --previous

# Describe pod for events
kubectl describe pod <pod-name>
```

#### Ingress Has No Address

**Cause**: Ingress controller not running.

**Solution**:
```bash
# Enable ingress addon
minikube addons enable ingress

# Wait for ingress controller
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

### Debugging Commands

```bash
# Get shell access to a pod
kubectl exec -it <pod-name> -- /bin/sh

# Port forward to test service directly
kubectl port-forward service/backend-service 8080:8080

# View all events
kubectl get events --sort-by='.lastTimestamp'

# Describe resources for detailed info
kubectl describe deployment backend
kubectl describe ingress app-ingress
```

## Learning Notes

### Why We Use ConfigMaps vs Secrets

- **ConfigMaps**: Store non-sensitive configuration data (DB host, app settings)
- **Secrets**: Store sensitive data like passwords (base64 encoded)
- Secrets can be encrypted at rest and have stricter RBAC controls

### How Kubernetes DNS Works

Services are accessible via DNS names:
- Simple: `service-name` (within same namespace)
- Full: `service-name.namespace.svc.cluster.local`

Example: Backend connects to `mysql-service` which resolves to the MySQL pod's IP.

### Why Probe Timing Matters

- **readinessProbe**: Determines when pod can receive traffic. Must pass before pod joins service.
- **livenessProbe**: Determines if pod is healthy. Failure triggers restart.
- **initialDelaySeconds**: Give app time to start before probing
- **periodSeconds**: How often to probe
- **failureThreshold**: How many failures before action is taken

### Resource Requests vs Limits

- **requests**: Minimum resources guaranteed to container
- **limits**: Maximum resources container can use
- Scheduler uses requests to place pods; limits prevent resource hogging

### Ingress Path Matching

- `pathType: Prefix`: Matches URL prefix (e.g., `/api` matches `/api/tutorials`)
- `pathType: Exact`: Matches exact path only
- Order matters: More specific paths should be listed first

## Quick Reference

### Useful kubectl Commands

| Command | Description |
|---------|-------------|
| `kubectl get all` | List all resources |
| `kubectl logs -f deploy/backend` | Follow backend logs |
| `kubectl describe pod <name>` | Detailed pod info |
| `kubectl exec -it <pod> -- sh` | Shell into pod |
| `kubectl port-forward svc/backend-service 8080:8080` | Local port forward |
| `kubectl delete -f k8s/` | Delete all resources |

### Cleanup

```bash
# Delete all application resources
kubectl delete -f k8s/

# Stop Minikube (preserves state)
minikube stop

# Delete Minikube cluster completely
minikube delete
```

## Production Considerations

When moving to production:

1. **Use proper image tags** instead of `:latest`
2. **Set `imagePullPolicy: Always`** with image registry
3. **Use external secrets management** (e.g., HashiCorp Vault)
4. **Configure CORS_ORIGIN** to specific domain
5. **Add TLS certificates** for HTTPS
6. **Set up monitoring** (Prometheus, Grafana)
7. **Configure pod autoscaling** (HPA)
8. **Use managed Kubernetes** (EKS, GKE, AKS)
