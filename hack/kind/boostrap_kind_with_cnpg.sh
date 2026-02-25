#!/bin/bash
set -euxo pipefail

K8S_VERSION=${K8S_VERSION:-v1.32.2}

cd "$(dirname "$0")"

# Create kind cluster
kind create cluster --config ./kind.yaml --image "kindest/node:${K8S_VERSION}"

# Install cilium
helm repo add cilium https://helm.cilium.io/
helm -n kube-system upgrade --install cilium cilium/cilium --version 1.17.4 --namespace kube-system --set envoy.enabled=false --set ipv6.enabled=true

# Install metrics server
kubectl apply -f ./metrics-server.yaml

# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.18.2/cert-manager.yaml

# Install minio
helm repo add minio https://charts.min.io/
helm upgrade --install \
  --set resources.requests.memory=512Mi \
  --set replicas=1 \
  --set mode=standalone \
  --set persistence.enabled=false \
  --set rootUser=rootuser,rootPassword=rootpass123 \
  --set 'buckets[0].name=test-bucket-1,buckets[0].policy=none,buckets[0].purge=false' \
  --set 'buckets[1].name=test-bucket-2,buckets[1].policy=none,buckets[1].purge=false' \
  minio minio/minio

# To access minio with kubectl:
# MINIO_POD_NAME=$(kubectl get pods --namespace default -l "release=minio" -o jsonpath="{.items[0].metadata.name}")
# kubectl exec $MINIO_POD_NAME -- mc alias set local http://localhost:9000 rootuser rootpass123
# kubectl exec $MINIO_POD_NAME -- mc ls local
# kubectl exec $MINIO_POD_NAME -- mc ls local/test-bucket-1

# Install CNPG
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.27/releases/cnpg-1.27.0.yaml

# Wait for CNPG manager deployment is ready
kubectl rollout status deployment/cnpg-controller-manager -n cnpg-system --timeout=180s
