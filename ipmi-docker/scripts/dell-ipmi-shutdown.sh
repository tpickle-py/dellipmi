#!/bin/bash

# Dell IPMI Power Management Script
# This script manages power state (on/off) for Dell servers using IPMI

# Default values
DEFAULT_USERNAME="root"
DEFAULT_PORT="623"

# Function to display usage
usage() {
    echo "Usage: $0 -H hostname [-U username] [-P password] [-p port] [-a action]"
    echo "Options:"
    echo "  -H    Hostname or IP address of the Dell iDRAC/BMC (required)"
    echo "  -U    IPMI username (default: root)"
    echo "  -P    IPMI password (required)"
    echo "  -p    IPMI port (default: 623)"
    echo "  -a    Action: on, off, status (default: status)"
    exit 1
}

# Function to check if ipmitool is installed
check_ipmitool() {
    if ! command -v ipmitool &> /dev/null; then
        echo "Error: ipmitool is not installed. Please install it first."
        echo "Ubuntu/Debian: sudo apt-get install ipmitool"
        echo "RHEL/CentOS: sudo yum install ipmitool"
        exit 1
    fi
}

# Parse command line arguments
while getopts "H:U:P:p:a:hf" opt; do
    case $opt in
        H) HOST="$OPTARG" ;;
        U) USERNAME="$OPTARG" ;;
        P) PASSWORD="$OPTARG" ;;
        p) PORT="$OPTARG" ;;
        a) ACTION="$OPTARG" ;;
        f) FORCE=true ;;
        h) usage ;;
        ?) usage ;;
    esac
done

# Set default value for FORCE if not set
FORCE=${FORCE:-false}

# Check required parameters
if [ -z "$HOST" ] || [ -z "$PASSWORD" ]; then
    echo "Error: Hostname and password are required."
    usage
fi

# Set default values if not provided
USERNAME=${USERNAME:-$DEFAULT_USERNAME}
PORT=${PORT:-$DEFAULT_PORT}
ACTION=${ACTION:-"status"}

# Check for ipmitool
check_ipmitool

# Function to check IPMI connectivity
check_connection() {
    if ! ipmitool -I lanplus -H "$HOST" -U "$USERNAME" -P "$PASSWORD" -p "$PORT" chassis status &> /dev/null; then
        echo "Error: Unable to connect to IPMI interface on $HOST"
        exit 1
    fi
}

# Function to get current power status
get_power_status() {
    local status
    status=$(ipmitool -I lanplus -H "$HOST" -U "$USERNAME" -P "$PASSWORD" -p "$PORT" chassis power status)
    echo "$status"
}

# Function to power on system
power_on() {
    local current_status
    current_status=$(get_power_status)
    
    if [[ $current_status == *"on"* ]]; then
        echo "System is already powered on."
        return 0
    fi
    
    echo "Powering on system..."
    if ipmitool -I lanplus -H "$HOST" -U "$USERNAME" -P "$PASSWORD" -p "$PORT" chassis power on; then
        echo "Power-on command sent successfully."
        
        # Monitor power-on progress
        echo "Monitoring power-on progress..."
        for i in {1..12}; do
            sleep 5
            current_status=$(get_power_status)
            if [[ $current_status == *"on"* ]]; then
                echo "System has been powered on successfully."
                return 0
            fi
            echo "Still starting up... (attempt $i/12)"
        done
        echo "Warning: System power state could not be verified after 60 seconds."
        return 1
    else
        echo "Error: Failed to send power-on command."
        return 1
    fi
}

# Function to power off system
power_off() {
    local current_status
    current_status=$(get_power_status)
    
    if [[ $current_status == *"off"* ]]; then
        echo "System is already powered off."
        return 0
    fi
    
    echo "Initiating graceful shutdown..."
    if ipmitool -I lanplus -H "$HOST" -U "$USERNAME" -P "$PASSWORD" -p "$PORT" chassis power soft; then
        echo "Shutdown command sent successfully."
        
        # Monitor shutdown progress
        echo "Monitoring shutdown progress..."
        for i in {1..30}; do
            sleep 10
            current_status=$(get_power_status)
            if [[ $current_status == *"off"* ]]; then
                echo "System has been powered off successfully."
                return 0
            fi
            echo "Still shutting down... (attempt $i/30)"
        done
        
        echo "Warning: System did not power off within 5 minutes."
        if [ "$FORCE" = true ]; then
            response="y"
        else
            echo "Would you like to force power off? (y/n)"
            read -r response
        fi

        if [[ $response =~ ^[Yy]$ ]]; then
            echo "Forcing power off..."
            ipmitool -I lanplus -H "$HOST" -U "$USERNAME" -P "$PASSWORD" -p "$PORT" chassis power off

            
            # Check if force power off worked
            sleep 5
            current_status=$(get_power_status)
            if [[ $current_status == *"off"* ]]; then
                echo "System has been forcefully powered off."
                return 0
            else
                echo "Error: Failed to force power off system."
                return 1
            fi
        fi
    else
        echo "Error: Failed to send shutdown command."
        return 1
    fi
}

# Main execution
echo "Connecting to Dell IPMI interface on $HOST..."
check_connection

case "$ACTION" in
    "on")
        power_on
        ;;
    "off")
        power_off
        ;;
    "status")
        status=$(get_power_status)
        echo "Current power status: $status"
        ;;
    *)
        echo "Error: Invalid action '$ACTION'. Use 'on', 'off', or 'status'"
        usage
        ;;
esac