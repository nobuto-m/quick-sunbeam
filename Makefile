.PHONY: default
default:
	@echo 'No default target'

.PHONY: single-node-guided
single-node-guided:
	/usr/bin/time -f 'real\t%E' act -P ubuntu-24.04=-self-hosted \
		--artifact-server-path .artifacts \
		-W .github/workflows/single-node-guided.yml

.PHONY: multi-node
multi-node:
	/usr/bin/time -f 'real\t%E' act -P ubuntu-24.04=-self-hosted \
		--artifact-server-path .artifacts \
		-W .github/workflows/multi-node.yml

.PHONY: destroy-all-sunbeam-machines
destroy-all-sunbeam-machines:
	@echo Run the following commands: >&2
	@uvt-kvm list | grep ^sunbeam- | xargs -t --no-run-if-empty -L1 echo uvt-kvm destroy
