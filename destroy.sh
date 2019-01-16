#! /bin/sh -

# Exit on any failures
set -e

# Add ssh key with which to execute ansible playbook.
mkdir keys
cp /tmp/keys/GITLAB_USER_BASTION_HOST_SSH_PRIVATE_KEY keys/id_rsa
chmod 700 keys/id_rsa

# Fetch ansible playbook and config.
curl -s https://gitlab.unomena.net/unomenapublic/gitlab-pipeline/raw/master/destroy.yml -o destroy.yml
curl -s https://gitlab.unomena.net/unomenapublic/gitlab-pipeline/raw/master/ansible.cfg -o ansible.cfg

# Replace environment variables in playbook.
envsubst < destroy.yml > playbook.yml

# Sync deploy artifacts to unique deploy path on bastion host.
DEPLOY_PATH=deploy-$RANDOM-$RANDOM
rsync -avzhe "ssh -i keys/id_rsa -o StrictHostKeyChecking=No" --exclude='.git' --exclude='keys' . $BASTION_HOST_CONNECTION_STRING:~/$DEPLOY_PATH

# Fetch Ansible inventory from cluster and execute playbook on bastion host.
ssh -i keys/id_rsa -o StrictHostKeyChecking=No $BASTION_HOST_CONNECTION_STRING << EOF
    cd $DEPLOY_PATH
    scp -o StrictHostKeyChecking=No admin@$CLUSTER_IP:/etc/ansible_inventory .
    ansible-playbook -i ansible_inventory --extra-vars "ansible_sudo_pass=$CLUSTER_ADMIN_USER_PASSWORD ci_job_token=$CI_JOB_TOKEN ci_registry=$CI_REGISTRY resource_prefix=$RESOURCE_PREFIX stack_hostname=$STACK_HOSTNAME stage=$STAGE" playbook.yml
    cd ..
    rm -rf $DEPLOY_PATH
EOF

echo Stack serving https://$STACK_HOSTNAME destroyed.

# Fetch inventory from cluster
#scp -i keys/id_rsa -o StrictHostKeyChecking=No admin@$CLUSTER_IP:/etc/ansible_inventory .

# Set environment variables in playbook.
#envsubst < destroy.yml > playbook.yml

# Execute playbook.
#ansible-playbook -i ansible_inventory --extra-vars "ansible_sudo_pass=$CLUSTER_ADMIN_USER_PASSWORD ci_job_token=$CI_JOB_TOKEN ci_registry=$CI_REGISTRY resource_prefix=$RESOURCE_PREFIX stack_hostname=$STACK_HOSTNAME stage=$STAGE" playbook.yml