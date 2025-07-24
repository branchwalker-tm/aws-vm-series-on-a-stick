#!/bin/bash

SSH_KEY=$(terraform output -raw key_pair_name)
HOST=$(terraform output -raw vmseries_mgmt_public_ip)
PASSWORD=$(terraform output -raw admin_password)

ssh -i "${SSH_KEY}.pem" "admin@${HOST}" << EOF
configure
set mgt-config users admin password
${PASSWORD}
${PASSWORD}
commit
exit
EOF
