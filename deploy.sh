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
#curl -s https://gitlab.unomena.net/unomenapublic/gitlab-pipeline/raw/master/deploy.yml -o deploy.yml
curl -s https://gitlab.unomena.net/unomenapublic/gitlab-pipeline/raw/master/deploy.yml -o deploy.yml
curl -s https://gitlab.unomena.net/unomenapublic/gitlab-pipeline/raw/master/templates/env -o templates/env
curl -s https://gitlab.unomena.net/unomenapublic/gitlab-pipeline/raw/master/templates/docker-compose.override.yml -o payload/templates/docker-compose.override.yml
curl -s https://gitlab.unomena.net/unomenapublic/gitlab-pipeline/raw/master/ansible.cfg -o ansible.cfg

# Replace environment variables in playbook.
envsubst < deploy.yml > payload/deploy.yml

# Replace environment variables in env template file.
envsubst < templates/env > payload/templates/env

# Add indicated compose file to payload.
cp $COMPOSE_FILE payload/

# Fetch Ansible inventory from cluster
scp -o StrictHostKeyChecking=No admin@$CLUSTER_IP:/etc/ansible_inventory payload/

# Execute Ansible playbook
cd payload
export ANSIBLE_FORCE_COLOR=1
ansible-playbook -i ansible_inventory --extra-vars "ansible_sudo_pass=$CLUSTER_ADMIN_USER_PASSWORD ci_job_token=$CI_JOB_TOKEN ci_registry=$CI_REGISTRY resource_prefix=$RESOURCE_PREFIX stack_hostname=$STACK_HOSTNAME stage=$STAGE aws_access_key=$AWS_ACCESS_KEY aws_secret_key=$AWS_SECRET_KEY compose_file=$COMPOSE_FILE" deploy.yml

echo Deployed stack to https://$STACK_HOSTNAME

if [ $STAGE = "staging" ]  || [ $STAGE = "production" ]; then
	curl -X POST -H 'Content-type: application/json' --data '{"text":"'$PRODUCTION_STACK_HOSTNAME' `'$CI_COMMIT_REF_SLUG'` is on '$STAGE' `'$STACK_HOSTNAME'` "}' https://hooks.slack.com/services/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
fi
