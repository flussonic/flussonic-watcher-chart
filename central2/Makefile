
all:
	docker build -t central2:1 .
	docker save --output central2.tar central2:1
	multipass transfer central2.tar watcher:/tmp/central2.tar
	multipass exec watcher -- sudo k3s ctr images import /tmp/central2.tar
	multipass exec watcher -- rm -f /tmp/central2.tar
	rm -f central2.tar

