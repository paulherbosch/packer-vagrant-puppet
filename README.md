# packer-vagrant-puppet
Temporary holding place for packer-vagrant-puppet related config tests.

## Prerequisites
- Packer version used: 0.10.1  
`https://releases.hashicorp.com/packer/0.10.1/packer_0.10.1_darwin_amd64.zip`
- Vagrant version used: 1.8.4  
`https://releases.hashicorp.com/vagrant/1.8.4/vagrant_1.8.4.dmg`
- Virtualbox version used: 5.0.20 r106931  
`https://www.virtualbox.org/wiki/Downloads`
- iso image used by packer to build the vagrant box:  
`https://codex.cegeka.be/jenkins/job/run-jeos-iso-creation-build/1702/artifact/jeos-iso-build/target/dist/jeos_svintvagrantrhel7.intra.cegeka.be_RedHat_7_x86_64.iso`

## JEOS Profile
We want to build a vagrant box with packer using a JEOS iso because we need the Cegeka certs to present in order to gain access to our pulp yum repo's.

A standard jeos profile was used with a custom kickstart script to add a vagrant user.

Here's the link to the jeos profile: `https://github.com/cegeka/jeos-iso-build/blob/master/image-service/profiles/svintvagrantrhel7.intra.cegeka.be.txt`

```slim_hwtype="virtual-esxi"
slim_cfgtype="node"
slim_swrole=""
slim_architecture="x86_64"
slim_operatingsystem="RedHat"
slim_operatingsystemrelease="7"
slim_hostname="svintvagrantrhel7"
slim_domainname="intra.cegeka.be"
slim_interface="eth0"
slim_bootproto="dhcp"
slim_ipaddress=""
slim_netmask=""
slim_gateway=""
slim_nameserver=""
slim_hinumber="HI"
slim_customer="cegeka"
slim_datacenter="vagrant"
slim_environment="dev"
slim_application="vagrant"
```

## Puppet Monorepo
The vagrant puppet provisioner needs access to all puppet modules. We created a puppet monorepo which contains all cegeka puppet-modules.  This repo needs to be cloned to your workstation so it can be referenced in the `Vagrantfile`:


https://github.com/cegeka/monorepo-puppet-modules


## Packer Template
Folder `cegeka-jeos-centos-7` contains a packer template and a couple of scripts.  
You can use this to build a vagrant box using the JEOS iso mentioned above.  
Update `template.json` to make it use the iso you downloaded and run following command to start the build:

`packer build template.json`

The above will generate a vagrant .box file in the current directory.

```{
  "provisioners": [
    {
      "type": "shell",
      "execute_command": "echo 'vagrant'|sudo -S sh '{{.Path}}'",
      "override": {
        "virtualbox-iso": {
          "scripts": [
            "scripts/base.sh",
            "scripts/vagrant.sh",
            "scripts/virtualbox.sh",
            "scripts/cleanup.sh"
          ]
        }
      }
    }
  ],
  "post-processors": [
    {
      "type": "vagrant",
      "override": {
        "virtualbox": {
          "output": "centos-7-1-x64-virtualbox.box"
        }
      }
    }
  ],
  "builders": [
    {
      "type": "virtualbox-iso",
      "boot_command": [
        "<tab><enter><wait>"
      ],
      "boot_wait": "10s",
      "disk_size": 40520,
      "guest_os_type": "RedHat_64",
      "http_directory": "http",
      "iso_checksum": "3af199d35f0b2897c178104a5751069e958788cf",
      "iso_checksum_type": "sha1",
      "iso_url": "jeos_svintvagrantrhel7.intra.cegeka.be_RedHat_7_x86_64.iso",
      "ssh_username": "vagrant",
      "ssh_password": "vagrant",
      "ssh_port": 22,
      "ssh_wait_timeout": "10000s",
      "shutdown_command": "echo '/sbin/halt -h -p' > /tmp/shutdown.sh; echo 'vagrant'|sudo -S sh '/tmp/shutdown.sh'",
      "guest_additions_path": "VBoxGuestAdditions_{{.Version}}.iso",
      "virtualbox_version_file": ".vbox_version",
      "vboxmanage": [
        [ "modifyvm", "{{.Name}}", "--memory", "512" ],
        [ "modifyvm", "{{.Name}}", "--cpus", "1" ]
      ]
    }
  ]
}
```

## Vagrant
Add the freshly built vagrant box to your config:

`vagrant box add ~/path/to/your/vagrant.box --name name-for-your-vagrant-box-e.g.-cegeka-rhel7`

Create a new directory and Vagrantfile for your new box:

```mkdir ~/vagrant/cegeka-rhel7
cd ~/vagrant/cegeka-rhel7
vagrant init name-of-vm-to-be-used-in-virtualbox```

Edit the vagrantfile

```# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # set vagrantbox
  config.vm.box = "cegeka-rhel7"

  # do not mount /vagrant
  # config.vm.synced_folder ".", "/vagrant", disabled: true

  # set hostname
  config.vm.hostname = "svintvagrantrhel7"

  # create a private network, which allows host-only access to the machine
  # config.vm.network "private_network", ip: "192.168.33.10"

  # puppet provisioning - NOT WORKING YET!
  config.vm.provision "puppet" do |puppet|
    puppet.manifests_path    = "/Users/paulh/git-repos/monorepo-puppet-modules"
    puppet.manifest_file     = "default.pp"
    # puppet.hiera_config_path = "/Users/paulh/git-repos/monorepo-puppet-modules/hiera.yaml"
    puppet.working_directory = "/tmp/vagrant-puppet"
    puppet.options           = "--hiera_config=/vagrant/hiera.yaml --verbose --debug"
  end
end
```

Run `vagrant up` to start the box  

Run `vagrant provision` to start the puppet run
