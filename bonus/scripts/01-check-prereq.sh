#!/bin/bash
set -e

done
for host in gitlab.42.fr argocd.42.fr app.42.fr; do
    if ! grep -q "127.0.0.1 $host" /etc/hosts; then
        echo "Adding $host to /etc/hosts"
        echo "127.0.0.1 $host" | sudo tee -a /etc/hosts > /dev/null
    fi
done

echo "=== Checking prerequisites ==="

 # Check availability of required tools
check_command() {
    if ! command -v "$1" &> /dev/null; then
    echo "❌ $1 is not installed"
        return 1
    else
    echo "✅ $1 is available"
        return 0
    fi
}

MISSING_TOOLS=0


 # List of required tools
for tool in docker k3d kubectl helm git curl jq lsof; do
    if ! check_command "$tool"; then
        MISSING_TOOLS=$((MISSING_TOOLS + 1))
    fi
done

 # Check if Docker is running
if command -v docker &> /dev/null; then
    if ! docker info &> /dev/null; then
    echo "❌ Docker is not running"
        MISSING_TOOLS=$((MISSING_TOOLS + 1))
    else
    echo "✅ Docker is working correctly"
    fi
fi

 # Check disk space
AVAILABLE_SPACE=$(df / | awk 'NR==2 {print $4}')
REQUIRED_SPACE=5000000  # 5GB in KB

if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    echo "❌ Insufficient disk space. Required: 5GB, Available: $((AVAILABLE_SPACE/1024/1024))GB"
    MISSING_TOOLS=$((MISSING_TOOLS + 1))
else
    echo "✅ Sufficient disk space"
fi

 # Automatically install missing tools
if [ $MISSING_TOOLS -gt 0 ]; then
    echo "Installing missing tools..."
    
    # Install expect for automating prompts
    if ! command -v expect &> /dev/null; then
    echo "Installing expect..."
        sudo apt-get update && sudo apt-get install -y expect
    fi

    # Install jq
    if ! command -v jq &> /dev/null; then
    echo "Installing jq..."
        sudo apt-get update && sudo apt-get install -y jq
    fi

    # Install lsof
    if ! command -v lsof &> /dev/null; then
    echo "Installing lsof..."
        sudo apt-get update && sudo apt-get install -y lsof
    fi
    
    # Install Docker
    if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
        sudo apt-get update && sudo apt-get install -y docker.io
        sudo systemctl start docker
        sudo usermod -aG docker $USER
    fi
    
    # Install k3d
    if ! command -v k3d &> /dev/null; then
    echo "Installing k3d..."
        curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
    fi
    
    # Install kubectl
    if ! command -v kubectl &> /dev/null; then
    echo "Installing kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
    fi

    # Install ArgoCD CLI
    if ! command -v argocd &> /dev/null; then
    echo "➡️  Installing the ArgoCD CLI..."
        if sudo curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && sudo chmod +x /usr/local/bin/argocd; then
        echo "ArgoCD CLI installed in /usr/local/bin"
        else
            mkdir -p "$HOME/.local/bin"
            curl -sSL -o "$HOME/.local/bin/argocd" https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
            chmod +x "$HOME/.local/bin/argocd"
            export PATH="$HOME/.local/bin:$PATH"
        echo "ArgoCD CLI installed in $HOME/.local/bin"
        fi
    fi
    
    # Install Helm
    if ! command -v helm &> /dev/null; then
    echo "Installing Helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
fi

echo "✅ All prerequisites are satisfied"
