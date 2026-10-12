#!/usr/bin/env bash
set -euo pipefail
site_root="$(cd "$(dirname "$0")" && pwd)"
kubectl apply -f "$site_root/k8s/namespace.yaml"
kubectl apply -f "$site_root/k8s/certificates.yaml"
kubectl -n visirupt create configmap visirupt-site --from-file="$site_root/static" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n visirupt create configmap visirupt-nginx --from-file=nginx.conf="$site_root/k8s/nginx.conf" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$site_root/k8s/workload.yaml"
kubectl -n visirupt rollout restart deployment/visirupt-web
kubectl -n visirupt rollout status deployment/visirupt-web --timeout=60s
