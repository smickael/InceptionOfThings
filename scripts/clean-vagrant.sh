#!/bin/bash
set -e

 # Vagrant VM cleanup (does not remove boxes)
echo "🧹 VAGRANT CLEANUP"
echo "===================="
echo "🔍 Searching for active Vagrant VMs..."
vagrant global-status --prune 2>/dev/null || true
echo ""
echo "Stopping and removing all Vagrant VMs..."
(cd p1 && vagrant destroy -f 2>/dev/null) || true
(cd p2 && vagrant destroy -f 2>/dev/null) || true
echo ""
echo "🧹 Cleaning global Vagrant data..."
vagrant global-status --prune 2>/dev/null || true
rm -rf .vagrant/ p1/.vagrant/ p2/.vagrant/ 2>/dev/null || true
echo "✅ Vagrant cleaned (boxes kept)"
