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


## Prep

1. Prepare a jammy or noble host

1. Clone the repository

   ```bash
   git clone https://github.com/nobuto-m/quick-sunbeam -b act
   cd quick-sunbeam/
   ```

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
cd quick-sunbeam/

make single-node-guided
```
