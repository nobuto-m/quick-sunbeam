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

#uvt-kvm ssh sunbeam-1.localdomain -- -t \
#    time sunbeam configure --openrc demo-openrc --manifest deployment_manifest.yaml

#Local or remote access to VMs [local/remote] (local): remote
#CIDR of network to use for external networking (10.20.20.0/24): 10.0.123.0/24
#IP address of default gateway for external network (10.0.123.1):
#Start of IP allocation range for external network (10.0.123.2): 10.0.123.51
#End of IP allocation range for external network (10.0.123.254): 10.0.123.80
#Network type for access to external network [flat/vlan] (flat):
#Populate OpenStack cloud with demo user, default images, flavors etc [y/n] (y):
#Username to use for access to OpenStack (demo):
#Password to use for access to OpenStack (qj********):
#Network range to use for project network (192.168.122.0/24): 192.168.1.0/24
#List of nameservers guests should use for DNS resolution (10.0.123.1):
#Enable ping and SSH access to instances? [y/n] (y):
