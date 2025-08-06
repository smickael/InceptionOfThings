# Commandes de test pour vérifier le cluster K3s

## Sur le nœud master (smickaelS)

```bash
# 1. Vérifier le statut du service K3s 
sudo systemctl status k3s

# 2. Exporter la configuration kubectl
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# 3. Vérifier les nœuds du cluster
kubectl get nodes -o wide

# 4. Vérifier les pods système
kubectl get pods -A

# 5. Vérifier les services système
kubectl get services -A

# 6. Afficher les informations détaillées du cluster
kubectl cluster-info

# 7. Vérifier la version de Kubernetes
kubectl version --short

# 8. Tester la création d'un pod simple
kubectl run test-pod --image=nginx --restart=Never

# 9. Vérifier que le pod est créé
kubectl get pods

# 10. Nettoyer le pod de test
kubectl delete pod test-pod
```

## Sur le nœud worker (smickaelSW)

```bash
# 1. Vérifier le statut du service K3s agent
sudo systemctl status k3s-agent

# 2. Vérifier les processus K3s
ps aux | grep k3s

# 3. Vérifier la connectivité réseau vers le master
ping -c 3 192.168.56.110

# 4. Vérifier que l'agent communique avec le master
sudo journalctl -u k3s-agent -f --no-pager | head -20

# ✅ INTERPRÉTATION DES LOGS K3S-AGENT :
# - "vxlan_network.go" : Configuration du réseau overlay VXLAN (normal)
# - "k3s agent is up and running" : L'agent fonctionne correctement ✅
# - "Starting network policy controller" : Contrôleur réseau démarré ✅
# - "Started Lightweight Kubernetes" : Service systemd actif ✅
# - Warnings "watcher.go" : Messages normaux, pas d'impact sur le fonctionnement
```

## Test avancé depuis le master

```bash
# Créer un déploiement avec réplication
kubectl create deployment nginx-test --image=nginx --replicas=2

# Vérifier que les pods sont distribués
kubectl get pods -o wide

# Exposer le déploiement
kubectl expose deployment nginx-test --port=80 --type=ClusterIP

# Tester la connectivité interne
kubectl run curl-test --image=curlimages/curl -it --rm -- curl nginx-test

# Nettoyer
kubectl delete deployment nginx-test
kubectl delete service nginx-test
```

## Vérifications réseau et état général

```bash
# Depuis le master - vérifier l'état des composants
kubectl get componentstatuses

# Vérifier les événements du cluster
kubectl get events --sort-by=.metadata.creationTimestamp

# Afficher les ressources disponibles
kubectl top nodes  # (si metrics-server est installé)

# Vérifier la configuration réseau
ip route
netstat -tuln | grep 6443
```
