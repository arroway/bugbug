#!/bin/bash
set -euox pipefail

# Script that run the whole data pipeline the fastest possible to validate
# that every part is working with the others

# Supposed to be run from the repository root directory

cd http_service/models/;

# Remove the model
rm defectenhancementtaskmodel* || true;
rm backout* || true;

# First retrieve a subset of bugs data
# TODO: Let the script download the previous DB as it should be pretty fast?
bugbug-data-bugzilla --limit 100

# Then retrieve a subset of commit data
mkdir -p cache
bugbug-data-commits --limit 100 cache

# Then train a bug model
bugbug-train --limit 500 --no-download defectenhancementtask

# Then train a commit model
bugbug-train --limit 30000 --no-download backout

# Then build docker images
cd ../..;
docker-compose build --pull bugbug-base

cd http_service/models;
docker-compose build --build-arg CHECK_MODELS=0

# Start the docker containers
env BUGBUG_ALLOW_MISSING_MODELS=1 docker-compose up -d --force-recreate

# Ensure we take down the containers at the end
trap "docker-compose logs && docker-compose down" EXIT

# Then check that we can correctly classify a bug
sleep 5 && python ../tests/test_integration.py