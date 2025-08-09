#!/bin/bash
set -e

 # Full Docker cleanup (containers, images, volumes, networks)
echo "🧹 DOCKER CLEANUP"
echo "==================="
echo "Stopping all containers..."
docker stop $(docker ps -aq) 2>/dev/null || true
echo ""
echo "🗑️  Removing all containers..."
docker rm $(docker ps -aq) 2>/dev/null || true
echo ""
echo "🗑️  Removing unused images..."
docker image prune -af 2>/dev/null || true
echo ""
echo "🗑️  Removing orphaned volumes..."
docker volume prune -f 2>/dev/null || true
echo ""
echo "🗑️  Removing unused networks..."
docker network prune -f 2>/dev/null || true
echo ""
echo "🧹 Cleaning Docker cache..."
docker system prune -af --volumes 2>/dev/null || true
echo "✅ Docker cleaned"
