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

echo "=== Copie du manifeste Kubernetes dans /vagrant/k3s-apps.yaml ==="
if [ -f /vagrant/confs/ingress.yaml ]; then
    cp /vagrant/confs/ingress.yaml /vagrant/k3s-apps.yaml
    echo "Manifeste copié avec succès."
else
    echo "ERREUR: /vagrant/confs/ingress.yaml introuvable ! Copie annulée."
    exit 1
fi

echo "=== FIN ==="

echo "\n==================== K3s Helper ===================="
echo "\n🚀  Useful commands after installation:"
echo ""
echo "1️⃣  Deploy applications:"
echo "   kubectl apply -f /vagrant/k3s-apps.yaml"
echo "   # Deploys all apps and ingress from the manifest."
echo ""
echo "2️⃣  Check deployments/services/ingress/pods:"
echo "   kubectl get deployments"
echo "   kubectl get services"
echo "   kubectl get ingress"
echo "   kubectl get pods -o wide"
echo ""
echo "3️⃣  Test applications (from your host):"
echo "   curl -H 'Host: app1.com' http://192.168.56.110"
echo "   curl -H 'Host: app2.com' http://192.168.56.110"
echo "   curl http://192.168.56.110   # App3 by default"
echo ""
echo "4️⃣  Check Traefik and LoadBalancer:"
echo "   kubectl get pods -n kube-system | grep traefik"
echo "   kubectl get services -n kube-system"
echo ""
echo "5️⃣  Ingress details:"
echo "   kubectl get ingress -o yaml"
echo "   kubectl describe ingress multi-app-ingress"
echo ""
echo "6️⃣  Scale app2 (replicas):"
echo "   kubectl get pods -l app=app2 -o wide"
echo "   kubectl scale deployment app2 --replicas=5"
echo ""
echo "7️⃣  View logs:"
echo "   kubectl logs -l app=app1"
echo "   kubectl logs -l app=app2"
echo ""
echo "💡  Tip: Use 'k' as a shortcut for 'kubectl' (already set)."
echo "====================================================\n"