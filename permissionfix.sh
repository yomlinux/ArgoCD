#!/bin/bash

echo "í´§ Setting up NFS Server Permissions for PostgreSQL"
echo "=================================================="

NFS_SERVER="10.0.0.135"
NFS_BASE_DIR="/data/app1/argocd"
NFS_DATA_DIR="/data/app1/argocd/postgresql"

echo "Configuring NFS server: $NFS_SERVER"
echo "NFS directory: $NFS_DATA_DIR"

# SSH to NFS server and set up permissions
ssh root@$NFS_SERVER << 'EOF'
set -e

NFS_BASE_DIR="/data/app1/argocd"
NFS_DATA_DIR="/data/app1/argocd/postgresql"

echo "1. Creating directory structure..."
mkdir -p $NFS_DATA_DIR

echo "2. Stopping any services that might be using the directory..."
# Check if any processes are using the directory
if lsof $NFS_DATA_DIR 2>/dev/null; then
    echo "   Warning: Processes are using the directory, attempting to identify..."
    lsof $NFS_DATA_DIR | head -10
fi

echo "3. Backing up existing data (if any)..."
if [ -d "$NFS_DATA_DIR" ] && [ "$(ls -A $NFS_DATA_DIR)" ]; then
    BACKUP_DIR="/tmp/postgresql_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p $BACKUP_DIR
    cp -a $NFS_DATA_DIR/* $BACKUP_DIR/ 2>/dev/null || true
    echo "   Backup created at: $BACKUP_DIR"
fi

echo "4. Cleaning up directory for fresh start..."
rm -rf $NFS_DATA_DIR/*
mkdir -p $NFS_DATA_DIR

echo "5. Setting correct ownership (UID 999, GID 999)..."
chown -R 999:999 $NFS_BASE_DIR

echo "6. Setting directory permissions..."
# Set base directory permissions
chmod 755 $NFS_BASE_DIR

# Set PostgreSQL data directory permissions
chmod 750 $NFS_DATA_DIR

# Set setgid bit so new files inherit group ownership
chmod g+s $NFS_DATA_DIR

# Set sticky bit on the directory
chmod +t $NFS_DATA_DIR

echo "7. Setting ACL for better permission control..."
# Install ACL tools if not present
if command -v setfacl >/dev/null 2>&1; then
    # Set default ACL for new files and directories
    setfacl -d -m u:999:rwx $NFS_DATA_DIR
    setfacl -d -m g:999:rwx $NFS_DATA_DIR
    setfacl -d -m o::--- $NFS_DATA_DIR

    # Set actual ACL
    setfacl -m u:999:rwx $NFS_DATA_DIR
    setfacl -m g:999:rwx $NFS_DATA_DIR
    setfacl -m o::--- $NFS_DATA_DIR
else
    echo "   ACL tools not available, using standard permissions"
fi

echo "8. Configuring NFS export permissions..."
# Check if the directory is in exports
if grep -q "$NFS_BASE_DIR" /etc/exports 2>/dev/null; then
    echo "   NFS export found, updating if needed..."
    # Example export line: /data/app1/argocd 10.0.0.0/24(rw,sync,no_root_squash,all_squash,anonuid=999,anongid=999)
    if ! grep -q "anonuid=999" /etc/exports; then
        echo "   Consider adding 'all_squash,anonuid=999,anongid=999' to NFS export options"
    fi
fi

echo "9. Verifying permissions..."
echo "=== Directory Structure ==="
ls -la $NFS_BASE_DIR/
echo ""

echo "=== PostgreSQL Directory Details ==="
ls -la $NFS_DATA_DIR/
echo ""

echo "=== Ownership Verification ==="
stat $NFS_DATA_DIR
echo ""

echo "=== Permission Test ==="
touch $NFS_DATA_DIR/test_file
mkdir $NFS_DATA_DIR/test_dir
echo "Test file and directory created:"
ls -la $NFS_DATA_DIR/test_*
echo ""

echo "=== Cleaning up test files ==="
rm -rf $NFS_DATA_DIR/test_*

echo "10. Setting up automatic permission maintenance..."
# Create a cron job to periodically fix permissions if needed
CRON_JOB="0 * * * * root chown -R 999:999 $NFS_DATA_DIR && chmod -R 750 $NFS_DATA_DIR"
if [ ! -f /etc/cron.d/nfs-argocd-maintenance ]; then
    echo "$CRON_JOB" > /etc/cron.d/nfs-argocd-maintenance
    chmod 644 /etc/cron.d/nfs-argocd-maintenance
    echo "   Maintenance cron job created"
else
    echo "   Maintenance cron job already exists"
fi

echo "âœ… NFS server permissions setup completed!"
EOF

echo ""
echo "í³‹ Permission setup summary:"
echo "   - Directory: $NFS_DATA_DIR"
echo "   - Owner: UID 999, GID 999"
echo "   - Permissions: 750 (rwxr-x---)"
echo "   - setgid bit: Enabled (files inherit group)"
echo "   - Sticky bit: Enabled"
echo ""
echo "Next steps:"
echo "1. Redeploy PostgreSQL: ./redeploy-postgresql.sh"
echo "2. Verify: ./debug-postgresql.sh"

echo "âš¡ Quick NFS Permission Fix"
echo "=========================="

NFS_SERVER="10.0.0.135"
NFS_DIR="/data/app1/argocd/postgresql"

echo "Fixing permissions on: $NFS_SERVER:$NFS_DIR"

ssh root@$NFS_SERVER << 'EOF'
set -e

NFS_DIR="/data/app1/argocd/postgresql"

echo "1. Stopping any processes using the directory..."
# Find and kill processes using the directory
if command -v lsof >/dev/null 2>&1; then
    PIDS=$(lsof -t $NFS_DIR 2>/dev/null || true)
    if [ -n "$PIDS" ]; then
        echo "   Stopping processes: $PIDS"
        kill -9 $PIDS 2>/dev/null || true
        sleep 2
    fi
fi

echo "2. Resetting ownership to UID 999, GID 999..."
chown -R 999:999 $NFS_DIR

echo "3. Setting directory permissions to 750..."
chmod -R 750 $NFS_DIR

echo "4. Setting setgid bit for inheritance..."
chmod g+s $NFS_DIR

echo "5. Verifying changes..."
ls -la $(dirname $NFS_DIR)/
echo ""
stat $NFS_DIR

echo "âœ… Quick permission fix completed!"
EOF

echo ""
echo "Now redeploy PostgreSQL to use the fixed permissions:"
echo "kubectl delete deployment -n argocd argocd-postgresql"
echo "kubectl apply -f postgresql-fixed.yaml"
