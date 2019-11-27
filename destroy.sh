#! /bin/sh -

# Exit on any failures
set -e

if [ $STAGE = "test" ] && [ ! -f docker-compose-test.yml ]; then
    echo "File docker-compose-test.yml not found, skipping test destroy."
    exit 0
fi

# Run ssh-agent (inside the build environment)
eval $(ssh-agent -s)

# Add bastion host ssh key to ssh agent.
mkdir -p keys
cp /tmp/keys/GITLAB_USER_BASTION_HOST_SSH_PRIVATE_KEY keys/id_rsa
chmod 700 keys/id_rsa
ssh-add keys/id_rsa

# Jump to bastion host and add expiring CA signed ssh key on it to local ssh agent.
# (Argument -n is required to avoid ssh eating the remainder of this script.)
ssh -n -o 'ForwardAgent yes' -o 'StrictHostKeyChecking=No' $BASTION_HOST_CONNECTION_STRING 'ssh-add'

# Fetch ansible playbook and config.
curl -s https://gitlab.unomena.net/unomenapublic/gitlab-pipeline/raw/master/destroy.yml -o destroy.yml
curl -s https://gitlab.unomena.net/unomenapublic/gitlab-pipeline/raw/master/ansible.cfg -o ansible.cfg

# Replace environment variables in playbook.
envsubst < destroy.yml > playbook.yml

# Fetch Ansible inventory from cluster
scp -o StrictHostKeyChecking=No admin@$CLUSTER_IP:/etc/ansible_inventory .

# Execute Ansible playbook
export ANSIBLE_FORCE_COLOR=1
ansible-playbook -i ansible_inventory --extra-vars "ansible_sudo_pass=$CLUSTER_ADMIN_USER_PASSWORD ci_job_token=$CI_JOB_TOKEN ci_registry=$CI_REGISTRY resource_prefix=$RESOURCE_PREFIX stack_hostname=$STACK_HOSTNAME stage=$STAGE" playbook.yml

echo Destroyed stack serving https://$STACK_HOSTNAME