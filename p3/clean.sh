#!/bin/bash

set -e

echo "=========================================="
echo "    FULL CLEANUP P3 (K3D)"
echo "=========================================="

 # Stop and delete all K3d clusters
echo "Deleting all K3d clusters..."
k3d cluster list --output json 2>/dev/null | jq -r '.[].name' 2>/dev/null | while read -r cluster; do
    if [ ! -z "$cluster" ]; then
    echo "  Deleting K3d cluster: $cluster"
        k3d cluster delete "$cluster" || true
    fi
done

 # Alternative if jq is not available
if ! command -v jq &> /dev/null; then
    echo "  Deleting all K3d clusters (alternative method)..."
    k3d cluster list 2>/dev/null | grep -v "NAME" | awk '{print $1}' | while read -r cluster; do
        if [ ! -z "$cluster" ] && [ "$cluster" != "NAME" ]; then
            echo "  Deleting K3d cluster: $cluster"
            k3d cluster delete "$cluster" || true
        fi
    done
fi

 # Clean Docker containers related to K3d
echo "Cleaning K3d Docker containers..."
docker ps -a --filter "label=app=k3d" --format "{{.ID}}" | while read -r container; do
    if [ ! -z "$container" ]; then
    echo "  Stopping K3d container: $container"
    docker stop "$container" 2>/dev/null || true
    echo "  Deleting K3d container: $container"
        docker rm "$container" 2>/dev/null || true
    fi
done

 # Clean K3d Docker networks
echo "Cleaning K3d Docker networks..."
docker network ls --filter "name=k3d" --format "{{.Name}}" | while read -r network; do
    if [ ! -z "$network" ]; then
    echo "  Deleting K3d network: $network"
        docker network rm "$network" 2>/dev/null || true
    fi
done

 # Clean K3d Docker volumes
echo "Cleaning K3d Docker volumes..."
docker volume ls --filter "name=k3d" --format "{{.Name}}" | while read -r volume; do
    if [ ! -z "$volume" ]; then
    echo "  Deleting K3d volume: $volume"
        docker volume rm "$volume" 2>/dev/null || true
    fi
done

 # Clean K3d kubeconfig files
echo "Cleaning kubeconfig files..."
rm -f ~/.kube/config || true
rm -rf ~/.k3d/ || true

 # Clean stopped containers and unused images
echo "General Docker cleanup..."
docker container prune -f || true
docker image prune -f || true
docker network prune -f || true
docker volume prune -f || true

echo "=========================================="
echo "    P3 CLEANUP COMPLETE"
echo "=========================================="
echo "All K3d clusters, containers, networks, and volumes have been deleted."
echo "Ports have been freed."
echo "You can now rerun: ./run.sh or the setup scripts."
