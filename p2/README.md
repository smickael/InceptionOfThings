# Part 2: K3s and three simple applications

This project guides you through the installation and configuration of **K3s** on a virtual machine. You will deploy three web applications accessible via the IP address 192.168.56.110, using specific hostnames (e.g., app1.com, app2.com, and app3.com). The default application will be displayed if no matching host is used (Here it will be application 3). Additionally, application 2 will be configured with three replicas.

``` mermaid
graph TD
    Client[Client Web Browser<br/>192.168.56.110] --> Host[Host Machine<br/>loginS<br/>192.168.56.110]
    
    Host --> Ingress[K3s Ingress Controller<br/>Routing based on HOST]
    
    Ingress -->|HOST: app1.com| App1[App 1<br/>Web Application]
    Ingress -->|HOST: app2.com| App2Service[App 2 Service<br/>Load Balancer]
    Ingress -->|HOST: default/autres| App3[App 3<br/>Web Application<br/>by default]
    
    App2Service --> App2Pod1[App 2 - Replica 1<br/>Pod]
    App2Service --> App2Pod2[App 2 - Replica 2<br/>Pod]
    App2Service --> App2Pod3[App 2 - Replica 3<br/>Pod]
    
    subgraph K3S["Cluster K3s"]
        Ingress
        App1
        App2Service
        App2Pod1
        App2Pod2
        App2Pod3
        App3
    end
    
    classDef hostClass fill:#4169E1,stroke:#000,stroke-width:2px,color:#fff
    classDef appClass fill:#87CEEB,stroke:#4169E1,stroke-width:2px
    classDef ingressClass fill:#9370DB,stroke:#000,stroke-width:2px,color:#fff
    classDef clusterClass fill:#f9f9f9,stroke:#333,stroke-width:2px
    
    class Host hostClass
    class App1,App2Pod1,App2Pod2,App2Pod3,App3 appClass
    class Ingress,App2Service ingressClass
    class K3S clusterClass
```

## Requirements & configuration

- `deploysAndIngress.yaml`: YAML manifest that describes what to deploy in your Kubernetes cluster.
- `install.sh`: script that transforms a blank VM into a working Kubernetes cluster.
- `Vagrantfile`: used with Vagrant, a tool that allows you to quickly create reproducible virtual machines for development.
- Add the following lines in your /etc/hosts:
``` bash
192.168.56.110 app1.com
192.168.56.110 app2.com
``` 

## Applications deployments

``` bash
# Start VM 
vagrant up 

# Connect to VM with ssh 
vagrant ssh smickaelS 

# Deploy applications 
kubectl apply -f /vagrant/k3s-apps.yaml 
# This command applies the Kubernetes configuration defined in a YAML file.
# Expected output: 
# 3 deployed applications (app1, app2, app3) each with:
# - A deployment: defines how to deploy and manage pods
# - A service: exposes the application within the cluster
# - A configmap: stores application templates/configurations
# 1 ingress: multi-app ingress that manages external routing to applications

# Check deployments 
kubectl get deployments 
kubectl get services 
kubectl get ingress 
kubectl get pods -o wide
```

## Tests & verifications

``` bash
# Check if Traefik is on
kubectl get pods -n kube-system | grep traefik

# Check LoadBalancer services
kubectl get services -n kube-system

# Check applications
curl -H "Host: app1.com" http://192.168.56.110
curl -H "Host: app2.com" http://192.168.56.110
curl http://192.168.56.110  # App3 by default
```

## Demos

``` bash
kubectl get ingress -o yaml
kubectl describe ingress multi-app-ingress
```

## Replicas

``` bash
kubectl get pods -l app=app2 -o wide
kubectl scale deployment app2 --replicas=5  # Scaling demo
```

## Logs

``` bash
kubectl logs -l app=app1
kubectl logs -l app=app2
```