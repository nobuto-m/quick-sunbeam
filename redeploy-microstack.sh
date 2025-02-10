#!/bin/bash

set -eux
# pv command doesn't pass through the exit code
set -o pipefail

cd "$(dirname "$0")"

# check pv at the earliest
hash pv

function ssh_to() {
    local ip="192.168.124.1${1}"
    shift
    ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu "${ip}" "$@"
}

USE_WORKAROUND=true
SPECS_PROFILE_DEFAULT=minimal-overcommit

specs_profile="$SPECS_PROFILE_DEFAULT"
if [ "$specs_profile" = minimal ]; then
    CPU=4
    MEMORY=16384
    DISK=128
    EXTRA_DISK=128
elif [ "$specs_profile" = minimal-overcommit ]; then
    CPU=16
    MEMORY=16384
    DISK=128
    EXTRA_DISK=128
elif [ "$specs_profile" = tutorial ]; then
    # https://canonical.com/microstack/docs/multi-node
    CPU=4
    MEMORY=32768
    DISK=200
    EXTRA_DISK=200
elif [ "$specs_profile" = allowance ]; then
    CPU=16
    MEMORY=65536
    DISK=512
    EXTRA_DISK=512
fi

for i in {1..3}; do
    # LP: #2095570
    if [ "$USE_WORKAROUND" = true ]; then
        virsh vol-create-as uvtool --format qcow2 \
            "sunbeam-machine-${i}-sata1.qcow" "$((EXTRA_DISK * 1024**3))"
        virsh attach-disk "sunbeam-machine-${i}.localdomain" \
            "/var/lib/uvtool/libvirt/images/sunbeam-machine-${i}-sata1.qcow" \
            sda --subdriver qcow2 --targetbus sata --config
    fi

done


time for i in {1..3}; do
    ssh_to "${i}" -t -- sudo snap install openstack --channel 2024.1/edge
    if [ "$i" = 1 ]; then
        ssh_to "${i}" -t -- 'sunbeam prepare-node-script --bootstrap | bash -x'
    else
        ssh_to "${i}" -t -- 'sunbeam prepare-node-script | bash -x'
    fi

    # LP: #2065911
    # TODO: make it permanent across reboots
    #ssh_to "${i}" -- sudo ip link set enp9s0 up
done

ssh_to 1 -- 'cat - > manifest.yaml' < manifest.yaml

ssh_to 1 -t -- \
    time sunbeam cluster bootstrap --manifest manifest.yaml \
        --role control,compute,storage | pv --timer -i 0.08

# LP: #2095487
if [ "$USE_WORKAROUND" = true ]; then
    ssh_to 1 -- \
        time juju destroy-controller localhost-localhost --no-prompt
fi

# LP: #2065490
#ssh_to 1 -- 'juju model-default --cloud "<petname>" logging-config="<root>=INFO;unit=DEBUG"'
ssh_to 1 -- 'juju model-config -m admin/openstack-machines logging-config="<root>=INFO;unit=DEBUG"'

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

ssh_to 2 -t -- \
    time sunbeam cluster join --role control,compute,storage \
        "$(ssh_to 1 -- sunbeam cluster add sunbeam-machine-2.localdomain -f value)" | pv --timer -i 0.08

ssh_to 3 -t -- \
    time sunbeam cluster join --role control,compute,storage \
        "$(ssh_to 1 -- sunbeam cluster add sunbeam-machine-3.localdomain -f value)" | pv --timer -i 0.08

# LP: #2065469
if [ "$USE_WORKAROUND" = true ]; then
    time (
        ssh_to 1 -t -- \
            sunbeam cluster resize | pv --timer -i 0.08 \
        || \
        ssh_to 1 -t -- \
            sunbeam cluster resize | pv --timer -i 0.08
    )
else
    time ssh_to 1 -t -- \
        sunbeam cluster resize | pv --timer -i 0.08
fi

# LP: #2096923, LP: #2095570
ssh_to 1 -- '
    set -ex
    sudo ceph status
    sudo ceph health detail
    sudo ceph osd pool autoscale-status
'

ssh_to 1 -t -- \
    time sunbeam configure --openrc demo-openrc

for i in {1..3}; do
    ssh_to "${i}" -t -- \
        'time sunbeam openrc > admin-openrc'
done

ssh_to 1 -t -- \
    time sunbeam launch ubuntu --name test

# shellcheck disable=SC2016
ssh_to 1 -- '
    set -ex
    # The cloud-init process inside the VM takes ~2 minutes to bring up the
    # SSH service after the VM gets ACTIVE in OpenStack
    sleep 300
    source demo-openrc
    demo_floating_ip="$(openstack floating ip list -c Floating\ IP\ Address -f value | head -n1)"
    ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -i ~/snap/openstack/current/sunbeam "ubuntu@${demo_floating_ip}" true
'

# be nice to my SSD
ssh_to 1 -- 'juju models --format json | jq -r ".models[].name" | xargs -t -I{} juju model-config -m {} logging-config="<root>=INFO"'

if [ "$USE_WORKAROUND" = true ]; then
    echo 'WARNING: Not a clean run. Some workarounds are used.'
fi
