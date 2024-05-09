#!/bin/bash

set -eux

## clean up
for i in {1..3}; do
    uvt-kvm destroy "sunbeam-$i" || true
done


for i in {1..3}; do
    uvt-kvm create \
        --machine-type q35 \
        --cpu 4 --memory 8192 \
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
    uvt-kvm ssh "sunbeam-$i" -- true
done


ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu "$(uvt-kvm ip sunbeam-1)"
