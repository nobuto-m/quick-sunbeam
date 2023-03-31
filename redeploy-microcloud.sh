#!/bin/bash

set -eux

## clean up
for i in {1..3}; do
    uvt-kvm destroy "mc-$i" || true
done



for i in {1..3}; do
    uvt-kvm create \
        --cpu 4 --memory 8192 \
        --disk 16 \
        --host-passthrough \
        "mc-$i" \
        release=jammy
done

for i in {1..3}; do
    uvt-kvm wait "mc-$i"
    virsh shutdown "mc-$i"

    sleep 5

    virsh attach-interface "mc-$i" network default \
        --model virtio --config

    virsh vol-create-as uvtool --format qcow2 \
        "mc-${i}-sata1.qcow" 34359738368

    virsh vol-create-as uvtool --format qcow2 \
        "mc-${i}-sata2.qcow" 34359738368

    virsh vol-create-as uvtool --format qcow2 \
        "mc-${i}-virtio1.qcow" 34359738368

    virsh vol-create-as uvtool --format qcow2 \
        "mc-${i}-virtio2.qcow" 34359738368


    virsh attach-disk "mc-$i" \
        "/var/lib/uvtool/libvirt/images/mc-${i}-sata1.qcow" \
        sda \
        --subdriver qcow2 --targetbus sata --config

    virsh attach-disk "mc-$i" \
        "/var/lib/uvtool/libvirt/images/mc-${i}-sata2.qcow" \
        sdb \
        --subdriver qcow2 --targetbus sata --config

    virsh attach-disk "mc-$i" \
        "/var/lib/uvtool/libvirt/images/mc-${i}-virtio1.qcow" \
        vdc \
        --subdriver qcow2 --targetbus virtio --config

    virsh attach-disk "mc-$i" \
        "/var/lib/uvtool/libvirt/images/mc-${i}-virtio2.qcow" \
        vdd \
        --subdriver qcow2 --targetbus virtio --config

    virsh start "mc-$i"
done



# https://github.com/canonical/microcloud/issues/68
for i in {1..3}; do
    uvt-kvm wait "mc-$i"
    uvt-kvm ssh "mc-$i" -- -t '
        sudo snap refresh snapd --edge
        sudo snap refresh lxd --stable
        sudo snap install microovn --edge
        sudo snap install microceph --edge
        sudo snap install microcloud --edge
    '
done


uvt-kvm ssh mc-1
