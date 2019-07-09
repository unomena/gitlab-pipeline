#! /bin/sh -

# Exit on any failures
set -e

# When a job is triggered enforce that it does not continue with an old tag.
# This is done to prevent older tags being pushed as part of a batch from proceeding
# with its pipeline.
if [ "$CI_JOB_MANUAL" != "true" ]
then
    LATEST_TAG="$(git ls-remote --tags --quiet | awk '{split($0,a,"tags/"); print a[2]}' | sort --version-sort | grep -e "^[0-9]" | tail -1)"
    if [ "$CI_COMMIT_TAG" != "$LATEST_TAG" ]
    then
        echo "Exiting job triggered for old tag $CI_COMMIT_TAG, latest tag is $LATEST_TAG."
        exit 1
    fi
fi