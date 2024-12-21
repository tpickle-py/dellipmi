#!/bin/bash

# Remote IPMI Management Script
# Manages multiple remote IPMI hosts with network scanning capability

CONFIG_DIR="/opt/ipmi/config"
CREDS_DIR="${CONFIG_DIR}/credentials"
SCRIPT_DIR="/opt/ipmi/scripts"

# Function to display usage
usage() {
    echo "Remote IPMI Management Tool"
    echo
    echo "Usage:"
    echo "  $0 [command] [options]"
    echo
    echo "Commands:"
    echo "  scan        Scan network for IPMI devices"
    echo "  add-host    Add a new host to manage"
    echo "  remove-host Remove a host from management"
    echo "  list-hosts  List all managed hosts"
    echo "  power       Execute power command on host(s)"
    echo
    echo "Options for scan:"
    echo "  --network   Network range to scan (e.g., 192.168.1.0/24)"
    echo "  --ports     Ports to scan (default: 623)"
    echo
    echo "Options for add-host:"
    echo "  --host      Hostname or IP address"
    echo "  --username  IPMI username"
    echo "  --password  IPMI password"
    echo "  --port      IPMI port (default: 623)"
    echo "  --alias     Friendly name for the host"
    echo
    echo "Options for remove-host:"
    echo "  --alias     Host alias to remove"
    echo
    echo "Options for power:"
    echo "  --host      Hostname/IP or alias (use 'all' for all hosts)"
    echo "  --action    Power action (on/off/status)"
    echo
    echo "Examples:"
    echo "  $0 scan --network 192.168.1.0/24"
    echo "  $0 add-host --host 192.168.1.100 --username admin --password secret --alias server1"
    echo "  $0 power --host server1 --action status"
    exit 1
}

# Function to scan network for IPMI devices
scan_network() {
    local network=""
    local ports="623"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --network) network="$2"; shift 2 ;;
            --ports) ports="$2"; shift 2 ;;
            *) echo "Unknown parameter: $1"; usage ;;
        esac
    done
    
    if [[ -z "$network" ]]; then
        echo "Error: Network range is required"
        usage
    fi
    
    echo "Scanning network $network for IPMI devices..."
    
    # Use nmap to scan for IPMI devices
    # First scan for open IPMI ports
    local scan_results=$(nmap -p$ports -sU --open "$network" -oG - | grep "/open/" | cut -d" " -f2)
    #from the $scan_results, check to see if it has both port 80 and 623 open by doing another nmap scan
    local ipmi_devices=$(nmap -p80,623 -sU --open $scan_results -oG - | grep "/open/" | cut -d" " -f2)
    echo "current devices: $ipmi_devices"



    if [[ -z "$scan_results" ]]; then
        echo "No IPMI devices found."
        return
    fi
    
    echo "Found potential IPMI devices:"
    echo "$scan_results"
    
    # Process each discovered host
    echo "$scan_results" | while read -r host; do
        # Check if host is already managed
        local existing_host=$(find "$CREDS_DIR" -type f -exec jq -r .host {} \; | grep -x "$host")
        if [[ -n "$existing_host" ]]; then
            echo "Host $host is already managed"
            continue
        fi
        
        echo
        echo "Found new IPMI device at $host"
        read -p "Would you like to add this host? (y/n): " add_host
        
        if [[ "$add_host" =~ ^[Yy]$ ]]; then
            # Generate a default alias
            local default_alias="ipmi-${host//./'-'}"
            
            # Prompt for configuration
            read -p "Enter alias for this host [$default_alias]: " alias
            alias=${alias:-$default_alias}
            
            read -p "Enter IPMI username [root]: " username
            username=${username:-root}
            
            read -s -p "Enter IPMI password: " password
            echo
            
            read -p "Enter IPMI port [623]: " port
            port=${port:-623}
            
            # Add the host
            add_host_internal "$host" "$username" "$password" "$port" "$alias"
            
            # Test connection
            echo "Testing connection..."
            if execute_power_command "$alias" "status"; then
                echo "Successfully added and verified host $alias ($host)"
            else
                echo "Warning: Unable to verify IPMI connection. Please check credentials."
                read -p "Would you like to remove this host? (y/n): " remove_host
                if [[ "$remove_host" =~ ^[Yy]$ ]]; then
                    remove_host_internal "$alias"
                fi
            fi
        fi
    done
}

# Function to encrypt credentials
encrypt_credentials() {
    local host="$1"
    local username="$2"
    local password="$3"
    local port="$4"
    local alias="$5"
    
    # Create host config file
    cat > "${CREDS_DIR}/${alias}.json" <<EOF
{
    "host": "${host}",
    "username": "${username}",
    "password": "${password}",
    "port": "${port}",
    "alias": "${alias}"
}
EOF
    chmod 600 "${CREDS_DIR}/${alias}.json"
}

# Internal function to add a host
add_host_internal() {
    local host="$1"
    local username="$2"
    local password="$3"
    local port="$4"
    local alias="$5"
    
    # Store credentials
    encrypt_credentials "$host" "$username" "$password" "$port" "$alias"
    echo "Host '$alias' added successfully"
}

# Function to add a new host
add_host() {
    local host=""
    local username=""
    local password=""
    local port="623"
    local alias=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --host) host="$2"; shift 2 ;;
            --username) username="$2"; shift 2 ;;
            --password) password="$2"; shift 2 ;;
            --port) port="$2"; shift 2 ;;
            --alias) alias="$2"; shift 2 ;;
            *) echo "Unknown parameter: $1"; usage ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "$host" || -z "$username" || -z "$password" || -z "$alias" ]]; then
        echo "Error: Missing required parameters"
        usage
    fi
    
    # Check if alias already exists
    if [[ -f "${CREDS_DIR}/${alias}.json" ]]; then
        echo "Error: Host alias '$alias' already exists"
        exit 1
    fi
    
    add_host_internal "$host" "$username" "$password" "$port" "$alias"
}

# Internal function to remove a host
remove_host_internal() {
    local alias="$1"
    if [[ -f "${CREDS_DIR}/${alias}.json" ]]; then
        rm "${CREDS_DIR}/${alias}.json"
        echo "Host '$alias' removed successfully"
    else
        echo "Error: Host '$alias' not found"
        return 1
    fi
}

# Function to remove a host
remove_host() {
    local alias=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --alias) alias="$2"; shift 2 ;;
            *) echo "Unknown parameter: $1"; usage ;;
        esac
    done
    
    if [[ -z "$alias" ]]; then
        echo "Error: Alias is required"
        usage
    fi
    
    remove_host_internal "$alias"
}

# Function to list all hosts
list_hosts() {
    echo "Managed IPMI Hosts:"
    echo "------------------"
    for cred_file in "${CREDS_DIR}"/*.json; do
        if [[ -f "$cred_file" ]]; then
            local alias=$(basename "$cred_file" .json)
            local host=$(jq -r .host "$cred_file")
            local username=$(jq -r .username "$cred_file")
            local port=$(jq -r .port "$cred_file")
            echo "Alias: $alias"
            echo "  Host: $host"
            echo "  Username: $username"
            echo "  Port: $port"
            echo
        fi
    done
}

# Function to execute power command
execute_power_command() {
    local host="$1"
    local action="$2"
    local cred_file="${CREDS_DIR}/${host}.json"
    
    if [[ ! -f "$cred_file" ]]; then
        echo "Error: Host '$host' not found"
        return 1
    fi
    
    # Read credentials
    local ipmi_host=$(jq -r .host "$cred_file")
    local username=$(jq -r .username "$cred_file")
    local password=$(jq -r .password "$cred_file")
    local port=$(jq -r .port "$cred_file")
    
    # Execute IPMI command
    echo "Executing power $action on $host ($ipmi_host)..."
    "${SCRIPT_DIR}/dell-ipmi-shutdown.sh" -H "$ipmi_host" -U "$username" -P "$password" -p "$port" -a "$action"
}

# Function to handle power commands
power_command() {
    local host=""
    local action=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --host) host="$2"; shift 2 ;;
            --action) action="$2"; shift 2 ;;
            *) echo "Unknown parameter: $1"; usage ;;
        esac
    done
    
    # Validate parameters
    if [[ -z "$host" || -z "$action" ]]; then
        echo "Error: Missing required parameters"
        usage
    fi
    
    # Check if action is valid
    if [[ ! "$action" =~ ^(on|off|status)$ ]]; then
        echo "Error: Invalid action. Use 'on', 'off', or 'status'"
        exit 1
    fi
    
    # Handle 'all' hosts
    if [[ "$host" == "all" ]]; then
        for cred_file in "${CREDS_DIR}"/*.json; do
            if [[ -f "$cred_file" ]]; then
                local current_host=$(basename "$cred_file" .json)
                execute_power_command "$current_host" "$action"
            fi
        done
    else
        execute_power_command "$host" "$action"
    fi
}

# Main script execution
case "$1" in
    scan)
        shift
        scan_network "$@"
        ;;
    add-host)
        shift
        add_host "$@"
        ;;
    remove-host)
        shift
        remove_host "$@"
        ;;
    list-hosts)
        list_hosts
        ;;
    power)
        shift
        power_command "$@"
        ;;
    *)
        usage
        ;;
esac