#!/bin/bash
set -e

FILENAME="$1"
if [ ! -f "$FILENAME" ]; then
    echo "File not found!"
    exit 1
fi

sha256sum -c "$FILENAME"
