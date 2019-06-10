#! /bin/sh -

# Exit on any failures
set -e

if [ -e docker-compose-build.yml ]
then
    gpg --no-tty --import /tmp/keys/GITLAB_BLACKBOX_GPG_KEY
    blackbox_postdeploy
    rm -f .env docker-compose.override.yml
    docker login --username gitlab-ci-token --password $CI_JOB_TOKEN $CI_REGISTRY
    docker-compose --file docker-compose-build.yml config | python -c "import sys, yaml; print('\n'.join(['\n'.join(service['build'].get('cache_from', [])) for service in yaml.load(sys.stdin)['services'].values()]))" | xargs -I % docker pull % || true
    docker-compose --file docker-compose-build.yml build
    docker-compose --file docker-compose-build.yml push
else
    echo "No docker-compose-build.yml file found, nothing to build."
fi