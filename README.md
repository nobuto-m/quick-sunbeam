## Disclaimer

Don't run this on a production system. It assumes a freshly installed
system like a ephemeral test env provisioned by MAAS.

## IP address allocation

Subnet: 192.168.124.0/24 (SNAT, no DHCP)

.1 - gateway (the host)

.6 - HTTP Proxy (the host)

.21 - sunbeam-single-node-guided

.31 - sunbeam-multi-node-1
.32 - sunbeam-multi-node-2
.33 - sunbeam-multi-node-3

.41 - sunbeam-multi-node-ha-1
.42 - sunbeam-multi-node-ha-2
.43 - sunbeam-multi-node-ha-3

.121-.130 - k8s lb range: single-node-guided
.131-.140 - k8s lb range: multi-node
.141-.150 - k8s lb range: multi-node-ha

.221-.230 - flat network range: single-node-guided
.231-.240 - flat network range: multi-node
.241-.250 - flat network range: multi-node-ha


## Time

### Single-node Guided

~59 min total including the smoke reboot testing.

### Multi-node

~173 min total

- `prepare-node-script --bootstrap` + 2x `sunbeam prepare-node-script` 7m16.604s
- `sunbeam cluster bootstrap` 25m49.372s
- `sunbeam cluster join` 22m18.170s
- `sunbeam cluster join` 22m10.131s
- `sunbeam cluster resize` 74m53.682s
- `sunbeam configure` 3m2.064s

## Install Act

https://nektosact.com/installation/index.html#pre-built-artifacts

and Node.js, e.g.

```
sudo snap install --classic node
```

Install actionlint too.

https://github.com/rhysd/actionlint/blob/main/docs/install.md#download-script


## Run

e.g.
```
make single-node-guided
```

## Prep

1. Prepare a jammy or noble host

1. Install prerequisites

   ```bash
   sudo apt-get update
   sudo apt-get install -y uvtool pv
   ```

1. Re-login or re-open an SSH session to be in the libvirt group

1. Download a noble VM image

   ```bash
   uvt-simplestreams-libvirt sync release=noble arch=amd64
   uvt-simplestreams-libvirt query
   ```

1. Generate a SSH key if not any

   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ''
   ```

1. Define a new bridge.

   ```bash
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

## Run

1. Clone

   ```bash
   git clone https://github.com/nobuto-m/quick-microstack
   cd quick-microstack/
   ```

2. Run

   ```bash
   time ./redeploy-microstack.sh
   ```
