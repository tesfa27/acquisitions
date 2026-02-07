#!/bin/bash

set -e

echo "🚀 Starting Minikube deployment..."

# # Start Minikube
# echo "📦 Starting Minikube..."
# minikube start

# Set Docker environment to Minikube
echo "🐳 Setting Docker environment to Minikube..."
eval $(minikube docker-env)

# Build image
echo "🔨 Building Docker image..."
docker build -t acquisitions-app:latest .

# Deploy to Kubernetes
echo "☸️  Deploying to Kubernetes..."
kubectl apply -f k8s/

# Wait for Neon Local to be ready
echo "⏳ Waiting for Neon Local to be ready..."
kubectl rollout status deployment/neon-local --timeout=2m

# Wait for deployment
echo "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/acquisitions-app --timeout=2m

# Expose service
minikube service acquisitions-app