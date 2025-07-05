#!/bin/bash

echo "=== Mise à jour du système ==="
sudo dnf update -y
sudo dnf install -y net-tools curl wget

echo "=== Désactivation des protections système ==="
sudo systemctl disable firewalld --now
sudo setenforce 0
sudo sed -i 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config

echo "=== Nettoyage des installations K3s précédentes ==="
sudo pkill -f k3s || true
sudo /usr/local/bin/k3s-uninstall.sh 2>/dev/null || true
sudo rm -rf /etc/rancher/k3s/ /var/lib/rancher/k3s/ || true

echo "=== Attente pour s'assurer que les processus sont terminés ==="
sleep 5

echo "=== Installation de K3s server ==="
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --node-ip 192.168.56.110 --write-kubeconfig-mode 644 --disable traefik --disable servicelb --token 12345" sh -s -

echo "=== Configuration de kubectl ==="
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /home/vagrant/.bashrc
echo 'alias k="kubectl"' >> /home/vagrant/.bashrc

echo "=== Sauvegarde du token pour l'agent ==="
echo "12345" > /vagrant/token
sudo cat /var/lib/rancher/k3s/server/node-token > /vagrant/server-token

echo "=== Attente du démarrage de K3s ==="
sleep 10

echo "=== Vérification du statut ==="
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
sudo systemctl status k3s --no-pager
kubectl get nodes || echo "En attente de l'initialisation complète..."

echo "=== Control plane setup complete ==="