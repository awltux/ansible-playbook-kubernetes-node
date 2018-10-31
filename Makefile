vagrant-up:
	# Does VirtualBox exist
	# On Windows install gnuwin32 version of make
	# http://gnuwin32.sourceforge.net/packages/make.htm
	vagrant up

vagrant-destroy-all:
	for i in `vagrant global-status | grep virtualbox | awk '{ print $$1 }'` ; do vagrant destroy -f $$i ; done

vagrant-destroy-k8s:
	# preserve the devops server and it's squid cache
	for i in `vagrant global-status | grep virtualbox | grep -v ' devops ' | awk '{ print $$1 }'` ; do vagrant destroy -f $$i ; done
