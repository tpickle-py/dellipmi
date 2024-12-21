# IPMI Docker Management Tool

This tool provides a containerized environment for managing multiple IPMI devices.

## Quick Start

1. Build and start the container:
```bash
docker-compose up -d
```

2. Scan network for IPMI devices:
```bash
docker exec -it ipmi-tools ipmi-manager scan --network 192.168.1.0/24
```

3. List managed hosts:
```bash
docker exec ipmi-tools ipmi-manager list-hosts
```

4. Check power status:
```bash
docker exec ipmi-tools ipmi-manager power --host hostname --action status
```

## Available Commands

### Network Scanning
```bash
docker exec -it ipmi-tools ipmi-manager scan --network 192.168.1.0/24
```

### Host Management
```bash
# Add host manually
docker exec ipmi-tools ipmi-manager add-host --host 192.168.1.100 --username admin --password secret --alias server1

# Remove host
docker exec ipmi-tools ipmi-manager remove-host --alias server1

# List hosts
docker exec ipmi-tools ipmi-manager list-hosts
```

### Power Management
```bash
# Check status
docker exec ipmi-tools ipmi-manager power --host server1 --action status

# Power on
docker exec ipmi-tools ipmi-manager power --host server1 --action on

# Power off
docker exec ipmi-tools ipmi-manager power --host server1 --action off

# Check all hosts
docker exec ipmi-tools ipmi-manager power --host all --action status
```
