#!/bin/bash

set -e
set -u
set -x

echo '## Recent runs'

gh workflow list --json name --jq .[].name | while read -r workflow; do
    echo "### $workflow"
    gh run list --limit 10 --status completed --workflow "$workflow"
done
