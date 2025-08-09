#!/bin/bash
set -e

 # Clean caches (Vagrant, Docker, Helm, Kubernetes, logs, .DS_Store)
echo "🧹 CACHE CLEANUP"
echo "=================="
echo "🗑️  Removing Vagrant caches..."
rm -rf ~/.vagrant.d/tmp/* 2>/dev/null || true
rm -rf ~/.vagrant.d/boxes/*/*/virtualbox/box_update_check 2>/dev/null || true
echo ""
echo "🗑️  Removing Docker caches..."
rm -rf ~/.docker/buildx/cache/* 2>/dev/null || true
echo ""
echo "🗑️  Removing Helm caches..."
rm -rf ~/.cache/helm/* 2>/dev/null || true
rm -rf ~/.config/helm/repositories.lock 2>/dev/null || true
echo ""
echo "🗑️  Removing Kubernetes caches..."
rm -rf ~/.kube/cache/* 2>/dev/null || true
echo ""
echo "🗑️  Removing temporary logs..."
rm -rf /tmp/k3* /tmp/vagrant* /tmp/docker* 2>/dev/null || true
echo ""
echo "🗑️  Removing .DS_Store files (macOS)..."
find . -name ".DS_Store" -delete 2>/dev/null || true
echo "✅ Cache cleaned"
