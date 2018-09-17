# See https://github.com/bear/iptable-tools for rules documentation

inbound 22
inbound 80
inbound 443
inbound 3001
inbound 4647
inbound 7171
inbound 8081
inbound 8125 ${PUBLICNET} UDP
inbound 8585
inbound 8800

outbound 80
outbound 443
outbound 4646
outbound 4647
outbound 4648
outbound 5432
outbound 5672
outbound 6379
outbound 15672
outbound 27017
