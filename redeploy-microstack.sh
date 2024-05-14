#!/bin/bash

set -eux

cd "$(dirname "$0")"

## clean up
for i in {1..3}; do
    # FIXME: the requirement of FQDN is not documented well in each tutorial
    uvt-kvm destroy "sunbeam-${i}.localdomain" || true
done


for i in {1..3}; do
    uvt-kvm create \
        --machine-type q35 \
        --cpu 16 --memory 16384 \
        --disk 64 \
        --ephemeral-disk 16 \
        --ephemeral-disk 16 \
        --host-passthrough \
        --unsafe-caching \
        --no-start \
        "sunbeam-${i}.localdomain" \
        release=jammy
done


for i in {1..3}; do
    virsh attach-interface "sunbeam-${i}.localdomain" network default \
        --model virtio --config

    virsh start "sunbeam-${i}.localdomain"
done


for i in {1..3}; do
    uvt-kvm wait "sunbeam-${i}.localdomain"
done

uvt-kvm ssh sunbeam-1 -- -t sudo snap install openstack --channel 2024.1/edge
uvt-kvm ssh sunbeam-1 -- tee deployment_manifest.yaml < manifest.yaml
#uvt-kvm ssh sunbeam-1 -- 'tail -n+2 /snap/openstack/current/etc/manifests/edge.yml >> deployment_manifest.yaml'
uvt-kvm ssh sunbeam-1 -- 'sunbeam prepare-node-script | bash -x'
uvt-kvm ssh sunbeam-1 -- -t time sunbeam cluster bootstrap --manifest deployment_manifest.yaml --role control --role compute --role storage \
    || (juju model-default --cloud sunbeam-microk8s logging-config='<root>=INFO;unit=DEBUG'; juju model-config -m openstack logging-config='<root>=INFO;unit=DEBUG')  # LP: #2065490
