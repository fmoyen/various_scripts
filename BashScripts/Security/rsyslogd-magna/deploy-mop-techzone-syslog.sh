#!/bin/bash

# Usage:
#   ./deploy-mop-techzone-syslog.sh <IP>
#   ./deploy-mop-techzone-syslog.sh <IP> <PASSWORD>


cat << "EOF"
   


                ██╗██████╗ ███╗   ███╗
                ██║██╔══██╗████╗ ████║
                ██║██████╔╝██╔████╔██║
                ██║██╔══██╗██║╚██╔╝██║
                ██║██████╔╝██║ ╚═╝ ██║
                ╚═╝╚═════╝ ╚═╝     ╚═╝

                Montpellier zLinux Team

           Contact: alexandre.dini@fr.ibm.com

==============================================================
           Remote rsyslog deployment utility
==============================================================
EOF

set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: $0 <IP> [PASSWORD]"
    exit 1
fi

REMOTE_IP="$1"
PASSWORD="${2:-}"
REMOTE_USER="root"

# Verify required local files exist
FILES=(
    "ibm-intermediate.cer"
    "ibm-root.cer"
    "10-forward-to-collector.conf"
)

for file in "${FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "Error: file not found: $file"
        exit 1
    fi
done

# Configure SSH/SCP commands
if [ -n "$PASSWORD" ]; then
    if ! command -v sshpass &>/dev/null; then
        echo "Error: sshpass is not installed."
        echo "Install it using: dnf install -y sshpass"
        exit 1
    fi

    SCP_CMD="sshpass -p '$PASSWORD' scp -o StrictHostKeyChecking=no"
    SSH_CMD="sshpass -p '$PASSWORD' ssh -o StrictHostKeyChecking=no"
else
    SCP_CMD="scp"
    SSH_CMD="ssh"
fi

echo "Copying certificates to the remote server..."
eval "$SCP_CMD ibm-intermediate.cer ibm-root.cer ${REMOTE_USER}@${REMOTE_IP}:/opt/"

echo "Copying rsyslog configuration file..."
eval "$SCP_CMD 10-forward-to-collector.conf ${REMOTE_USER}@${REMOTE_IP}:/etc/rsyslog.d/"

echo "Applying remote configuration..."

eval "$SSH_CMD ${REMOTE_USER}@${REMOTE_IP}" <<'EOF'
set -e

mkdir -p /etc/pki/rsyslog

(cat /opt/ibm-intermediate.cer; echo; cat /opt/ibm-root.cer) \
    > /etc/pki/rsyslog/ibm-ca-chain.pem

openssl s_client \
    -connect 10.11.5.3:6514 \
    -CAfile /etc/pki/rsyslog/ibm-ca-chain.pem \
    </dev/null

systemctl restart rsyslog

echo "Rsyslog service restarted successfully."
EOF

echo "Deployment completed successfully on ${REMOTE_IP}."
