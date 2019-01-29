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

#apt install openssh-client -y
eval $(ssh-agent -s)
echo "$GITLAB_USER_BASTION_HOST_SSH_PRIVATE_KEY" | tr -d '\r' | ssh-add - > /dev/null


mkdir keys
cp /tmp/keys/GITLAB_USER_BASTION_HOST_SSH_PRIVATE_KEY keys/id_rsa
chmod 700 keys/id_rsa

ssh -i keys/id_rsa -n -o 'ForwardAgent yes' -o 'StrictHostKeyChecking=No' $BASTION_HOST_CONNECTION_STRING 'ssh-add'
echo "DEBUG"

# Fetch ansible playbook, templates and config.
mkdir -p templates
mkdir -p payload/templates
curl -s https://gitlab.unomena.net/unomenapublic/gitlab-pipeline/raw/master/deploy.yml -o deploy.yml
curl -s https://gitlab.unomena.net/unomenapublic/gitlab-pipeline/raw/master/templates/env -o templates/env
curl -s https://gitlab.unomena.net/unomenapublic/gitlab-pipeline/raw/master/ansible.cfg -o ansible.cfg

# Replace environment variables in playbook.
envsubst < deploy.yml > payload/deploy.yml

# Replace environment variables in env template file.
envsubst < templates/env > payload/templates/env

# Add indicated compose file to payload.
cp $COMPOSE_FILE payload/

# Sync deploy artifacts to unique workspace on bastion host.
rsync -avzhe "ssh -i keys/id_rsa -o StrictHostKeyChecking=No" payload/ $BASTION_HOST_CONNECTION_STRING:~/$WORKSPACE_NAME
#ssh -i keys/id_rsa -o StrictHostKeyChecking=No $BASTION_HOST_CONNECTION_STRING "mkdir $WORKSPACE_NAME"
#scp -i keys/id_rsa -o StrictHostKeyChecking=No playbook.yml $BASTION_HOST_CONNECTION_STRING:~/$WORKSPACE_NAME

# Fetch Ansible inventory from cluster and execute playbook on bastion host.
ssh -i keys/id_rsa -o StrictHostKeyChecking=No $BASTION_HOST_CONNECTION_STRING << EOF
    cd $WORKSPACE_NAME
    scp -o StrictHostKeyChecking=No admin@$CLUSTER_IP:/etc/ansible_inventory .
    ansible-playbook -i ansible_inventory --extra-vars "ansible_sudo_pass=$CLUSTER_ADMIN_USER_PASSWORD ci_job_token=$CI_JOB_TOKEN ci_registry=$CI_REGISTRY resource_prefix=$RESOURCE_PREFIX stack_hostname=$STACK_HOSTNAME stage=$STAGE aws_access_key=$AWS_ACCESS_KEY aws_secret_key=$AWS_SECRET_KEY compose_file=$COMPOSE_FILE" deploy.yml
EOF

echo Deployed stack to https://$STACK_HOSTNAME