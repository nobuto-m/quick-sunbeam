## Prep

Limit the default DHCP range so we can use the remaining for OVN.

```
virsh net-update default delete \
    ip-dhcp-range \
    '<range start="192.168.122.2" end="192.168.122.254"/>' \
    --live --config


virsh net-update default add \
    ip-dhcp-range \
    '<range start="192.168.122.101" end="192.168.122.254"/>' \
    --live --config
```
