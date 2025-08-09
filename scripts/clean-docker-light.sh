#!/bin/bash
set -e

 # Light Docker cleanup (containers, volumes, networks, but NOT images)
echo "🧹 DOCKER CLEANUP (light)"
echo "==================="
echo "Stopping all containers..."
docker stop $(docker ps -aq) 2>/dev/null || true
echo ""
echo "🗑️  Removing all containers..."
docker rm $(docker ps -aq) 2>/dev/null || true
echo ""
echo "🗑️  Removing orphaned volumes..."
docker volume prune -f 2>/dev/null || true
echo ""
echo "🗑️  Removing unused networks..."
docker network prune -f 2>/dev/null || true
echo "✅ Docker cleaned (images kept)"
