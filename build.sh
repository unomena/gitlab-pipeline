#! /bin/sh -

# Exit on any failures
set -e

# Apply transcrypt credentials on repo to decrypt encrypted files.
if [ -z "$TRANSCRYPT_PASSWORDA" ]
then
    echo "Skipping transcrypt: TRANSCRYPT_PASSWORD variable is not set."
else
    transcrypt --yes --cipher=aes-256-cbc --password="$TRANSCRYPT_PASSWORD"
fi

if [ -e docker-compose-build.yml ]
then
    rm -f .env docker-compose.override.yml
    docker login --username gitlab-ci-token --password $CI_JOB_TOKEN $CI_REGISTRY
    docker-compose --file docker-compose-build.yml config | python -c "import sys, yaml; print('\n'.join(['\n'.join(service['build'].get('cache_from', [])) for service in yaml.load(sys.stdin)['services'].values()]))" | xargs -I % docker pull % || true
    docker-compose --file docker-compose-build.yml build
    docker-compose --file docker-compose-build.yml push
else
    echo "No docker-compose-build.yml file found, nothing to build."
fi