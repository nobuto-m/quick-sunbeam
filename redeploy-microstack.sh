#!/bin/bash

set -eux

cd "$(dirname "$0")"

## clean up
for i in {1..3}; do
    # FIXME: the requirement of FQDN is not documented well in each tutorial
    uvt-kvm destroy "sunbeam-${i}.localdomain" || true
done

function ssh_to() {
    local ip="10.0.123.1${1}"
    shift
    ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu "${ip}" "$@"
}

for i in {1..3}; do
    cat <<EOF | uvt-kvm create \
        --machine-type q35 \
        --cpu 16 \
        --host-passthrough \
        --memory 16384 \
        --disk 64 \
        --ephemeral-disk 16 \
        --ephemeral-disk 16 \
        --unsafe-caching \
        --network-config /dev/stdin \
        --no-start \
        "sunbeam-${i}.localdomain" \
        release=jammy
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      accept-ra: false
      addresses:
        - 10.0.123.1${i}/24
      routes:
        - to: default
          via: 10.0.123.1
      nameservers:
        addresses:
          - 10.0.123.1
EOF
done


for i in {1..3}; do
    virsh detach-interface "sunbeam-${i}.localdomain" network --config

    virsh attach-interface "sunbeam-${i}.localdomain" network virbr-sunbeam \
        --model virtio --config
    virsh attach-interface "sunbeam-${i}.localdomain" network virbr-sunbeam \
        --model virtio --config

    virsh start "sunbeam-${i}.localdomain"
done


for i in {1..3}; do
    until ssh_to "${i}" -t -- cloud-init status --wait; do
        sleep 5
    done

    ssh_to "${i}" -t -- sudo snap install openstack --channel 2024.1/edge
    ssh_to "${i}" -t -- 'sunbeam prepare-node-script | bash -x'

    # LP: #2065911
    # TODO: make it permanent across reboots
    ssh_to "${i}" -- sudo ip link set enp9s0 up
done

ssh_to 1 -t -- \
    time sunbeam cluster bootstrap --accept-defaults

# LP: #2065490
ssh_to 1 -- 'juju model-default --cloud sunbeam-microk8s logging-config="<root>=INFO;unit=DEBUG"'
ssh_to 1 -- 'juju model-config -m openstack logging-config="<root>=INFO;unit=DEBUG"'

ssh_to 1 -t -- \
    time sunbeam configure --accept-defaults --openrc demo-openrc

ssh_to 1 -t -- \
    'time sunbeam openrc > admin-openrc'

ssh_to 1 -t -- \
    time sunbeam launch ubuntu --name test
