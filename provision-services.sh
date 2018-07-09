#!/usr/bin/env bash

set -exu

REPLICATED_VERSION="2.10.3"
DOCKER_VERSION="17.03.2"

guess_private_ip(){
  /sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'
}

write_config(){
  config_dir=/var/lib/replicated/circle-config
  mkdir -p "$config_dir"

  echo "${HTTP_PROXY:-}" > $config_dir/http_proxy
  echo "${HTTPS_PROXY:-}" > $config_dir/https_proxy
  echo "${NO_PROXY:-}" > $config_dir/no_proxy
}

run_installer(){
  echo "--------------------------------------------"
  echo "       Finding Private IP"
  echo "--------------------------------------------"


  PRIVATE_IP=${PRIVATE_IP:-$(guess_private_ip)}
  export PRIVATE_IP

  echo "Using address: ${PRIVATE_IP}"

  echo "--------------------------------------------"
  echo "          Downloading Replicated"
  echo "--------------------------------------------"
  curl -sSk -o /tmp/get_replicated.sh "https://get.replicated.com/docker?replicated_tag=$REPLICATED_VERSION&replicated_ui_tag=$REPLICATED_VERSION&replicated_operator_tag=$REPLICATED_VERSION"

  echo "--------------------------------------------"
  echo "          Installing Replicated"
  echo "--------------------------------------------"

  bash /tmp/get_replicated.sh local-address="$PRIVATE_IP" no-proxy no-docker
}

run_installer
write_config

