## Prep

Define a new bridge with a subnet in the 10.0.0.0/16 range to avoid
[LP: #2065700](https://launchpad.net/bugs/2065700).

```
cat <<EOF | virsh net-define /dev/stdin
<network>
  <name>virbr-sunbeam</name>
  <bridge name='virbr-sunbeam' stp='off'/>
  <forward mode='nat'/>
  <ip address='10.0.123.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='10.0.123.101' end='10.0.123.254'/>
    </dhcp>
  </ip>
</network>
EOF
virsh net-autostart virbr-sunbeam
virsh net-start virbr-sunbeam
```
