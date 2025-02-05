## Time

~173 min total

- `prepare-node-script --bootstrap` + 2x `sunbeam prepare-node-script` 7m16.604s
- `sunbeam cluster bootstrap` 25m49.372s
- `sunbeam cluster join` 22m18.170s
- `sunbeam cluster join` 22m10.131s
- `sunbeam cluster resize` 74m53.682s
- `sunbeam configure` 3m2.064s

## Prep

1. Prepare a jammy or noble host

1. Install prerequisites

    sudo apt-get update
    sudo apt-get install -y uvtool

1. Download a noble VM image

    uvt-simplestreams-libvirt sync release=noble arch=amd64
    uvt-simplestreams-libvirt query

1. Generate a SSH key if not any

    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ''

1. Define a new bridge.

```
virsh net-define /dev/stdin <<EOF
<network>
  <name>sunbeam-virbr0</name>
  <bridge name='sunbeam-virbr0' stp='off'/>
  <forward mode='nat'/>
  <ip address='192.168.124.1' netmask='255.255.255.0' />
</network>
EOF
virsh net-autostart sunbeam-virbr0
virsh net-start sunbeam-virbr0
```
