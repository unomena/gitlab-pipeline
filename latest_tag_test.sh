#! /bin/sh -

# Exit on any failures
set -e

if [ "$CI_JOB_TRIGGERED" == "true" ]
then
    LATEST_TAG="$(git describe --abbrev=0 --tags)"
    if [ "$CI_COMMIT_TAG" != "$LATEST_TAG" ]
    then
        exit 1
    fi
fi