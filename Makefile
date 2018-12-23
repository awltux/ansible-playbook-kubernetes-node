.PHONY: list
list:
	cat Makefile | grep "^[A-z]" | awk '{print $$1}' | sed "s/://g"

vagrant-up:
	# Does VirtualBox exist
	# On Windows install gnuwin32 version of make
	# http://gnuwin32.sourceforge.net/packages/make.htm
	vagrant up

vagrant-ssh:
	# Does VirtualBox exist
	# On Windows install gnuwin32 version of make
	# http://gnuwin32.sourceforge.net/packages/make.htm
	vagrant ssh devops

# Destroy kubernetes cluster but preserve the data nodes
vagrant-destroy-cluster:
	for i in `vagrant global-status | grep virtualbox | grep -v ' devops ' | grep -v ' zfs-storage ' | awk '{ print $$1 }'` ; do vagrant destroy -f $$i ; done

vagrant-destroy-devops:
	vagrant destroy -f devops

vagrant-destroy-all:
	for i in `vagrant global-status | grep virtualbox | awk '{ print $$1 }'` ; do vagrant destroy -f $$i ; done

vagrant-reload:
	vagrant reload --provision devops

vagrant-reload-all:
	vagrant reload --provision

molecule-test:
	molecule test

molecule-login:
	docker run -it --rm \
		-v `pwd`:/vagrant \
		centos:7.5.1804 \
		/bin/bash
