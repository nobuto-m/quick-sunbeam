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

    # TODO: doc needs to be updated to clarify this requirement
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



for i in {1..3}; do
    uvt-kvm wait "mc-$i"
    uvt-kvm ssh "mc-$i" -- -t '
        # https://github.com/canonical/microcloud/issues/68
        sudo snap refresh snapd --edge
        # https://github.com/canonical/microcloud/issues/90
        sudo snap refresh lxd --edge
        sudo snap install microovn --edge
        sudo snap install microceph --edge
        sudo snap install microcloud --edge

        # https://github.com/canonical/microcloud/issues/89
        # may require netplan conf changes to survive after a reboot
        sudo ip link set enp7s0 up
    '
done


uvt-kvm ssh mc-1
