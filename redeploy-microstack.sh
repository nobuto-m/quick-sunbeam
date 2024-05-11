#!/bin/bash

set -eux

cd "$(dirname "$0")"

## clean up
for i in {1..3}; do
    uvt-kvm destroy "sunbeam-$i" || true
done


for i in {1..3}; do
    uvt-kvm create \
        --machine-type q35 \
        --cpu 16 --memory 16384 \
        --disk 64 \
        --ephemeral-disk 16 \
        --host-passthrough \
        --no-start \
        "sunbeam-$i" \
        release=jammy
done


for i in {1..3}; do
    virsh attach-interface "sunbeam-$i" network default \
        --model virtio --config

    virsh start "sunbeam-$i"
done


for i in {1..3}; do
    uvt-kvm wait "sunbeam-$i"
done

uvt-kvm ssh sunbeam-1 -- tee deployment_manifest.yaml < manifest.yaml
uvt-kvm ssh sunbeam-1 -- sudo snap install openstack --channel 2024.1/edge
uvt-kvm ssh sunbeam-1 -- 'sunbeam prepare-node-script | bash -x'
uvt-kvm ssh sunbeam-1 -- sunbeam cluster bootstrap --manifest deployment_manifest.yaml --role control --role compute --role storage
