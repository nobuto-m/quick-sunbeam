[![Testflinger - Single-node How-to Guide](../../actions/workflows/testflinger-single-node.yml/badge.svg)](../../actions/workflows/testflinger-single-node.yml)  
[![Testflinger - Multi-node How-to Guide](../../actions/workflows/testflinger-multi-node.yml/badge.svg)](../../actions/workflows/testflinger-multi-node.yml)

## Disclaimer

Don't run this on a production system. It assumes a freshly installed
system like an ephemeral physical host environment provisioned by MAAS.

## Networking

The main NIC and the secondary NIC are connected to the same VLAN/subnet as follows.

### Subnet

The CIDR is hardcoded on purpose for simplicity.

`192.168.124.0/24`

- On untagged VLAN
- SNAT is enabled to access the internet
- No DHCP server is running

### IP address allocation

| 4th octet | purpose                                |
|-----------|----------------------------------------|
| .1        | Gateway, DNS (the host)                |
|           |                                        |
| .6        | HTTP Proxy (the host) TODO             |
|           |                                        |
| .21       | sunbeam-single-node                    |
|           |                                        |
| .31       | sunbeam-multi-node-1                   |
| .32       | sunbeam-multi-node-2                   |
| .33       | sunbeam-multi-node-3                   |
|           |                                        |
| .121-.130 | k8s LB range: single-node              |
| .131-.140 | k8s LB range: multi-node               |
|           |                                        |
| .151-.200 | flat network range: single-node, [LP #2098823](https://bugs.launchpad.net/snap-openstack/+bug/2098823) |
| .201-.250 | flat network range: multi-node,  [LP #2098823](https://bugs.launchpad.net/snap-openstack/+bug/2098823) |


## Prep

1. Prepare a jammy or noble host

1. Clone the repository

1. Install prerequisites

   ```bash
   sudo apt-get update
   sudo apt-get install -y make
   make prerequisites
   # make sure ~/.local/bin is in PATH
   source  ~/.profile
   ```

## Run

Use `act` command direcly or use an example in the Makefile, e.g.

```bash
make single-node
```
or
```bash
make multi-node
```


## Misc

### Single-node

~59 min total including the smoke reboot testing.

### Multi-node

~173 min total
