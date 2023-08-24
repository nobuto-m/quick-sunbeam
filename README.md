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

Define 3 additional isolated networks.

```
for i in {1..3}; do

    cat <<EOF | virsh net-define /dev/stdin
<network>
  <name>isolated-$i</name>
  <domain name="network"/>
  <ip address="192.168.10${i}.1" netmask="255.255.255.0">
    <dhcp>
      <range start="192.168.10${i}.101" end="192.168.10${i}.254"/>
    </dhcp>
  </ip>
</network>
EOF

    virsh net-autostart isolated-$i
    virsh net-start     isolated-$i

done
```
