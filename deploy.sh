#! /bin/sh -

# Exit on any failures
set -e

# Set working dir perms to avoud ansible.cfg security error, see
# https://docs.ansible.com/ansible/devel/reference_appendices/config.html#cfg-in-world-writable-dir
chmod 700 .

# Add ssh key with which to execute ansible playbook.
mkdir keys
cp /tmp/keys/GITLAB_USER_BASTION_HOST_SSH_PRIVATE_KEY keys/id_rsa
chmod 700 keys/id_rsa

# Fetch ansible playbook, templates and config.
ssh -i keys/id_rsa $BASTION_HOST_CONNECTION_STRING "curl -s https://gitlab.unomena.net/unomenapublic/gitlab-pipeline/raw/master/ansible.cfg -o ansible.cfg"
ssh -i keys/id_rsa $BASTION_HOST_CONNECTION_STRING "curl -s https://gitlab.unomena.net/unomenapublic/gitlab-pipeline/raw/master/deploy.yml -o deploy.yml"
ssh -i keys/id_rsa $BASTION_HOST_CONNECTION_STRING "curl -s https://gitlab.unomena.net/unomenapublic/gitlab-pipeline/raw/master/templates/env -o templates/env"
ssh -i keys/id_rsa $BASTION_HOST_CONNECTION_STRING "mkdir -p templates"

# Fetch Ansible inventory from cluster
ssh -i keys/id_rsa -o StrictHostKeyChecking=No $BASTION_HOST_CONNECTION_STRING "scp -o StrictHostKeyChecking=No admin@$CLUSTER_IP:/etc/ansible_inventory ."

# Fetch inventory from cluster
#scp -i keys/id_rsa -o StrictHostKeyChecking=No admin@$CLUSTER_IP:/etc/ansible_inventory .

# Set environment variables in playbook.
#envsubst < deploy.yml > playbook.yml

# Execute playbook.
#ansible-playbook -i ansible_inventory --extra-vars "ansible_sudo_pass=$CLUSTER_ADMIN_USER_PASSWORD ci_job_token=$CI_JOB_TOKEN ci_registry=$CI_REGISTRY resource_prefix=$RESOURCE_PREFIX stack_hostname=$STACK_HOSTNAME stage=$STAGE aws_access_key=$AWS_ACCESS_KEY aws_secret_key=$AWS_SECRET_KEY compose_file=$COMPOSE_FILE" playbook.yml

echo Stack deployed to https://$STACK_HOSTNAME
