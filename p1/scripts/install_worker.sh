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
sudo /usr/local/bin/k3s-agent-uninstall.sh 2>/dev/null || true
sudo rm -rf /etc/rancher/k3s/ /var/lib/rancher/k3s/ || true

echo "=== Attente pour s'assurer que les processus sont terminés ==="
sleep 5

echo "=== Attente du token du serveur ==="
while [ ! -f /vagrant/token ]; do
  echo "Attente du token..."
  sleep 5
done

echo "=== Test de connectivité vers le serveur ==="
ping -c 3 192.168.56.110

echo "=== Installation de K3s agent ==="
export TKN=$(cat /vagrant/token)
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="agent --server https://192.168.56.110:6443 --node-ip 192.168.56.111 --token $TKN" sh -s -

echo "=== Vérification du statut de l'agent ==="
sleep 10
sudo systemctl status k3s-agent --no-pager

echo "=== Agent setup complete ==="