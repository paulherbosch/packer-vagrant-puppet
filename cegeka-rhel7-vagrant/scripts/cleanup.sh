yum -y erase gtk2 libX11 hicolor-icon-theme avahi freetype bitstream-vera-fonts
yum -y clean all
rm -f /etc/yum.repos.d/os.repo
rm -rf VBoxGuestAdditions_*.iso
rm -rf /tmp/rubygems-*

