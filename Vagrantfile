# Create CentOS 7 hosts to support kubernetes cluster
# Windows pre-requisites:
#    - Tortoise Git
#    - VirtualBox
#    - make and make-dep from gnuwin32
#    - Vagrant 

natBaseAddrString = "192.168"
hostonlyBaseAddrString = "172.28.128"
vagrantNatAddr = "15"
routeEth1Path = "/etc/sysconfig/network-scripts/route-eth1"

sshBasePort = 2200
# One DevOps
devopsBaseAddr = 8
devopsBaseName = "devops"

zfsBaseAddr = 9
zfsBaseName = "zfs-storage"

# Up to 7 master_nodes
masterCount = 1
masterBaseAddr = 10
masterBaseName = "master-"

nodeCount = 2
nodeBaseAddr = 17
nodeBaseName = "node-"

sshKeyName = "vagrant"

# Valid providers are: virtualbox, libvirt, docker
# libvirt instructions: https://docs.cumulusnetworks.com/display/VX/Vagrant+and+Libvirt+with+KVM+or+QEMU
vm_provider="virtualbox"
# NOTE: These will need changed if using other providers 
vboxImage = "centos/7"
vboxVersion = "1809.01"

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
#!/bin/bash -eu

if [[ "$1" == "disable_swap" ]]; then
  # Kubernetes nodes don't like swap enabled.
  swapoff -a
  sed -i "s/^.* swap .*$//" /etc/fstab
fi

touch #{routeEth1Path}

routeCount=0
if ! grep -q "devops" /etc/hosts; then
  echo "#{natBaseAddrString}.#{devopsBaseAddr}.#{vagrantNatAddr} devops" >> /etc/hosts
fi
if ! ip route | grep "#{natBaseAddrString}.#{devopsBaseAddr}.0"; then
  ip route add #{natBaseAddrString}.#{devopsBaseAddr}.0/24 via #{hostonlyBaseAddrString}.#{devopsBaseAddr} dev eth1
  cat > #{routeEth1Path} <<INNER_HEREDOC
ADDRESS${routeCount}=#{natBaseAddrString}.#{devopsBaseAddr}.0
NETMASK${routeCount}=255.255.255.0
GATEWAY${routeCount}=#{hostonlyBaseAddrString}.#{devopsBaseAddr}
INNER_HEREDOC
fi

routeCount=1
if ! grep -q "zfs-storage" /etc/hosts; then
  echo "#{natBaseAddrString}.#{zfsBaseAddr}.#{vagrantNatAddr} zfs-storage" >> /etc/hosts
fi
if ! ip route | grep "#{natBaseAddrString}.#{zfsBaseAddr}.0"; then
  ip route add #{natBaseAddrString}.#{zfsBaseAddr}.0/24 via #{hostonlyBaseAddrString}.#{zfsBaseAddr} dev eth1
  cat > #{routeEth1Path} <<INNER_HEREDOC
ADDRESS${routeCount}=#{natBaseAddrString}.#{zfsBaseAddr}.0
NETMASK${routeCount}=255.255.255.0
GATEWAY${routeCount}=#{hostonlyBaseAddrString}.#{zfsBaseAddr}
INNER_HEREDOC
fi

routeCount=2
for index in {0..#{nodeCount - 1}}; do
  if ! grep -q "#{nodeBaseName}$(( #{nodeBaseAddr} + ${index} ))" /etc/hosts; then
    echo "#{natBaseAddrString}.$(( #{nodeBaseAddr} + ${index} )).#{vagrantNatAddr} #{nodeBaseName}$(( #{nodeBaseAddr} + ${index} ))" >> /etc/hosts
  fi
  if ! ip route | grep "#{natBaseAddrString}.$(( #{nodeBaseAddr} + index )).0"; then
    ip route add #{natBaseAddrString}.$(( #{nodeBaseAddr} + ${index} )).0/24 via #{hostonlyBaseAddrString}.$(( #{nodeBaseAddr} + ${index} )) dev eth1
	cat >> #{routeEth1Path} <<INNER_HEREDOC
ADDRESS$(( routeCount + index ))=#{natBaseAddrString}.$(( #{nodeBaseAddr} + ${index} )).0
NETMASK$(( routeCount + index ))=255.255.255.0
GATEWAY$(( routeCount + index ))=#{hostonlyBaseAddrString}.$(( #{nodeBaseAddr} + ${index} ))
INNER_HEREDOC
  fi
done

routeCount=#{nodeCount}
for index in {0..#{masterCount - 1}}; do
  if ! grep -q "#{masterBaseName}$(( #{masterBaseAddr} + ${index} ))" /etc/hosts; then
    echo "#{natBaseAddrString}.$(( #{masterBaseAddr} + ${index} )).#{vagrantNatAddr} #{masterBaseName}$(( #{masterBaseAddr} + ${index} ))" >> /etc/hosts
  fi
  if ! ip route | grep "#{natBaseAddrString}.$(( #{masterBaseAddr} + ${index} )).0"; then
    ip route add #{natBaseAddrString}.$(( #{masterBaseAddr} + ${index} )).0/24 via #{hostonlyBaseAddrString}.$(( #{masterBaseAddr} + ${index} )) dev eth1
	cat >> #{routeEth1Path} <<INNER_HEREDOC
ADDRESS$(( routeCount + index ))=#{natBaseAddrString}.$(( #{masterBaseAddr} + ${index} )).0
NETMASK$(( routeCount + index ))=255.255.255.0
GATEWAY$(( routeCount + index ))=#{hostonlyBaseAddrString}.$(( #{masterBaseAddr} + ${index} ))
INNER_HEREDOC
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

[storage]
zfs-storage

[all:children]
provisioner
all_nodes

[all_nodes:children]
master_nodes
worker_nodes

BASH_HEREDOC


echo "[master_nodes]" >> inventory
for index in {0..#{masterCount - 1}}; do
	echo "#{masterBaseName}$(( #{masterBaseAddr} + ${index} ))" >> inventory
done

echo >> inventory
echo "[worker_nodes]" >> inventory
for index in {0..#{nodeCount - 1}}; do
	echo "#{nodeBaseName}$(( #{nodeBaseAddr} + ${index} ))" >> inventory
done

chown -R vagrant:vagrant inventory

# Initialise the ansible role git clones
# only vagrant user has public-keys setup
sudo -u vagrant ansible-playbook --inventory=inventory playbook-init.yml

sudo -u vagrant ansible-playbook --inventory=inventory playbook-apply.yml 

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
	(0..masterCount-1).each do |masterIndex|
      	config.vm.define "#{masterBaseName}#{masterBaseAddr + masterIndex}" do |machine|
			machine.vm.hostname = "#{masterBaseName}#{masterBaseAddr + masterIndex}"
			machine.vm.network "private_network", ip: "#{hostonlyBaseAddrString}.#{masterBaseAddr + masterIndex}"
			machine.ssh.port = #{sshBasePort + masterBaseAddr + masterIndex}
			machine.vm.provider "#{vm_provider}" do |provider_vm|
				provider_vm.name = "#{masterBaseName}#{masterBaseAddr + masterIndex}"
				provider_vm.memory = 4096
				provider_vm.cpus = 2
				# Use the network address as a way of making a unique IP address on eth0; otherwise
				# vagrant would make all nodes 10.0.2.15 which confuses kubeadm
				provider_vm.customize ['modifyvm',:id, '--natnet1', "#{natBaseAddrString}.#{masterBaseAddr + masterIndex}.0/24"] 
			end
        	machine.vm.provision  "shell", inline: $setup_ssh_keys
        	machine.vm.provision  "shell" do |bash_shell|
			  bash_shell.inline = $setup_hosts
			  # Kubernetes nodes don't like swap enabled.
			  bash_shell.args = "disable_swap"
			end
		end
	end
	(0..nodeCount-1).each do |nodeIndex|
      	config.vm.define "#{nodeBaseName}#{nodeBaseAddr + nodeIndex}" do |machine|
			machine.vm.hostname = "#{nodeBaseName}#{nodeBaseAddr + nodeIndex}"
			machine.vm.network "private_network", ip: "#{hostonlyBaseAddrString}.#{nodeBaseAddr + nodeIndex}"
			machine.vm.provider "#{vm_provider}" do |provider_vm|
				provider_vm.name = "#{nodeBaseName}#{nodeBaseAddr + nodeIndex}"
				provider_vm.memory = 4096
				provider_vm.cpus = 2
				# Use the network address as a way of making a unique IP address on eth0; otherwise
				# vagrant would make all nodes 10.0.2.15 which confuses kubeadm
				provider_vm.customize ['modifyvm',:id, '--natnet1', "#{natBaseAddrString}.#{nodeBaseAddr + nodeIndex}.0/24"] 
			end
        	machine.vm.provision  "shell", inline: $setup_ssh_keys
        	machine.vm.provision  "shell" do |bash_shell|
			  bash_shell.inline = $setup_hosts
			  # Kubernetes nodes don't like swap enabled.
			  bash_shell.args = "disable_swap"
			end
		end
	end
	config.vm.define "#{zfsBaseName}" do |machine|
		machine.vm.hostname = "#{zfsBaseName}"
		machine.vm.network "private_network", ip: "#{hostonlyBaseAddrString}.#{zfsBaseAddr}"
		machine.vm.provider "#{vm_provider}" do |provider_vm|
			provider_vm.name = "#{zfsBaseName}"
			provider_vm.memory = 4096
			provider_vm.cpus = 4
			# Use the network address as a way of making a unique IP address on eth0; otherwise
			# vagrant would make all nodes 10.0.2.15
			provider_vm.customize ['modifyvm',:id, '--natnet1', "#{natBaseAddrString}.#{zfsBaseAddr}.0/24"] 
		end
    	machine.vm.provision  "shell", inline: $setup_ssh_keys
       	machine.vm.provision  "shell", inline: $setup_hosts
	end
	config.vm.define "#{devopsBaseName}" do |machine|
		machine.vm.hostname = "#{devopsBaseName}"
		machine.vm.network "private_network", ip: "#{hostonlyBaseAddrString}.#{devopsBaseAddr}"
		machine.vm.provider "#{vm_provider}" do |provider_vm|
			provider_vm.name = "#{devopsBaseName}"
			provider_vm.memory = 4096
			provider_vm.cpus = 4
			# Use the network address as a way of making a unique IP address on eth0; otherwise
			# vagrant would make all nodes 10.0.2.15
			provider_vm.customize ['modifyvm',:id, '--natnet1', "#{natBaseAddrString}.#{devopsBaseAddr}.0/24"] 
		end
    	machine.vm.provision  "shell", inline: $setup_ssh_keys
       	machine.vm.provision  "shell", inline: $setup_hosts
		# now we have the infrastructure created, provision the kubernetes cluster using ansible playbook
    	machine.vm.provision  "shell", inline: $ansible_playbook
	end
end
