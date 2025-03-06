[![Single-node How-to Guide](../../actions/workflows/single-node.yml/badge.svg)](../../actions/workflows/single-node.yml)  
[![Multi-node How-to Guide](../../actions/workflows/multi-node.yml/badge.svg)](../../actions/workflows/multi-node.yml)

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
| .181-.220 | (additional range for Tempest plugin)  |
| .221-.230 | flat network range: single-node        |
| .231-.240 | flat network range: multi-node         |
| .241-.250 | (additional range for Tempest plugin)  |


## Prep

1. Prepare a jammy or noble host

1. Clone the repository

1. Install prerequisites

   ```bash
   sudo apt-get update
   sudo apt-get install -y make
   make prerequisites
   ```

1. Re-login or re-open an SSH session

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
