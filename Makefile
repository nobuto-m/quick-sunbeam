.PHONY: default
default:
	@echo 'No default target'

.PHONY: prerequisites
prerequisites:
	@echo prerequisites

.PHONY: single-node-guided
single-node-guided:
	/usr/bin/time -f 'real\t%E' act \
		-P ubuntu-latest=-self-hosted \
		-P ubuntu-24.04=-self-hosted \
		--artifact-server-path .artifacts \
		-W .github/workflows/single-node-guided.yml

.PHONY: multi-node
multi-node:
	/usr/bin/time -f 'real\t%E' act \
		-P ubuntu-latest=-self-hosted \
		-P ubuntu-24.04=-self-hosted \
		--artifact-server-path .artifacts \
		-W .github/workflows/multi-node.yml

.PHONY: multi-node-ha
multi-node-ha:
	/usr/bin/time -f 'real\t%E' act \
		-P ubuntu-latest=-self-hosted \
		-P ubuntu-24.04=-self-hosted \
		--artifact-server-path .artifacts \
		-W .github/workflows/multi-node-ha.yml

.PHONY: destroy-all-sunbeam-machines
destroy-all-sunbeam-machines:
	@echo 'Review the list of machines and pass it to bash. e.g.' >&2
	@echo 'make destroy-all-sunbeam-machines | bash -x' >&2
	@echo >&2
	@uvt-kvm list | grep ^sunbeam- | xargs --no-run-if-empty -L1 echo uvt-kvm destroy
