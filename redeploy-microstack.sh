#!/bin/bash

set -e
# pv command doesn't pass through the exit code
set -o pipefail

echo 'Not used and to be migrated to GitHub workflow.'
exit 1

cd "$(dirname "$0")"

# be nice to my SSD
ssh_to 1 -- 'juju models --format json | jq -r ".models[].name" | xargs -t -I{} juju model-config -m {} logging-config="<root>=INFO"'

if [ "$USE_WORKAROUND" = true ]; then
    echo 'WARNING: Not a clean run. Some workarounds are used.'
fi
