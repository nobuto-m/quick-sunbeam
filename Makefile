.PHONY: default
default:
	@echo 'No default target'

.PHONY: prerequisites
prerequisites:
	# install make before make(?)
	if ip link show sunbeam-virbr0; then
		@echo 'Looks like the prerequisites are satisfied.'
		@exit 0
	fi

	mkdir -p ~/.local/bin/
	bash <(curl https://raw.githubusercontent.com/nektos/act/master/install.sh) -b ~/.local/bin
	bash <(curl https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash) latest ~/.local/bin

	sudo apt-get update
	sudo apt-get install -y uvtool j2cli shellcheck
	sudo -g libvirt uvt-simplestreams-libvirt sync release=noble arch=amd64
	sudo -g libvirt uvt-simplestreams-libvirt query

	echo n | ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N '' || true
	cat .github/assets/workflows/ssh_config | tee -a ~/.ssh/config

	sudo -g libvirt virsh -c qemu:///system net-define .github/assets/workflows/sunbeam-virbr0.xml
	sudo -g libvirt virsh -c qemu:///system net-autostart sunbeam-virbr0
	sudo -g libvirt virsh -c qemu:///system net-start sunbeam-virbr0

	@echo 'Please logout from the shell / SSH session and login again.'

.PHONY: single-node-guided
single-node-guided:
	/usr/bin/time -f 'Workflow total time:\t%E' act \
		-P self-hosted=-self-hosted \
		--artifact-server-path .artifacts/$(@)/$$(date -u -Isec) \
		-W .github/workflows/$(@).yml

.PHONY: multi-node
multi-node:
	/usr/bin/time -f 'Workflow total time:\t%E' act \
		-P self-hosted=-self-hosted \
		--artifact-server-path .artifacts/$(@)/$$(date -u -Isec) \
		-W .github/workflows/$(@).yml

.PHONY: multi-node-minimal-with-cpu-overcommit
multi-node-minimal-with-cpu-overcommit:
	/usr/bin/time -f 'Workflow total time:\t%E' act \
		-P self-hosted=-self-hosted \
		--artifact-server-path .artifacts/$(@)/$$(date -u -Isec) \
		-W .github/workflows/multi-node.yml \
		--input hardware_profile=minimal-with-cpu-overcommit # FIXME

.PHONY: multi-node-allowance
multi-node-allowance:
	/usr/bin/time -f 'Workflow total time:\t%E' act \
		-P self-hosted=-self-hosted \
		--artifact-server-path .artifacts/$(@)/$$(date -u -Isec) \
		-W .github/workflows/multi-node.yml \
		--input hardware_profile=allowance # FIXME

.PHONY: multi-node-ha
multi-node-ha:
	/usr/bin/time -f 'Workflow total time:\t%E' act \
		-P self-hosted=-self-hosted \
		--artifact-server-path .artifacts/$(@)/$$(date -u -Isec) \
		-W .github/workflows/$(@).yml

.PHONY: destroy-all-sunbeam-machines
destroy-all-sunbeam-machines:
	@echo 'Review the list of machines and pass it to bash. e.g.' >&2
	@echo 'make destroy-all-sunbeam-machines | bash -x' >&2
	@echo >&2
	@uvt-kvm list | grep ^sunbeam- | xargs --no-run-if-empty -L1 echo uvt-kvm destroy
