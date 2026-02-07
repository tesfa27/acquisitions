# Kubernetes Manifests for Minikube

## Quick Start

### 1. Start Minikube
```bash
minikube start --cpus=4 --memory=4096
```

### 2. Build Image in Minikube
```bash
eval $(minikube docker-env)
docker build -t acquisitions:latest .
```

### 3. Deploy
```bash
kubectl apply -f k8s/
```

### 4. Access App
```bash
minikube ip  # Get IP
# Visit: http://<minikube-ip>:30000
```

### 5. View Logs
```bash
kubectl logs -f deployment/acquisitions-app
```

### 6. Port Forward (Alternative)
```bash
kubectl port-forward svc/acquisitions-app 3000:80
# Visit: http://localhost:3000
```

## Files
- `00-namespace.yaml` - Uses default namespace
- `01-configmap.yaml` - Dev configuration
- `02-secret.yaml` - Dev credentials
- `03-pvc.yaml` - 1Gi storage for logs
- `04-deployment.yaml` - 1 replica, minimal resources
- `05-service.yaml` - NodePort on port 30000

## Cleanup
```bash
kubectl delete -f k8s/
minikube stop
```
