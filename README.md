## Time

~173 min total

- `prepare-node-script --bootstrap` + 2x `sunbeam prepare-node-script` 7m16.604s
- `sunbeam cluster bootstrap` 25m49.372s
- `sunbeam cluster join` 22m18.170s
- `sunbeam cluster join` 22m10.131s
- `sunbeam cluster resize` 74m53.682s
- `sunbeam configure` 3m2.064s

## Prep

Define a new bridge.

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
