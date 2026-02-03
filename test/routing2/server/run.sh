#!/bin/bash

ip mptcp limits set subflow 1
#ip mptcp endpoint add 10.123.201.2 dev eth1 signal

ip route add 10.123.201.0/24 via 10.123.200.3
ip route add 10.123.202.0/24 via 10.123.200.3

# Start iperf3 in background
iperf3 -s -p 5201 &

# Wait a bit for iperf3 to start
sleep 1

# Start mptcp-proxy (this will run in foreground)
/mptcp-proxy/mptcp-proxy -m server -p 4444 -r localhost:5201