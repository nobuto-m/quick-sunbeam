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

    uvt-kvm ssh "sunbeam-${i}.localdomain" -- -t sudo snap install openstack --channel 2024.1/edge
    uvt-kvm ssh "sunbeam-${i}.localdomain" -- 'sunbeam prepare-node-script | bash -x'

done

uvt-kvm ssh sunbeam-1.localdomain -- tee deployment_manifest.yaml < manifest.yaml
#uvt-kvm ssh sunbeam-1.localdomain -- 'tail -n+2 /snap/openstack/current/etc/manifests/edge.yml >> deployment_manifest.yaml'

uvt-kvm ssh sunbeam-1.localdomain -- -t \
    time sunbeam cluster bootstrap --manifest deployment_manifest.yaml \
        --role control

# LP: #2065490
uvt-kvm ssh sunbeam-1.localdomain -- 'juju model-default --cloud sunbeam-microk8s logging-config="<root>=INFO;unit=DEBUG"'
uvt-kvm ssh sunbeam-1.localdomain -- 'juju model-config -m openstack logging-config="<root>=INFO;unit=DEBUG"'

# LP: #2065700
# TODO: add compute and storage after having a working Calico IP address
# or after disabling Calico VXLAN

#uvt-kvm ssh sunbeam-2.localdomain -- -t \
#    time sunbeam cluster join --role control \
#        --token "$(uvt-kvm ssh sunbeam-1.localdomain -- sunbeam cluster add --name sunbeam-2.localdomain -f value)"
#
#uvt-kvm ssh sunbeam-3.localdomain -- -t \
#    time sunbeam cluster join --role control \
#        --token "$(uvt-kvm ssh sunbeam-1.localdomain -- sunbeam cluster add --name sunbeam-3.localdomain -f value)"

#uvt-kvm ssh sunbeam-1.localdomain -- -t \
#    time sunbeam cluster resize
