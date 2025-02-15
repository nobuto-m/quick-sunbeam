#!/bin/bash

set -e
# pv command doesn't pass through the exit code
set -o pipefail

echo 'Not used and to be migrated to GitHub workflow.'
exit 1

cd "$(dirname "$0")"

# check pv at the earliest
hash pv

function ssh_to() {
    local ip="192.168.124.1${1}"
    shift
    ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu "${ip}" "$@"
}

time for i in {1..3}; do
    # LP: #2065911
    # TODO: make it permanent across reboots
    #ssh_to "${i}" -- sudo ip link set enp9s0 up
done

# LP: #2096923
if [ "$USE_WORKAROUND" = true ]; then
    ssh_to 1 -- '
        set -ex
        sudo ceph status
        sudo ceph health detail
        sudo ceph osd pool autoscale-status

        sudo ceph config set global osd_pool_default_pg_autoscale_mode warn
        sudo ceph osd pool ls | xargs -t -I{} sudo ceph osd pool set {} pg_autoscale_mode warn
        sudo ceph osd pool set glance pg_num 32
        sudo ceph osd pool set cinder-ceph pg_num 32

        sudo ceph status
        sudo ceph health detail
        sudo ceph osd pool autoscale-status
    '
fi

# LP: #2096923, LP: #2095570
ssh_to 1 -- '
    set -ex
    sudo ceph status
    sudo ceph health detail
    sudo ceph osd pool autoscale-status
'

for i in {1..3}; do
    ssh_to "${i}" -t -- \
        'time sunbeam openrc > admin-openrc'
done

# be nice to my SSD
ssh_to 1 -- 'juju models --format json | jq -r ".models[].name" | xargs -t -I{} juju model-config -m {} logging-config="<root>=INFO"'

if [ "$USE_WORKAROUND" = true ]; then
    echo 'WARNING: Not a clean run. Some workarounds are used.'
fi
