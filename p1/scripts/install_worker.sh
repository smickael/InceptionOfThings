#!/bin/bash

# IP du serveur
SERVER_IP="192.168.56.110"

# Attendre que le serveur soit prêt
sleep 10

# Récupération du token depuis le serveur
TOKEN=$(sshpass -p "vagrant" ssh -o StrictHostKeyChecking=no vagrant@${SERVER_IP} \
  sudo cat /var/lib/rancher/k3s/server/node-token)

# Installation de k3s en mode agent
curl -sfL https://get.k3s.io | K3S_URL="https://${SERVER_IP}:6443" K3S_TOKEN="${TOKEN}" sh -