# See https://github.com/bear/iptable-tools for rules documentation

inbound 22 ens3
inbound 80 ens3
inbound 443 ens3
inbound 3001 ens3
inbound 4647 ens3
inbound 7171 ens3
inbound 8081 ens3
inbound 8125 ens3 UDP
inbound 8585 ens3
inbound 8800 ens3

outbound 80 ens3
outbound 443 ens3
outbound 4646 ens3
outbound 4647 ens3
outbound 4648 ens3
outbound 5432 ens3
outbound 5672 ens3
outbound 6379 ens3
outbound 15672 ens3
outbound 27017 ens3
