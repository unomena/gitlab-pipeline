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
curl -s https://gitlab.unomena.net/unomenapublic/gitlab-pipeline/raw/master/templates/env -o templates/env_unsub

# Replace environment variables in playbook.
envsubst < deploy.yml > playbook.yml

# Replace environment variables in env template file.
envsubst < templates/env_unsub > templates/env

# Sync deploy artifacts to unique deploy path on bastion host.
DEPLOY_PATH=deploy-$RANDOM
rsync -avzhe "ssh -i keys/id_rsa -o StrictHostKeyChecking=No" --exclude='.git' --exclude='keys' . $BASTION_HOST_CONNECTION_STRING:~/$DEPLOY_PATH

# Fetch Ansible inventory from cluster and execute playbook on bastion host.
ssh -i keys/id_rsa -o StrictHostKeyChecking=No $BASTION_HOST_CONNECTION_STRING << EOF
    cd $DEPLOY_PATH
    scp -o StrictHostKeyChecking=No admin@$CLUSTER_IP:/etc/ansible_inventory .
    ansible-playbook -i ansible_inventory --extra-vars "ansible_sudo_pass=$CLUSTER_ADMIN_USER_PASSWORD ci_job_token=$CI_JOB_TOKEN ci_registry=$CI_REGISTRY resource_prefix=$RESOURCE_PREFIX stack_hostname=$STACK_HOSTNAME stage=$STAGE aws_access_key=$AWS_ACCESS_KEY aws_secret_key=$AWS_SECRET_KEY compose_file=$COMPOSE_FILE" playbook.yml
EOF

ssh -i keys/id_rsa -o StrictHostKeyChecking=No $BASTION_HOST_CONNECTION_STRING "rm -rf DEPLOY_PATH"

echo Stack deployed to https://$STACK_HOSTNAME