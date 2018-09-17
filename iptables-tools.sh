#!/bin/bash
#
# Author:  bear (Mike Taylor)
# Contact: bear@bear.im
# License: MIT
#
# Copyright (c) 2015 by Mike Taylor'
#

# RULESDIR will default to /etc/iptables.d
# PUBLICNET will default to eth0 unless you override it
set -x
RULESDIR="/etc/iptables.d"
if [ -z "${PUBLICNET}" ]; then
  PUBLICNET="eth0"
fi

if hash iptables 2>/dev/null ; then
  IPFOUND="found"
else
  IPFOUND=""
fi

function check-iptables () {
  if [ -z "${IPFOUND}" ]; then
    echo "iptables binary not found, exiting"
    exit 4
  fi
}
# inbound(port, network, protocol)
function inbound () {
  if [ -z "$1" ]; then
    echo "inbound rules require a port value"
    exit 2
  fi
  if [ -z "$2" ]; then
    INBOUNDNET=${PUBLICNET}
  else
    INBOUNDNET=$2
  fi
  if [ -z "$3" ]; then
    INBOUNDPROTO="tcp"
  else
    INBOUNDPROTO=$3
  fi

  check-iptables

  echo "  defining inbound rule for port $1 ${INBOUNDPROTO} for ${INBOUNDNET}"
  iptables -A INPUT  -i ${INBOUNDNET} -p ${INBOUNDPROTO} --dport $1 -m state --state NEW,ESTABLISHED -j ACCEPT
  iptables -A OUTPUT -o ${INBOUNDNET} -p ${INBOUNDPROTO} --sport $1 -m state --state ESTABLISHED     -j ACCEPT
}

# outbound(port, network, protocol)
function outbound () {
  if [ -z "$1" ]; then
    echo "outbound rules require a port value"
    exit 2
  fi
  if [ -z "$2" ]; then
    INBOUNDNET=${PUBLICNET}
  else
    INBOUNDNET=$2
  fi
  if [ -z "$3" ]; then
    INBOUNDPROTO="tcp"
  else
    INBOUNDPROTO=$3
  fi

  check-iptables

  echo "  defining outbound rule for port $1 ${INBOUNDPROTO} for ${INBOUNDNET}"
  iptables -A OUTPUT -o ${INBOUNDNET} -p ${INBOUNDPROTO} --dport $1 -m state --state NEW,ESTABLISHED -j ACCEPT
  iptables -A INPUT  -i ${INBOUNDNET} -p ${INBOUNDPROTO} --sport $1 -m state --state ESTABLISHED     -j ACCEPT
}

# rules(path-to-rules-dir)
function load-rules () {
  echo "loading rules"

  check-iptables

  if [ -z "$1" ]; then
    echo "rules path required"
    exit 2
  fi
  if [ -d "$1" ]; then
    for s in ${RULESDIR}/*.sh ; do
      if [ -e "${s}" ]; then
        source ${s}
      fi
    done
  fi
}

function check-rules () {
  echo "checking current rules against saved rules"

  check-iptables

  iptables-save | sed -e '/^[#:]/d' > /tmp/iptables.check

  if [ -e /tmp/itpables.check ]; then
    if [ -e /etc/iptables.rules ]; then
      cat /etc/iptables.rules | sed -e '/^[#:]/d' > /tmp/iptables.rules
      diff -q /tmp/iptables.rules /tmp/iptables.check
    else
      echo "unable to check, /etc/iptables.rules does not exist"
      exit 1
    fi
  else
    echo "iptables.check file was not generated"
    exit 1
  fi
}

#
# Clear everything from iptables, establish default drop
# and then set rules for common ports
#
function reset-rules () {
  echo "resetting iptables rules to default DENY"

  check-iptables

  iptables  -F

  # Default policy is drop
  iptables -P INPUT DROP
  iptables -P OUTPUT DROP

  # Docker
  iptables -A INPUT -i docker0 -j ACCEPT
  iptables -A OUTPUT -o docker0 -j ACCEPT

  # Allow localhost
  iptables -A INPUT  -i lo -j ACCEPT
  iptables -A OUTPUT -o lo -j ACCEPT

  # Allow incoming SSH
  inbound 22

  # Allow outgoing SSH
  outbound 22

  # Allow outbound DHCP
  outbound "67:68" ${PUBLICNET} "udp"

  # Allow outbound DNS
  outbound "53" ${PUBLICNET} "udp"

  # Allow only NTP if it's our request
  iptables -A INPUT  -s 0/0 -d 0/0 -p udp --source-port      123:123 -m state --state ESTABLISHED     -j ACCEPT
  iptables -A OUTPUT -s 0/0 -d 0/0 -p udp --destination-port 123:123 -m state --state NEW,ESTABLISHED -j ACCEPT
}

DOLOAD=""
DORESET=""
DOCHECK=""
DOFLOW=""

while [ $# -gt 0 ]; do
  case "$1" in
    --rules)
              RULESDIR="$2"
              shift
              shift
              ;;
    --load)
              DOLOAD="yes"
              shift
              ;;
    --reset)
              DORESET="yes"
              shift
              ;;
    --check)
              DOCHECK="yes"
              shift
              ;;
    --flow)
              DOFLOW="yes"
              shift
              ;;
    --net)
              PUBLICNET="$2"
              shift
              shift
              ;;
  esac
done

if [ -n "${DORESET}" ]; then
  reset-rules
fi
if [ -n "${DOLOAD}" ]; then
  if [ -d "${RULESDIR}" ]; then
    load-rules "${RULESDIR}"
  else
    echo "Provided rules directory does not exist: ${RULESDIR}"
    exit 2
  fi
fi
if [ -n "${DOCHECK}" ]; then
  check-rules
fi

if [ -n "${DOFLOW}" ]; then
  cat << EOF

          ┌──────────────┐
        ┌─│   network    │◀┐
        │ └──────────────┘ │
        ▼                  │
┌──────────────┐   ┌──────────────┐
│  prerouting  │   │ postrouting  │
└──────────────┘   └──────────────┘
        │                  ▲
        │   ┌──────────┐   │
        ├──▶│ forward  │───┤
        │   └──────────┘   │
        ▼                  │
┌──────────────┐   ┌──────────────┐
│    input     │   │    output    │
└──────────────┘   └──────────────┘
        │                  ▲
        │ ┌──────────────┐ │
        └▶│   process    │─┘
          └──────────────┘

EOF
  exit
fi
