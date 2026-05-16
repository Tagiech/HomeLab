#!/bin/bash
set -e

TAG=$1

if [ -z "$TAG" ]; then
  echo "Error: TAG parameter is required"
  echo "Usage: $0 <tag>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname $0)" && pwd)"
cd "$SCRIPT_DIR"

echo "Stopping old container"
docker compose down

echo "Cleaning old images"
docker images "ghcr.io/tagiech/vk-photos-extractor*" -q | xargs -r docker image rm -f || true

echo "Pulling new image"
TAG=${TAG} docker compose pull

echo "Starting new container"
TAG=${TAG} docker compose up -d

echo "Done"
