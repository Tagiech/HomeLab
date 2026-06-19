#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <app-name> <app-type>"
  exit 1
fi

APPNAME=$1
APPTYPE=$2
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

helm upgrade --install "$APPNAME" \
  "$SCRIPT_DIR/charts/$APPTYPE" \
  -f "$SCRIPT_DIR/globalvalues.yaml" \
  -f "$SCRIPT_DIR/appvalues/$APPTYPE/$APPNAME/values.yaml" \
  -n "$APPTYPE" --create-namespace
