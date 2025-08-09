# Ajouter un alias k pour kubectl si absent
if ! grep -q 'alias k=' ~/.bashrc 2>/dev/null; then
  echo "alias k=\"kubectl\"" >> ~/.bashrc
  echo "alias kgp=\"kubectl get pods\"" >> ~/.bashrc
  echo "alias kgpa=\"kubectl get pods -A\"" >> ~/.bashrc
  echo "alias kgs=\"kubectl get svc\"" >> ~/.bashrc
  echo "alias kgsa=\"kubectl get svc -A\"" >> ~/.bashrc
  echo "alias kgi=\"kubectl get ingress -A\"" >> ~/.bashrc
  echo "alias kgia=\"kubectl get ingress -A\"" >> ~/.bashrc

  echo "alias gitlabpass=\"kubectl get secret -n gitlab gitlab-gitlab-initial-root-password -o jsonpath='{.data.password}' | base64 -d\"" >> ~/.bashrc
  echo "alias argopass=\"kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d\"" >> ~/.bashrc
  echo "alias gitlabpat=\"cat /tmp/gitlab_pat.txt\"" >> ~/.bashrc

  echo "Alias 'k' ajouté pour kubectl dans ~/.bashrc"
  source ~/.bashrc
fi
#!/bin/bash
set -e

# Mise à jour des paquets
sudo apt-get update

echo "🔍 Installation des prérequis : Docker, k3d, kubectl, helm, VirtualBox, Vagrant, jq, vim..."


# Docker
if ! command -v docker &>/dev/null; then
    echo "➡️  Installation de Docker..."
    sudo apt-get update
    sudo apt-get install -y docker.io
    sudo systemctl start docker
fi
# Ajouter l'utilisateur au groupe docker
sudo usermod -aG docker $USER

# k3d
if ! command -v k3d &>/dev/null; then
    echo "➡️  Installation de k3d..."
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

# kubectl
if ! command -v kubectl &>/dev/null; then
    echo "➡️  Installation de kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
fi

# helm
if ! command -v helm &>/dev/null; then
    echo "➡️  Installation de helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

VBOX_VERSION="7.0.26-168464~Ubuntu~$(lsb_release -cs)"

# VirtualBox
if ! command -v VBoxManage &>/dev/null; then
    echo "➡️  Installation de VirtualBox version $VBOX_VERSION ..."
    wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo gpg --yes --dearmor -o /usr/share/keyrings/oracle-virtualbox-2016.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib" | sudo tee /etc/apt/sources.list.d/virtualbox.list
    if ! apt-cache madison virtualbox-7.0 | grep -q "$VBOX_VERSION"; then
        echo "❌ Version VirtualBox $VBOX_VERSION non trouvée dans le dépôt."
        echo "Versions disponibles :"
        apt-cache madison virtualbox-7.0
        exit 1
    fi
    sudo apt-get install -y virtualbox-7.0="$VBOX_VERSION"
    sudo apt-get install build-essential dkms linux-headers-$(uname -r)
    sudo /sbin/vboxconfig
fi

# Vagrant
if ! command -v vagrant &>/dev/null; then
    echo "➡️  Installation de Vagrant..."
    sudo apt-get update
    sudo apt-get install -y vagrant
fi

# jq
if ! command -v jq &>/dev/null; then
    echo "➡️  Installation de jq..."
    sudo apt-get update
    sudo apt-get install -y jq
fi

# yq
if ! command -v yq &>/dev/null; then
    echo "➡️  Installation de yq..."
    sudo wget -O /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    sudo chmod +x /usr/local/bin/yq
fi

# socat (pour les proxies TCP)
if ! command -v socat &>/dev/null; then
    echo "➡️  Installation de socat..."
    sudo apt-get update
    sudo apt-get install -y socat
fi

# openssh-server
if ! command -v sshd &>/dev/null; then
    echo "➡️  Installation de openssh-server..."
    sudo apt-get update
    sudo apt-get install -y openssh-server
    # sudo systemctl enable ssh
fi

# install argocd cli
if ! command -v argocd &> /dev/null; then
    echo "➡️  Installation du CLI ArgoCD..."
    if sudo curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && sudo chmod +x /usr/local/bin/argocd; then
        echo "ArgoCD CLI installé dans /usr/local/bin"
    else
        mkdir -p "$HOME/.local/bin"
        curl -sSL -o "$HOME/.local/bin/argocd" https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        chmod +x "$HOME/.local/bin/argocd"
        export PATH="$HOME/.local/bin:$PATH"
        echo "ArgoCD CLI installé dans $HOME/.local/bin"
    fi
fi

# Add user to vboxsf group
sudo usermod -aG vboxsf $USER

echo "✅ All prerequisites are installed."
echo "ℹ️  Log out and log back in to apply docker and vboxsf group changes."
