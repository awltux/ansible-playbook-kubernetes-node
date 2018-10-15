# ansible-playbook-kubernetes-node

Playbook to create a kubernetes node on CentOS/RHEL 7

Run the playbook-init.yml first to clone the ansible roles from git

```
ansible-playbook playbook-init.yml
```
   
Then run the playbook-apply.yml on a target host.
  
```
ansible-playbook --inventory <node_hostname>, playbook-apply.yml
```
