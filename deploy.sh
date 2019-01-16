#! /bin/sh -

# Exit on any failures
set -e

# Add bastion host ssh key.
mkdir keys
cp /tmp/keys/GITLAB_USER_BASTION_HOST_SSH_PRIVATE_KEY keys/id_rsa
chmod 700 keys/id_rsa

# Fetch ansible playbook, templates and config.
mkdir -p templates
curl -s https://gitlab.unomena.net/unomenapublic/gitlab-pipeline/raw/master/ansible.cfg -o ansible.cfg
curl -s https://gitlab.unomena.net/unomenapublic/gitlab-pipeline/raw/master/deploy.yml -o deploy.yml
curl -s https://gitlab.unomena.net/unomenapublic/gitlab-pipeline/raw/master/templates/env -o templates/env

# Set environment variables in playbook.
envsubst < deploy.yml > playbook.yml

# Sync deploy artifacts to unique deploy path on bastion host.
DEPLOY_PATH=deploy-$RANDOM
rsync -avzhe "ssh -i ../keys/id_rsa -o StrictHostKeyChecking=No" --exclude='.git' . $BASTION_HOST_CONNECTION_STRING:~/$DEPLOY_PATH

# Fetch Ansible inventory from cluster
ssh -i ../keys/id_rsa -o StrictHostKeyChecking=No $BASTION_HOST_CONNECTION_STRING << EOF
    cd $DEPLOY_PATH
    scp -o StrictHostKeyChecking=No admin@$CLUSTER_IP:/etc/ansible_inventory .
    ansible-playbook -i ansible_inventory --extra-vars "ansible_sudo_pass=$CLUSTER_ADMIN_USER_PASSWORD ci_job_token=$CI_JOB_TOKEN ci_registry=$CI_REGISTRY resource_prefix=$RESOURCE_PREFIX stack_hostname=$STACK_HOSTNAME stage=$STAGE aws_access_key=$AWS_ACCESS_KEY aws_secret_key=$AWS_SECRET_KEY compose_file=$COMPOSE_FILE" playbook.yml
EOF

echo Stack deployed to https://$STACK_HOSTNAME
# Set working dir perms to avoid ansible.cfg security error, see
# https://docs.ansible.com/ansible/devel/reference_appendices/config.html#cfg-in-world-writable-dir
#chmod 700 .




#rsync -avzhe ssh . $BASTION_HOST_CONNECTION_STRING:~/ 2>&1 >/dev/null; \



# Fetch inventory from cluster
#scp -i keys/id_rsa -o StrictHostKeyChecking=No admin@$CLUSTER_IP:/etc/ansible_inventory .


# Execute playbook.

