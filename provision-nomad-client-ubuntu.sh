#!/usr/bin/env bash

set -exu

NOMAD_VERSION="0.5.6"
DOCKER_VERSION="17.03.2"

guess_private_ip(){
  /sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'
}

PRIVATE_IP=${PRIVATE_IP:-$(guess_private_ip)}

if [ -z "${NOMAD_SERVER_ADDRESS}" ]; then
  echo "The NOMAD_SERVER_ADDRESS env var is required."
  echo "It should point to the ip address of your CircleCI"
  echo "services installation."
  exit 1
fi

echo "-------------------------------------------"
echo "     Performing System Updates"
echo "-------------------------------------------"
apt-get update && apt-get -y upgrade

echo "-------------------------------------------"
echo "     Installing Required Dependencies"
echo "-------------------------------------------"
apt-get install -y zip

echo "--------------------------------------"
echo "       Persisting Iptables"
echo "--------------------------------------"
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
apt-get install -y iptables-persistent
service netfilter-persistent start
invoke-rc.d netfilter-persistent save
service netfilter-persistent stop

echo "--------------------------------------"
echo "        Installing Docker"
echo "--------------------------------------"
apt-get install -y "linux-image-extra-$(uname -r)" linux-image-extra-virtual
apt-get install -y apt-transport-https ca-certificates curl
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get -y install "docker-ce=${DOCKER_VERSION}~ce-0~ubuntu-$(lsb_release -cs)" cgmanager

echo "--------------------------------------"
echo "         Installing nomad"
echo "--------------------------------------"
curl -o nomad.zip "https://releases.hashicorp.com/nomad/0.5.6/nomad_${NOMAD_VERSION}_linux_amd64.zip"
unzip nomad.zip
mv nomad /usr/bin
mkdir -p /etc/nomad

echo "--------------------------------------"
echo "      Creating config.hcl"
echo "--------------------------------------"
cat <<EOT > /etc/nomad/config.hcl
log_level = "DEBUG"

data_dir = "/opt/nomad"
datacenter = "us-east-1"

advertise {
    http = "$PRIVATE_IP"
    rpc = "$PRIVATE_IP"
    serf = "$PRIVATE_IP"
}

client {
    enabled = true
    servers = ["${NOMAD_SERVER_ADDRESS}:4647"]
    node_class = "linux-64bit"
    options = {"driver.raw_exec.enable" = "1"}
}
EOT

echo "--------------------------------------"
echo "      Creating nomad.conf"
echo "--------------------------------------"
cat <<EOT > /etc/init/nomad.conf
start on filesystem or runlevel [2345]
stop on shutdown

script
    exec nomad agent -config /etc/nomad/config.hcl
end script
EOT

echo "--------------------------------------"
echo "   Creating ci-privileged network"
echo "--------------------------------------"
docker network create --driver=bridge --opt com.docker.network.bridge.name=ci-privileged ci-privileged

echo "--------------------------------------"
echo "      Starting Nomad service"
echo "--------------------------------------"
service nomad restart
