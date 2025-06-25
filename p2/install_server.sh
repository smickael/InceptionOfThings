#!/bin/bash

echo "=== Mise à jour du système ==="
sudo dnf update -y
sudo dnf install -y net-tools curl wget

echo "=== Désactivation des protections système ==="
sudo systemctl disable firewalld --now
sudo setenforce 0
sudo sed -i 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config

echo "=== Nettoyage ==="
sudo pkill -f k3s || true
sudo /usr/local/bin/k3s-uninstall.sh 2>/dev/null || true
sudo rm -rf /etc/rancher/k3s/ /var/lib/rancher/k3s/ || true
sleep 5

echo "=== Installation K3s SIMPLE ==="
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

echo "=== Attente et vérification ==="
sleep 20
sudo systemctl status k3s --no-pager

echo "=== Test kubectl ==="
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
sudo chmod 644 /etc/rancher/k3s/k3s.yaml

# Test simple
kubectl get nodes || echo "ERREUR: kubectl ne fonctionne pas"

echo "=== Configuration utilisateur ==="
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /home/vagrant/.bashrc
echo 'alias k="kubectl"' >> /home/vagrant/.bashrc

echo "=== FIN ==="