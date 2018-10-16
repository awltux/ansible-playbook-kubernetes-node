# Create CentOS 7 hosts to support kubernetes cluster
# Windows pre-requisites:
#    - Tortoise Git
#    - VirtualBox
#    - make and make-dep from gnuwin32
#    - Vagrant 

nodeCount = 3
networkBaseAddrString = "192.168.77."
vboxVersion = "1809.01"

vboxImage = "centos/7"
devopsBaseAddr = 10
nodeBaseAddr = 20
nodeBaseName = "node-"
devopsBaseName = "devops"

sshKeyName = "vagrant"

ssh_prv_key = ""
# User running vagrant has to have keys available
if File.file?("#{Dir.home}/.ssh/#{sshKeyName}")
	ssh_prv_key = File.read("#{Dir.home}/.ssh/#{sshKeyName}")
else
	puts "No SSH key found: #{Dir.home}/.ssh/#{sshKeyName}"
	puts "You will need to remedy this before running this Vagrantfile."
	exit 1
end

$setup_hosts = <<-HEREDOC
#!/bin/bash

set -e

if ! grep -q "devops" /etc/hosts; then
  echo "#{networkBaseAddrString}#{devopsBaseAddr} devops" >> /etc/hosts
fi

for index in {0..#{nodeCount - 1}}; do
  if ! grep -q "node-${index}" /etc/hosts; then
    echo "#{networkBaseAddrString}$(( #{nodeBaseAddr} + ${index} )) node-${index}" >> /etc/hosts
  fi
done

HEREDOC

$ansible_playbook = <<-HEREDOC
set -e
yum install -y ansible git

pushd /vagrant/ansible

cat > inventory <<BASH_HEREDOC
[provisioner]
devops

[all:children]
provisioner
all_nodes

[all_nodes:children]
master_nodes
worker_nodes

[master_nodes]
node-0

[worker_nodes]
BASH_HEREDOC

for index in {1..#{nodeCount - 1}}; do
	echo "node-${index}" >> inventory
done

chown -R vagrant:vagrant inventory

# Initialise the ansible role git clones
# only vagrant user has public-keys setup
sudo -u vagrant ansible-playbook --inventory=inventory playbook-init.yml

# BEWARE: This will override kubernetes_kubelet_extra_args defined in ansible files.
# kubeadm fails to start kubectl if swap enabled on master; but swap required for small memory machines in vagrant environment  
sudo -u vagrant ansible-playbook --inventory=inventory --extra-vars "kubernetes_kubelet_extra_args='--fail-swap-on=false'" playbook-apply.yml 

popd
HEREDOC

$setup_ssh_keys = <<-HEREDOC
    # Copy the current users vagrant key (ssh_prv_key) into each box an set it as an authorised user
    set -e

	sshDir="/home/vagrant/.ssh"
	tmpPrivateKey=${sshDir}/vagrant
	rsaPrivateKey=${sshDir}/id_rsa
	rsaPublicKey=${sshDir}/id_rsa.pub
	authorizedKeys=${sshDir}/authorized_keys
	
    echo "Provisioning SSH keys"
	
    mkdir -p ${sshDir}

    echo "#{ssh_prv_key}" > ${tmpPrivateKey}
    chmod 600 ${tmpPrivateKey}
    ssh_pub_key=`ssh-keygen -y -f ${tmpPrivateKey}`

    if grep -sq "${ssh_pub_key}" ${authorizedKeys}; then
      echo "SSH keys already provisioned."
      exit 0;
    fi
    mv -f  ${tmpPrivateKey} ${rsaPrivateKey}
    chmod 600 ${rsaPrivateKey}
	
	echo "${ssh_pub_key}" > ${rsaPublicKey}
    chmod 644 ${rsaPublicKey}

    touch ${authorizedKeys}
    echo "${ssh_pub_key}" >> ${authorizedKeys}
    chmod 600 ${authorizedKeys}

	# Running as root, so switch created files to vagrant user
    chown -R vagrant:vagrant /home/vagrant
HEREDOC

Vagrant.configure("2") do |config|
    # always use Vagrants insecure key
	config.ssh.insert_key = false
	# forward ssh agent to easily ssh into the different machines
	config.ssh.forward_agent = true
	check_guest_additions = false
	functional_vboxsf = false
    # BOX VERSION FROM HERE: https://app.vagrantup.com/centos/boxes/7
	config.vm.box = vboxImage
    config.vm.box_version = vboxVersion
	(0..nodeCount-1).each do |nodeIndex|
      	config.vm.define "#{nodeBaseName}#{nodeIndex}" do |machine|
			machine.vm.network :private_network, ip: "#{networkBaseAddrString}#{nodeBaseAddr + nodeIndex}"
			machine.vm.hostname = "#{nodeBaseName}#{nodeIndex}"
			machine.vm.provider "virtualbox" do |vbox|
				vbox.name = "#{nodeBaseName}#{nodeIndex}"
			end
        	machine.vm.provision  "shell", inline: $setup_ssh_keys
        	machine.vm.provision  "shell", inline: $setup_hosts
		end
	end
	config.vm.define "#{devopsBaseName}" do |machine|
		machine.vm.network :private_network, ip: "#{networkBaseAddrString}#{devopsBaseAddr}"
		machine.vm.hostname = "#{devopsBaseName}"
		machine.vm.provider "virtualbox" do |vbox|
			vbox.name = "#{devopsBaseName}"
		end
    	machine.vm.provision  "shell", inline: $setup_ssh_keys
       	machine.vm.provision  "shell", inline: $setup_hosts
    	machine.vm.provision  "shell", inline: $ansible_playbook
	end
end
