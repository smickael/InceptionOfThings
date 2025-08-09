#!/bin/bash
set -e

 # K3d cluster cleanup (does not remove images/charts)
echo "🧹 K3D CLEANUP"
echo "================"
echo "🔍 Searching for K3d clusters..."
k3d cluster list 2>/dev/null || echo "No K3d cluster found"
echo ""
echo "Deleting all K3d clusters..."
k3d cluster delete --all 2>/dev/null || true
echo ""
echo "🧹 Cleaning K3d networks..."
docker network ls | grep k3d | awk '{print $1}' | xargs -r docker network rm 2>/dev/null || true
echo "✅ K3d cleaned (images/charts kept)"
