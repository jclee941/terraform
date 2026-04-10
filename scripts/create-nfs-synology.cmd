#!/bin/bash
# Create NFS share on Synology - to be executed via SSH
# This script content will be executed on Synology

# Create shared folder
synoshare --add gitlab-runner-cache "GitLab Runner Cache" /volume1/gitlab-runner-cache 2>/dev/null || echo "Share may already exist"

# Enable NFS
synoshare --setnfs gitlab-runner-cache enable

# Add NFS rule for 192.168.50.0/24
synonfsext --add-rule gitlab-runner-cache 192.168.50.0/24 rw 2>/dev/null || echo "Rule may already exist"

# Verify
showmount -e localhost
echo "NFS share created successfully"
