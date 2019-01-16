#! /bin/sh -

# Exit on any failures
set -e

# Generate random workspace path name
WORKSPACE_NAME=workspace-$RANDOM-$RANDOM

# Always cleanup bastion host workspace
function cleanup {
    ssh -i keys/id_rsa -o StrictHostKeyChecking=No $BASTION_HOST_CONNECTION_STRING << EOF
    rm -rf $WORKSPACE_NAME
EOF
}
trap cleanup EXIT

# Add bastion host ssh key.
mkdir keys
cp /tmp/keys/GITLAB_USER_BASTION_HOST_SSH_PRIVATE_KEY keys/id_rsa
chmod 700 keys/id_rsa

# Fetch ansible playbook and config.
curl -s https://gitlab.unomena.net/unomenapublic/gitlab-pipeline/raw/master/destroy.yml -o destroy.yml
curl -s https://gitlab.unomena.net/unomenapublic/gitlab-pipeline/raw/master/ansible.cfg -o ansible.cfg

# Replace environment variables in playbook.
envsubst < destroy.yml > playbook.yml

# Sync deploy artifacts to unique deploy path on bastion host.
rsync -avzhe "ssh -i keys/id_rsa -o StrictHostKeyChecking=No" --exclude='.git' --exclude='keys' . $BASTION_HOST_CONNECTION_STRING:~/$WORKSPACE_NAME

# Fetch Ansible inventory from cluster and execute playbook on bastion host.
ssh -i keys/id_rsa -o StrictHostKeyChecking=No $BASTION_HOST_CONNECTION_STRING << EOF
    cd $WORKSPACE_NAME
    scp -o StrictHostKeyChecking=No admin@$CLUSTER_IP:/etc/ansible_inventory .
    ansible-playbook -i ansible_inventory --extra-vars "ansible_sudo_pass=$CLUSTER_ADMIN_USER_PASSWORD ci_job_token=$CI_JOB_TOKEN ci_registry=$CI_REGISTRY resource_prefix=$RESOURCE_PREFIX stack_hostname=$STACK_HOSTNAME stage=$STAGE" playbook.yml
    cd ..
    rm -rf $WORKSPACE_NAME
EOF

echo Destroyed stack serving https://$STACK_HOSTNAME