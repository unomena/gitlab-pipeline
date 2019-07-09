#! /bin/sh -

# Exit on any failures
set -e

# When a job is triggered enforce that it does not continue with an old tag.
# This is done to prevent older tags being pushed as part of a batch from proceeding
# with its pipeline.
if [ "$CI_JOB_MANUAL" != "true" ]
then
    LATEST_TAG="$(git ls-remote --tags --quiet | tail -1 | awk '{split($0,a,"/"); print a[3]}')"
    if [ "$CI_COMMIT_TAG" != "$LATEST_TAG" ]
    then
        echo "Exiting job triggered for old tag $CI_COMMIT_TAG, latest tag is $LATEST_TAG."
        exit 1
    fi
fi