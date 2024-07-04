#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Run as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 
  exit 1
fi


# Replacing legacy repos
sed -i s/mirror.centos.org/vault.centos.org/g /etc/yum.repos.d/*.repo
sed -i s/^#.*baseurl=http/baseurl=http/g /etc/yum.repos.d/*.repo
sed -i s/^mirrorlist=http/#mirrorlist=http/g /etc/yum.repos.d/*.repo
yum update -y

# Install necessary packages
yum install -y \
  redhat-lsb-core \
  wget \
  rpmdevtools \
  rpm-build \
  createrepo \
  yum-utils \
  gcc \
  vim

# Variables
NGINX_VERSION="1.23.3"
OPENSSL_VERSION="1.1.1q"
NGINX_SRC_RPM="nginx-${NGINX_VERSION}-1.el7.ngx.src.rpm"
OPENSSL_TAR="openssl-${OPENSSL_VERSION}.tar.gz"
REPO_DIR="/usr/share/nginx/html/repo"
NGINX_REPO_URL="http://nginx.org/packages/mainline/centos/7/SRPMS/${NGINX_SRC_RPM}"
OPENSSL_URL="https://www.openssl.org/source/old/1.1.1/${OPENSSL_TAR}"
BUILD_DIR="/usr/lib"
RPMS_DIR="/root/rpmbuild/RPMS/x86_64"

# Download and extract
wget $NGINX_REPO_URL
wget --no-check-certificate $OPENSSL_URL
tar -xvf $OPENSSL_TAR -C $BUILD_DIR

# Install nginx source RPM
rpm -ivh $NGINX_SRC_RPM

# Install build dependencies
yum-builddep /root/rpmbuild/SPECS/nginx.spec -y

# Modify nginx spec file to use the custom OpenSSL
sed -i "s|--with-stream_ssl_preread_module|--with-stream_ssl_preread_module --with-openssl=${BUILD_DIR}/openssl-${OPENSSL_VERSION} --with-openssl-opt=enable-tls1_3|g" /root/rpmbuild/SPECS/nginx.spec

# Compile nginx
rpmbuild -ba /root/rpmbuild/SPECS/nginx.spec

# Install and start nginx
yum localinstall -y ${RPMS_DIR}/nginx-${NGINX_VERSION}-1.el7.ngx.x86_64.rpm
sed -i '/index  index.html index.htm;/a autoindex on;' /etc/nginx/conf.d/default.conf
systemctl enable --now nginx

# Create RPM repository
mkdir -p $REPO_DIR
cp ${RPMS_DIR}/nginx-${NGINX_VERSION}-1.el7.ngx.x86_64.rpm $REPO_DIR
createrepo $REPO_DIR

# Add custom RPM repository to the list
cat > /etc/yum.repos.d/custom.repo << EOF
[custom]
name=custom-repo
baseurl=http://192.168.56.10/repo
gpgcheck=0
enabled=1
EOF

# Clean up yum cache
yum clean all
