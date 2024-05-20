#!/bin/bash

set -eux

cd "$(dirname "$0")"

## clean up
for i in {1..3}; do
    # FIXME: the requirement of FQDN is not documented well in each tutorial
    uvt-kvm destroy "sunbeam-${i}.localdomain" || true
done


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
        --password ubuntu \
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
    uvt-kvm wait "sunbeam-${i}.localdomain"

    uvt-kvm ssh "sunbeam-${i}.localdomain" -- -t sudo snap install openstack --channel 2024.1/edge
    uvt-kvm ssh "sunbeam-${i}.localdomain" -- 'sunbeam prepare-node-script | bash -x'

    # LP: #2065911
    # TODO: make it permanent across reboots
    uvt-kvm ssh "sunbeam-${i}.localdomain" -- sudo ip link set enp9s0 up
done

uvt-kvm ssh sunbeam-1.localdomain -- tee deployment_manifest.yaml < manifest.yaml
uvt-kvm ssh sunbeam-1.localdomain -- 'tail -n+2 /snap/openstack/current/etc/manifests/edge.yml >> deployment_manifest.yaml'

uvt-kvm ssh sunbeam-1.localdomain -- -t \
    time sunbeam cluster bootstrap --manifest deployment_manifest.yaml \
        --role control --role compute --role storage

# LP: #2065490
uvt-kvm ssh sunbeam-1.localdomain -- 'juju model-default --cloud sunbeam-microk8s logging-config="<root>=INFO;unit=DEBUG"'
uvt-kvm ssh sunbeam-1.localdomain -- 'juju model-config -m openstack logging-config="<root>=INFO;unit=DEBUG"'

uvt-kvm ssh sunbeam-2.localdomain -- -t \
    time sunbeam cluster join --role control --role compute --role storage \
        --token "$(uvt-kvm ssh sunbeam-1.localdomain -- sunbeam cluster add --name sunbeam-2.localdomain -f value)"

uvt-kvm ssh sunbeam-3.localdomain -- -t \
    time sunbeam cluster join --role control --role compute --role storage \
        --token "$(uvt-kvm ssh sunbeam-1.localdomain -- sunbeam cluster add --name sunbeam-3.localdomain -f value)"

uvt-kvm ssh sunbeam-1.localdomain -- -t \
    time sunbeam cluster resize

uvt-kvm ssh sunbeam-1.localdomain -- -t \
    time sunbeam configure --openrc demo-openrc --manifest deployment_manifest.yaml

uvt-kvm ssh sunbeam-1.localdomain -- -t \
    'time sunbeam openrc > admin-openrc'

uvt-kvm ssh sunbeam-1.localdomain -- -t \
    time sunbeam launch ubuntu --name test
