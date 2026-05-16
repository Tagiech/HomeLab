#!/bin/bash
set -e

docker exec -it nextcloud php occ maintenance:repair
docker exec -it nextcloud php occ upgrade
