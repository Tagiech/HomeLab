#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <app-name> <app-type>"
  exit 1
fi

APPNAME=$1
APPTYPE=$2

helm upgrade --install "$APPNAME" \
  ./charts/"$APPTYPE" \
  -f globalvalues.yaml \
  -f appvalues/"$APPTYPE"/"$APPNAME"/values.yaml \
  -n "$APPTYPE"