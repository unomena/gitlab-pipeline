#! /bin/sh -

# Exit on any failures
set -e

pip install bandit

bandit -t B105 -r .