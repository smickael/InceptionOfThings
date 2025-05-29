
#!/bin/bash

# Mise à jour de base
sudo apt-get update -y

# Installation de k3s en mode serveur
curl -sfL https://get.k3s.io | sh -

# Rendre le kubeconfig accessible à l'utilisateur vagrant
sudo chown vagrant:vagrant /etc/rancher/k3s/k3s.yaml