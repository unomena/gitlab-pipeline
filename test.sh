#! /bin/sh -

# Exit on any failures
set -e

# Run ssh-agent (inside the build environment)
eval $(ssh-agent -s)

# Add bastion host ssh key to ssh agent.
mkdir keys
cp /tmp/keys/GITLAB_USER_BASTION_HOST_SSH_PRIVATE_KEY keys/id_rsa
chmod 700 keys/id_rsa
ssh-add keys/id_rsa

# Jump to bastion host and add expiring CA signed ssh key on it to local ssh agent.
# (Argument -n is required to avoid ssh eating the remainder of this script.)
ssh -n -o 'ForwardAgent yes' -o 'StrictHostKeyChecking=No' $BASTION_HOST_CONNECTION_STRING 'ssh-add'

# Fetch ansible playbook, templates and config.
mkdir -p templates
mkdir -p payload/templates
curl -s $PIPELINE_ASSETS_ROOT_URL/test.yml -o test.yml
#curl -s $PIPELINE_ASSETS_ROOT_URL/templates/env -o templates/env
curl -s $PIPELINE_ASSETS_ROOT_URL/templates/docker-compose.override.yml -o payload/templates/docker-compose.deploy.yml
curl -s $PIPELINE_ASSETS_ROOT_URL/ansible.cfg -o ansible.cfg

# Replace environment variables in playbook.
envsubst < test.yml > payload/test.yml

# Replace environment variables in env template file.
#envsubst < templates/env > payload/templates/env

# Add test compose file to payload.
#cp docker-compose-test.yml payload/
# Add indicated compose file to payload.
cp .env payload/.env
cp docker-compose.yml payload/
cp docker-compose.override.yml payload/

# Fetch Ansible inventory from cluster
scp -o StrictHostKeyChecking=No admin@$CLUSTER_IP:/etc/ansible_inventory payload/

# Execute Ansible playbook
cd payload
export ANSIBLE_FORCE_COLOR=1
export ANSIBLE_PIPELINING=1
ansible-playbook -i ansible_inventory --extra-vars "ansible_sudo_pass=$CLUSTER_ADMIN_USER_PASSWORD ci_job_token=$CI_JOB_TOKEN ci_registry=$CI_REGISTRY resource_prefix=$RESOURCE_PREFIX stack_hostname=$STACK_HOSTNAME stage=$STAGE aws_access_key=$AWS_ACCESS_KEY aws_secret_key=$AWS_SECRET_KEY" test.yml
