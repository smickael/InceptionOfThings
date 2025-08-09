
expand-disk:
	sudo bash scripts/expand_root_disk.sh
# Makefile pour le projet IoT - Nettoyage complet
# Usage: make clean

.PHONY: help clean clean-vagrant clean-k3d clean-docker clean-cache status

# Affichage de l'aide par défaut
help:
	@echo "🧹 MAKEFILE DE NETTOYAGE PROJET IOT"
	@echo "===================================="
	@echo ""
	@echo "Commandes disponibles:"
	@echo "  make p1            Nettoyer et lancer la partie 1 (K3s + Vagrant)"
	@echo "  make p2            Nettoyer et lancer la partie 2 (K3s + Apps)"
	@echo "  make p3            Nettoyer et lancer la partie 3 (K3d + ArgoCD)"
	@echo "  make bonus         Nettoyer, lancer p3 si besoin, puis le bonus (K3d + GitLab)"
	@echo "  make clean         Nettoyage complet (tout supprimer)"
	@echo "  make clean-vagrant Supprimer toutes les VMs Vagrant"
	@echo "  make clean-k3d     Supprimer tous les clusters K3d"
	@echo "  make clean-docker  Nettoyer Docker (containers, images, volumes)"
	@echo "  make clean-cache   Supprimer les dossiers cache"
	@echo "  make status        Afficher l'état actuel"
	@echo "  make help          Afficher cette aide"
	@echo ""
	@echo "⚠️  ATTENTION: 'make clean' supprime TOUT (irréversible)"
	@echo ""

# Nettoyage complet (sans supprimer les caches, images, box, charts)
clean:
	bash scripts/clean-vagrant.sh
	bash scripts/clean-k3d.sh
	bash scripts/clean-docker-light.sh
	@echo "\n🎉 NETTOYAGE TERMINÉ (caches, images, box, charts conservés) !\n===============================\n\n✅ Tous les environnements ont été supprimés (caches, images, box, charts conservés)\n✅ Système prêt pour une nouvelle installation\n\nPour relancer un environnement:\n  cd p1 && ./run.sh    # Partie 1 (Vagrant + K3s)\n  cd p2 && ./run.sh    # Partie 2 (Vagrant + Apps)\n  cd p3 && ./run.sh    # Partie 3 (K3d + ArgoCD)\n  cd bonus && ./run.sh # Bonus (K3d + GitLab)\n"

# Nettoyage complet + suppression des caches, images, box, charts (gain d'espace disque)
fclean:
	bash scripts/clean-vagrant.sh
	bash scripts/clean-k3d.sh
	bash scripts/clean-docker.sh
	bash scripts/clean-cache.sh
	@echo "\n🎉 NETTOYAGE COMPLET TERMINÉ !\n===============================\n\n✅ Tous les environnements et caches ont été supprimés (max espace disque)\n✅ Système prêt pour une nouvelle installation (max espace disque)\n\nPour relancer un environnement:\n  cd p1 && ./run.sh    # Partie 1 (Vagrant + K3s)\n  cd p2 && ./run.sh    # Partie 2 (Vagrant + Apps)\n  cd p3 && ./run.sh    # Partie 3 (K3d + ArgoCD)\n  cd bonus && ./run.sh # Bonus (K3d + GitLab)\n"

# Supprimer les dossiers cache
clean-cache:
	bash scripts/clean-cache.sh

# Afficher l'état actuel du système
status:
	bash scripts/status.sh

.PHONY: p1
p1:
	$(MAKE) clean
	@echo "🚀 Lancement de la partie 1 (K3s + Vagrant)"
	@echo "🚀 Vérification des prérequis p1..."
	@(cd p1/scripts && bash check_prereq.sh)
	@echo "🚀 Lancement de la partie 1 (K3s + Vagrant)"
	@(cd p1 && ./run.sh)

.PHONY: p2
p2:
	$(MAKE) clean
	@echo "🚀 Lancement de la partie 2 (K3s + Apps)"
	@echo "🚀 Vérification des prérequis p2..."
	@(cd p2/scripts && bash check_prereq.sh)
	@echo "🚀 Lancement de la partie 2 (K3s + Apps)"
	@(cd p2 && ./run.sh)

.PHONY: p3
p3:
	$(MAKE) clean
	@echo "🚀 Lancement de la partie 3 (K3d + ArgoCD)"
	@echo "🚀 Vérification des prérequis p3..."
	@(cd p3/scripts && bash check_prereq.sh)
	@echo "🚀 Lancement de la partie 3 (K3d + ArgoCD)"
	@(cd p3 && ./run.sh)

add-gitlab-host:
	@if ! grep -q "gitlab.local" /etc/hosts; then \
		echo "127.0.0.1 gitlab.local" | sudo tee -a /etc/hosts; \
		echo "Entrée ajoutée à /etc/hosts"; \
	else \
		echo "Entrée déjà présente dans /etc/hosts"; \
	fi

.PHONY: bonus
bonus:
	@echo "🚀 Lancement du bonus (K3d + GitLab) : installation GitLab sur cluster p3 existant..."
	@if kubectl get ns gitlab &>/dev/null; then \
		echo "⚠️  Namespace gitlab déjà présent, suppression des ressources GitLab..."; \
		kubectl delete ns gitlab; \
		sleep 5; \
	fi
	(cd bonus && ./run.sh)

.PHONY: bonus-next
bonus-next:
	@echo "🔗 Connexion du repo GitLab à ArgoCD et déploiement auto..."
	(cd bonus/scripts && bash connect_gitlab_to_argocd.sh)

install:
	@echo "Installation des programmes requis pour toutes les parties..."
	bash scripts/install-prerequisites.sh
