VBOX_VERSION=$(cat /home/vagrant/.vbox_version)

# required for VirtualBox 4.3.26
yum install -y bzip2

# create vboxadd user and vboxsf group
# we don't want vbox guest additions installer to do this
# because we need to control the uid and gid
/usr/sbin/groupadd -g 65533 vboxsf
/usr/sbin/useradd vboxadd --uid 65533 --gid 1 --home-dir /var/run/vboxadd --no-create-home --no-user-group --shell /bin/false

# install vbox guest additions
cd /tmp
mount -o loop /home/vagrant/VBoxGuestAdditions_$VBOX_VERSION.iso /mnt
sh /mnt/VBoxLinuxAdditions.run
umount /mnt
rm -rf /home/vagrant/VBoxGuestAdditions_*.iso

