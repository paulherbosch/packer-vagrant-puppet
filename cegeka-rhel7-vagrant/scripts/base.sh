sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers

cat << EOF > /etc/yum.repos.d/os.repo
[os]
name=PULP mirror RedHat 7 os staid/shared/prd
baseurl=https://pulp.cegeka.be/staid/shared/prd/redhat-7-os-x86_64
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-7-release
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
sslverify=True
sslclientcert=/etc/cegeka/ssl/certs/svintvagrantrhel7.intra.cegeka.be.pem
sslclientkey=/etc/cegeka/ssl/private_keys/svintvagrantrhel7.intra.cegeka.be.pem
EOF
yum -y install gcc make gcc-c++ kernel-devel-`uname -r` perl
