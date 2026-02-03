# MPTCP-Proxy

MPTCP-Proxy is a TCP proxy that provides Multipath TCP (MPTCP) functionality for standard TCP applications. By acting as an intermediary, it enables applications that don't natively support MPTCP to benefit from multiple network paths, improving throughput, reliability, and resilience.

## What is MPTCP?

Multipath TCP (MPTCP) is an extension to TCP that allows a single connection to use multiple network paths simultaneously. This can provide:

- **Increased throughput**: Aggregate bandwidth from multiple interfaces
- **Better reliability**: Seamless failover between network paths
- **Improved resilience**: Continue connection even if one path fails

## How MPTCP-Proxy Works

![The Overview of MPTCP-Proxy](/assets/overview.png)

MPTCP-Proxy operates in two modes:

1. **Client Mode**: Receives standard TCP connections and forwards them using MPTCP
2. **Server Mode**: Receives MPTCP connections and forwards them as standard TCP to backend services

This architecture allows legacy applications (like iperf3, nginx, etc.) to utilize MPTCP without modification.

## Usage

```
Usage of ./mptcp-proxy:
  -m, --mode string     specify mode (server or client)
  -p, --port int        local bind port
  -r, --remote string   remote address (ex. 127.0.0.1:8080)
  -t, --transparent     Enable transparent mode
      --disable-mptcp   Disable MPTCP (use standard TCP)
```

### Examples

**Client Mode:**
```bash
./mptcp-proxy -m client -p 5555 -r 10.0.1.2:4444
```

**Server Mode:**
```bash
./mptcp-proxy -m server -p 4444 -r localhost:80
```

## Environment

- Ubuntu 22.04 LTS
- Linux Kernel with MPTCP support (5.15+)
- Docker & Docker Compose (for testing)

## Building

```bash
make build
```

This will create the `mptcp-proxy` binary in the `bin/` directory.

## Testing

The project includes four test scenarios demonstrating different MPTCP configurations:

### Test Scenarios

#### 1. Simple Test (`test/simple/`)

![Test Environment](/assets/test-env.png)

**Purpose**: Basic MPTCP functionality test with two network paths in a simple client-server setup.

**Topology**:
- Client and Server are directly connected via two networks (network_a and network_b)
- Both client and server have two network interfaces
- Tests basic MPTCP subflow establishment and data transfer

**Run test**:
```bash
cd test/simple
./test.sh
```

**What it tests**:
- MPTCP connection establishment over multiple paths
- Subflow creation and management
- Address announcement and establishment
- iperf3 throughput over MPTCP

---

#### 2. Routing Test (`test/routing/`)

**Purpose**: Tests MPTCP through a router with multi-path routing.

**Topology**:
- Client and Server are connected through a Router node
- Server has two interfaces to the router (network_a and network_b)
- Client connects to router via network_c
- Router performs load balancing using ECMP (Equal-Cost Multi-Path)

**Run test**:
```bash
cd test/routing
./test.sh
```

**What it tests**:
- MPTCP through intermediate router
- Multi-path routing with nexthop load balancing
- MPTCP endpoint announcement
- Router forwarding behavior with MPTCP

**Key difference from Simple**: Introduces routing complexity and tests MPTCP behavior through a router.

---

#### 3. Routing2 Test (`test/routing2/`)

**Purpose**: Tests asymmetric MPTCP configuration where only client has multiple paths.

**Topology**:
- Server has single interface to network_a
- Router connects network_a, network_b, and network_c
- Client has two interfaces (network_b and network_c)
- Only client-side path diversity is tested

**Run test**:
```bash
cd test/routing2
./test.sh
```

**What it tests**:
- MPTCP with asymmetric path availability
- Client-initiated subflows without server announcement
- Verifies ANNOUNCED count is 0 (no server-side announcements)
- Client-side multipath capability

**Key difference from Routing**: Server doesn't announce additional addresses, only client creates multiple subflows.

---

#### 4. SoftEther VPN Test (`test/sevpn/`)

**Purpose**: Tests MPTCP integration with VPN tunnels using SoftEther VPN.

**Topology**:
- Complex multi-container setup with VPN tunnels
- Server side: server-srv ↔ server-vpn ↔ server-proxy
- Client side: client-vpn ↔ client-proxy
- MPTCP proxy sits between VPN endpoints
- Uses two physical paths (network_a and network_b) between proxies

**Run test**:
```bash
cd test/sevpn
./test.sh
```

**What it tests**:
- MPTCP over VPN tunnels
- Integration with SoftEther VPN
- Multiple paths with VPN encapsulation
- ping connectivity test through VPN-MPTCP chain
- Note: Some connections may not be properly tracked (CLOSED events)

**Key difference**: Most complex scenario, combining VPN tunnels with MPTCP for real-world deployment simulation.

---

### Test Output

All tests verify the following MPTCP events:

- `CREATED`: MPTCP connections are created
- `ESTABLISHED`: Main connection is established
- `ANNOUNCED`: Additional addresses are announced (except routing2)
- `SF_ESTABLISHED`: Subflows are established
- `CLOSED`: Connections are properly closed

### Running All Tests

```bash
# Run individual tests
cd test/simple && ./test.sh
cd test/routing && ./test.sh
cd test/routing2 && ./test.sh
cd test/sevpn && ./test.sh
```

Each test script will:
1. Stop any existing containers
2. Build Docker images
3. Start the test environment
4. Run connectivity tests
5. Verify MPTCP behavior
6. Clean up containers

## Project Structure

```
mptcp/
├── cmd/
│   └── mptcp-proxy/       # Main application code
├── tproxy/                # Transparent proxy implementation
├── test/
│   ├── shared/            # Shared test utilities
│   ├── simple/            # Basic MPTCP test
│   ├── routing/           # Router with multi-path test
│   ├── routing2/          # Asymmetric path test
│   └── sevpn/             # VPN integration test
├── assets/                # Documentation images
└── README.md
```

## License

See LICENSE file for details.

## Contributing

Contributions are welcome! Please see CONTRIBUTING.md for details.

# Example of MPTCP Packtes

![Wireshark](/assets/wireshark.png)