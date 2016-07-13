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
We want to build vagrant boxes with packer.  
Packer needs to use an is built with Jeos because we need all Cegeka certs to be present on the vagrant box so it has access to our pulp yum repo's.

A standard jeos profile was used with a custom kickstart script which adds a vagrant user.

The only differences between the default kickstart en this one are:

- disable the puppet service. we'll use `vagrant provision` and don't need the puppet daemon running
- create a vagrant user so packer can ssh into the vm during the postbuild process

https://github.com/cegeka/jeos-iso-build/blob/master/image-service/input/kickstart/custom/svintvagrantrhel7.intra.cegeka.be/ks.cfg.end-el7
```
%packages
@jeos
%end

%pre
%end

%post
#!/bin/sh

# Cegeka splash screen
cat <<EOF | augtool
set /files/boot/grub/menu.lst/splashimage /boot/grub/cegeka-splash.xpm.gz
save
EOF

# Use Cegeka generated certificates
cat <<EOF | augtool
set /files/etc/puppet/puppet.conf/main/ssldir /etc/cegeka/ssl
save
EOF

# Setup Puppet pluginsync
cat <<EOF | augtool
set /files/etc/puppet/puppet.conf/main/pluginsync true
save
EOF

# Manage services on boot
chkconfig iscsi off
chkconfig iscsid off
chkconfig puppet off

# Remove unnecessary RPMs
rpm -e system-config-securitylevel-tui

# Import Cegeka RPM signing GPG key
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CGK
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-Cegeka

# Import RedHat RPM signing GPG key
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

# Create Vagrant User
/usr/sbin/groupadd -g 65534 vagrant
/usr/sbin/useradd vagrant -u 65534 -g vagrant -G wheel
echo "vagrant"|passwd --stdin vagrant
echo "vagrant        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers.d/vagrant
echo "Defaults:vagrant !requiretty"                 >> /etc/sudoers.d/vagrant
chmod 0440 /etc/sudoers.d/vagrant
```

Here's the link to the jeos profile: `https://github.com/cegeka/jeos-iso-build/blob/master/image-service/profiles/svintvagrantrhel7.intra.cegeka.be.txt`

```
slim_hwtype="virtual-esxi"
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
The vagrant puppet provisioner needs access to all puppet modules. We created a puppet monorepo which contains all cegeka puppet-modules.  
It's probably easiest if you clone this repo and use it as the root for your vagrant project.

https://github.com/cegeka/monorepo-puppet-modules

## Packer Template
Folders `cegeka-rhel6-vagrant` and `cegeka-rhel7-vagrant` contain a packer template and a couple of scripts.  
You can use this to build a vagrant box using the JEOS isos mentioned above.  
Update `template.json` to make it use the iso you downloaded.
Don't forget to update iso checksum (use `shasum isofile.iso)
Run following command to start the build:

`packer build template.json`

The above will generate a vagrant .box file in the current directory.

```
{
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
            "scripts/puppet.sh",
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
          "output": "cegeka-vagrant-rhel7.box"
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
      "iso_checksum": "f0abc97c0e953419272c57e45bc5f20fb7212abe",
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
        [ "modifyvm", "{{.Name}}", "--memory", "1024" ],
        [ "modifyvm", "{{.Name}}", "--cpus", "2" ]
      ]
    }
  ]
}
```

## Vagrant

### Manual setup, without puppet provisioning
Add the freshly built vagrant box to your config:

`vagrant box add ~/path/to/your/vagrant.box --name cegeka-rhel7`

Create a new directory and Vagrantfile for your new box:

```
mkdir ~/vagrant/cegeka-rhel7
cd ~/vagrant/cegeka-rhel7
vagrant init name-of-vm-to-be-used-in-virtualbox
```

Edit the vagrantfile

```
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # set vagrantbox
  config.vm.box = 'cegeka-rhel7'

  # set hostname
  config.vm.hostname = 'svintvagrantrhel7'

  # create a private network, which allows host-only access to the machine
  config.vm.network 'private_network', ip: '192.168.33.10'

  # # puppet provisioner
  # config.vm.provision 'puppet' do |puppet|
  #   puppet.environment_path  = 'puppet'
  #   puppet.hiera_config_path = 'puppet/hiera.yaml'
  #   puppet.environment       = 'dev'
  #   puppet.options           = '--verbose --fileserverconfig=/vagrant/fileserver.conf'
  # end

  # shell provisioner - stop puppet daemon.
  #
  # profile::iac::base enables the puppet service after each 'vagrant provision'
  # vagrant does not use the puppet daemon so it can be stopped
  config.vm.provision 'shell', inline: 'sudo systemctl stop puppet'
end
```

Run `vagrant up` to start the box  

Run `vagrant ssh` to access your box

If you uncomment `config.vm.network 'private_network'`, you can access the ip address in the config directly from you mac.  
I find this config handy becuase it eliminates the need for portforwarding.

### (semi) Automatic setup
If you clone the `git@github.com:cegeka/monorepo-puppet-modules.git` repository you can use it as the root for your vagrant project.

... TBC ...
