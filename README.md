# Kubernetes Architecture & Deployment Guide

## Overview

Kubernetes is a container orchestration platform that automates deployment, scaling, and management of containerized applications across multiple servers.

## Architecture

```
Developer → Git Repo → CI/CD Pipeline → Container Registry → Kubernetes Cluster
                                                                    ↓
                                            Master Node (Control Plane)
                                            ├── API Server
                                            ├── Scheduler
                                            └── Controller Manager
                                                    ↓
                                    Worker Nodes (Multiple Servers)
                                    ├── Node 1 (Pod 1, Pod 2)
                                    ├── Node 2 (Pod 3, Pod 4)
                                    └── Node 3 (Pod 5, Pod 6)
```

## Real-World Deployment Flow

1. **Developer** pushes code to Git repository
2. **CI/CD Pipeline** (GitHub Actions, GitLab CI) automatically builds Docker image
3. **Image** is pushed to container registry (Docker Hub, ECR, GCR)
4. **YAML files** (deployment specs) are stored in Git
5. **Kubernetes** pulls image from registry and deploys to cluster
6. **Scheduler** decides which worker node runs each pod
7. **Kubelet** on each node manages pods locally

### Deploy Application

```bash
kubectl apply -f k8s/
```

Kubernetes automatically handles distribution across all servers.

## YAML Deployment Flow

### Where YAML is Deployed

The YAML is deployed to the **Master Node (Control Plane)**, not worker nodes.

```
Your Machine
    ↓
kubectl apply -f k8s/04-deployment.yaml
    ↓
Master Node (API Server receives YAML)
    ↓
Scheduler decides which Worker Nodes get the pods
    ↓
Worker Node 1: Pod 1 runs here
Worker Node 2: Pod 2 runs here
```

### Key Points

- **YAML deployed once** to Master Node's API Server
- **Master Node** stores the configuration
- **Scheduler** reads YAML and decides pod placement
- **Worker Nodes** run the actual pods (containers)
- **Kubelet** on each worker node manages pods locally

### Example with 3 Worker Nodes

```bash
kubectl apply -f k8s/04-deployment.yaml  # Deploy to Master
```

Master sees `replicas: 2` and tells:
- Worker Node 1: "Run Pod 1"
- Worker Node 2: "Run Pod 2"

### Check Pod Placement

```bash
kubectl get pods -o wide
```

Output:
```
NAME                    READY   NODE
acquisitions-app-xxx    1/1     node-1 (192.168.1.10)
acquisitions-app-yyy    1/1     node-2 (192.168.1.11)
```

## Master Node Configuration

The Master Node stores:

1. **Worker Node IPs** - registered when nodes join the cluster
2. **Pod assignments** - which pod runs on which node
3. **YAML configuration** - your deployment specs
4. **State** - current status of all resources

### Setup Process

```
Worker Node 1 (192.168.1.10)
    ↓ (joins cluster)
Master Node (192.168.1.5)
    ├── Stores: Node 1 IP = 192.168.1.10
    ├── Stores: Node 1 Status = Ready
    └── Stores: YAML configs

Worker Node 2 (192.168.1.11)
    ↓ (joins cluster)
Master Node
    ├── Stores: Node 2 IP = 192.168.1.11
    ├── Stores: Node 2 Status = Ready
    └── Scheduler: "Pod 1 → Node 1, Pod 2 → Node 2"
```

### Check Registered Nodes

```bash
kubectl get nodes
```

Output:
```
NAME       STATUS   ROLES           AGE
master     Ready    control-plane   10m
node-1     Ready    worker          8m
node-2     Ready    worker          7m
```

### Check Pod-to-Node Mapping

```bash
kubectl get pods -o wide
```

Output:
```
NAME                    READY   NODE
acquisitions-app-xxx    1/1     node-1 (192.168.1.10)
acquisitions-app-yyy    1/1     node-2 (192.168.1.11)
```

Master Node maintains this mapping and tells each worker node what to run via **Kubelet** (agent on each worker).

## Setup Kubernetes on 3 Ubuntu VMs 

### Step 1: Prepare All VMs

On each VM (Master and Workers):

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io curl
sudo usermod -aG docker $USER
```

### Step 2: Install Kubernetes Tools

On all 3 VMs:

```bash
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo systemctl enable kubelet
```

### Step 3: Initialize Master Node

On VM1 (Master):

```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Save the output token - you'll need it for worker nodes.

### Step 4: Install Network Plugin

On Master:

```bash
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

### Step 5: Join Worker Nodes

On Master, get join command:

```bash
kubeadm token create --print-join-command
```

On VM2 and VM3 (Workers):

```bash
sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

### Step 6: Verify Cluster

```bash
kubectl get nodes
```

All nodes should show `Ready` status.

### Step 7: Deploy Your Application

On Master:

```bash
kubectl apply -f k8s/
```

Verify deployment:

```bash
kubectl get pods
kubectl get svc
```

## Real-World Tools

- **ArgoCD** - GitOps (YAML changes auto-deploy)
- **Helm** - Package manager for Kubernetes
- **Kustomize** - Template management
- **Terraform** - Infrastructure as code

## Cloud Alternatives

- **AWS EKS** - Elastic Kubernetes Service (managed Kubernetes)
- **Google GKE** - Google Kubernetes Engine
- **Azure AKS** - Azure Kubernetes Service

For production, use managed services instead of manual setup.

## Key Concepts

### Pods
- Smallest deployable unit in Kubernetes
- Usually contains one container
- Can contain multiple containers (sidecar pattern)

### Deployments
- Manages pod replicas
- Handles rolling updates
- Ensures desired state

### Services
- Exposes pods to network
- Load balances traffic
- Provides stable IP/DNS

### ConfigMaps & Secrets
- Store configuration data
- Store sensitive data (passwords, tokens)
- Mounted as environment variables or files

### Persistent Volumes
- Storage that persists beyond pod lifecycle
- Shared across pods
- Managed by cluster

## Rolling Updates (Zero Downtime Deployments)

Rolling Update is a deployment strategy that updates pods one at a time with zero downtime.

### How It Works with 2 Replicas

```
Initial State:
  Pod 1 (v1) - Running
  Pod 2 (v1) - Running

Step 1: Create new pod
  Pod 1 (v1) - Running
  Pod 2 (v1) - Running
  Pod 3 (v2) - Creating

Step 2: New pod ready, traffic routes to it
  Pod 1 (v1) - Running
  Pod 2 (v1) - Running
  Pod 3 (v2) - Ready, receiving traffic

Step 3: Terminate old pod
  Pod 1 (v1) - Terminated
  Pod 2 (v1) - Running
  Pod 3 (v2) - Running

Step 4: Create another new pod
  Pod 2 (v1) - Running
  Pod 3 (v2) - Running
  Pod 4 (v2) - Creating

Step 5: New pod ready
  Pod 2 (v1) - Running
  Pod 3 (v2) - Running
  Pod 4 (v2) - Ready

Step 6: Terminate last old pod
  Pod 3 (v2) - Running
  Pod 4 (v2) - Running

Result: 2 new pods running, zero downtime
```

### Update Your Application

1. Build new image:
```bash
eval $(minikube docker-env)
docker build -t acquisitions-app:latest .
```

2. Trigger rolling update:
```bash
kubectl rollout restart deployment/acquisitions-app
```

Or update image tag:
```bash
kubectl set image deployment/acquisitions-app app=acquisitions-app:v2
```

3. Watch the update:
```bash
kubectl rollout status deployment/acquisitions-app
```

### Control Update Speed

Add to deployment spec to control rolling update behavior:

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # Max extra pods during update
      maxUnavailable: 0  # Min pods always available
```

- **maxSurge: 1** - Allow 1 extra pod during update (3 pods total with 2 replicas)
- **maxUnavailable: 0** - Ensure at least 1 pod is always running

This ensures continuous service availability during updates.

## Common Commands

```bash
# View resources
kubectl get nodes
kubectl get pods
kubectl get svc
kubectl get deployments

# Deploy
kubectl apply -f k8s/

# View logs
kubectl logs <pod-name>

# Execute command in pod
kubectl exec -it <pod-name> -- sh

# Scale deployment
kubectl scale deployment <name> --replicas=3

# Update deployment
kubectl rollout restart deployment/<name>

# Delete resources
kubectl delete deployment <name>
kubectl delete pod <pod-name>
```
