#! /bin/sh -

# Exit on any failures
set -e

# Install required packages and ansible.
apt-get -yy update
apt-get install -y openssh-client
pip install ansible

# Set working dir perms to avoud ansible.cfg security error, see
# https://docs.ansible.com/ansible/devel/reference_appendices/config.html#cfg-in-world-writable-dir
chmod 700 .

# Add ssh key with which to execute ansible playbook.
mkdir keys
cp $CLUSTER_ADMIN_USER_SSH_PRIVATE_KEY_FILE keys/id_rsa
chmod 700 keys/id_rsa

# Fetch ansible playbook and config.
wget https://gitlab.unomena.net/unomenapublic/gitlab-pipeline/raw/master/destroy.yml
wget https://gitlab.unomena.net/unomenapublic/gitlab-pipeline/raw/master/ansible.cfg

# Fetch inventory from cluster
scp -i keys/id_rsa -o StrictHostKeyChecking=No admin@$CLUSTER_IP:/etc/ansible_inventory .

# Execute playbook.
ansible-playbook -i ansible_inventory --extra-vars "ansible_sudo_pass=$CLUSTER_ADMIN_USER_PASSWORD ci_job_token=$CI_JOB_TOKEN ci_registry=$CI_REGISTRY resource_prefix=$RESOURCE_PREFIX stack_hostname=$STACK_HOSTNAME stage=$STAGE" destroy.yml