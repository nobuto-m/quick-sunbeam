#!/bin/bash

set -eux
# pv command doesn't pass through the exit code
set -o pipefail

cd "$(dirname "$0")"

## clean up
for i in {1..3}; do
    # FIXME: the requirement of FQDN is not documented well in each tutorial
    uvt-kvm destroy "sunbeam-${i}.localdomain" || true
done

function ssh_to() {
    local ip="192.168.123.1${1}"
    shift
    ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu "${ip}" "$@"
}

for i in {1..3}; do
    cat <<EOF | uvt-kvm create \
        --machine-type q35 \
        --cpu 16 \
        --host-passthrough \
        --memory 16384 \
        --disk 128 \
        --ephemeral-disk 16 \
        --ephemeral-disk 16 \
        --unsafe-caching \
        --network-config /dev/stdin \
        --no-start \
        "sunbeam-${i}.localdomain" \
        release=noble
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      accept-ra: false
      addresses:
        - 192.168.123.1${i}/24
      routes:
        - to: default
          via: 192.168.123.1
      nameservers:
        addresses:
          - 192.168.123.1
EOF
done


for i in {1..3}; do
    virsh attach-interface "sunbeam-${i}.localdomain" network default \
        --model virtio --config

    virsh start "sunbeam-${i}.localdomain"
done


time for i in {1..3}; do
    until ssh_to "${i}" -t -- cloud-init status --wait --long; do
        # LP: #2095395
        [ "$?" = 2 ] && break
        sleep 5
    done

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

ssh_to 1 -- 'tee deployment_manifest.yaml' < manifest.yaml

ssh_to 1 -t -- \
    time sunbeam cluster bootstrap --manifest deployment_manifest.yaml \
        --role control,compute,storage | pv --timer -i 0.08

# LP: #2095487
ssh_to 1 -t -- \
    time juju destroy-controller localhost-localhost --no-prompt

# LP: #2065490
#ssh_to 1 -- 'juju model-default --cloud sunbeam-microk8s logging-config="<root>=INFO;unit=DEBUG"'
#ssh_to 1 -- 'juju model-config -m openstack logging-config="<root>=INFO;unit=DEBUG"'

ssh_to 2 -t -- \
    time sunbeam cluster join --role control,compute,storage \
        "$(ssh_to 1 -- sunbeam cluster add sunbeam-2.localdomain -f value)" | pv --timer -i 0.08

ssh_to 3 -t -- \
    time sunbeam cluster join --role control,compute,storage \
        "$(ssh_to 1 -- sunbeam cluster add sunbeam-3.localdomain -f value)" | pv --timer -i 0.08

# LP: #2095570
ssh_to 1 -t -- time juju run -m admin/openstack-machines microceph/1 add-osd device-id='/dev/disk/by-path/virtio-pci-0000:06:00.0'
ssh_to 1 -t -- time juju run -m admin/openstack-machines microceph/2 add-osd device-id='/dev/disk/by-path/virtio-pci-0000:06:00.0'

ssh_to 1 -t -- \
    time sunbeam cluster resize | pv --timer -i 0.08

ssh_to 1 -t -- \
    time sunbeam configure --openrc demo-openrc

for i in {1..3}; do
    ssh_to "${i}" -t -- \
        'time sunbeam openrc > admin-openrc'
done

ssh_to 1 -t -- \
    time sunbeam launch ubuntu --name test

# shellcheck disable=SC2016
ssh_to 1 -t -- '
    set -ex
    # The cloud-init process inside the VM takes ~2 minutes to bring up the
    # SSH service after the VM gets ACTIVE in OpenStack
    sleep 300
    source demo-openrc
    demo_floating_ip="$(openstack floating ip list -c Floating\ IP\ Address -f value | head -n1)"
    ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -i ~/snap/openstack/current/sunbeam "ubuntu@${demo_floating_ip}" true
'

# be nice to my SSD
ssh_to 1 -t -- juju model-config -m openstack update-status-hook-interval=2h
