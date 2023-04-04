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
        --no-start \
        "mc-$i" \
        release=jammy
done

for i in {1..3}; do
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
        sudo snap refresh --channel latest/edge     snapd
        sudo snap refresh --channel latest/stable   lxd
        sudo snap install --channel latest/edge     microovn
        sudo snap install --channel latest/edge     microceph
        sudo snap install --channel latest/edge     microcloud
    '
done

# https://github.com/canonical/microcloud/issues/89
netplan_override="\
network:
  version: 2
  ethernets:
    enp7s0:
      dhcp4: no
"

for i in {1..3}; do
    printf '%s' "$netplan_override" | uvt-kvm ssh "mc-$i" '
        sudo tee /etc/netplan/90-local-ovs-port.yaml
        sudo netplan apply
    '
done


uvt-kvm ssh mc-1
