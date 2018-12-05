#! /bin/sh -

if [ -e docker-compose-build.yml ]
then
    apk add --no-cache py-pip
    pip install docker-compose
    rm -f .env docker-compose.override.yml
    docker login --username gitlab-ci-token --password $CI_JOB_TOKEN $CI_REGISTRY
    docker-compose --file docker-compose-build.yml build --pull
    docker-compose --file docker-compose-build.yml push
fi