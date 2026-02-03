#!/bin/bash

################################################################################
# Script: gather_linux_infos.bash
# Description: Gathers comprehensive Linux platform and software information
# Usage: ./gather_linux_infos.bash [-o|--output]
#        -o, --output : Save output to timestamped file
################################################################################

# Variables
SAVE_TO_FILE=false
OUTPUT_FILE=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            SAVE_TO_FILE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [-o|--output]"
            echo "  -o, --output : Save output to timestamped file"
            echo "  -h, --help   : Display this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Function to display separator
display_separator() {
    echo "======================================================="
}

# Function to gather platform information
gather_platform_info() {
    echo
    display_separator
    echo "=== PLATFORM INFORMATION ==="
    display_separator
    
    # OS Release
    echo
    echo "OS Release:"
    if [ -f /etc/os-release ]; then
        cat /etc/os-release
    else
        echo "  /etc/os-release not found"
    fi
    
    # Kernel Information
    echo
    echo "Kernel:"
    uname -a
    
    # Memory Information
    echo
    echo "Total Memory:"
    free -h | grep Mem | awk '{print "  " $2}'
    
    # CPU Cores
    echo
    echo "CPU Cores:"
    if command -v nproc >/dev/null 2>&1; then
        echo "  $(nproc) cores"
    elif command -v lscpu >/dev/null 2>&1; then
        lscpu | grep "^CPU(s):" | awk '{print "  " $2 " cores"}'
    else
        echo "  Unable to determine CPU cores"
    fi
    
    # Disk Space (root partition)
    echo
    echo "Disk Space (root partition):"
    df -h / | tail -n 1 | awk '{print "  Size: " $2 ", Used: " $3 ", Available: " $4 ", Use%: " $5}'
    
    # System Uptime
    echo
    echo "System Uptime:"
    if command -v uptime >/dev/null 2>&1; then
        uptime -p | sed 's/^/  /'
    else
        uptime | sed 's/^/  /'
    fi
}

# Function to gather software information
gather_software_info() {
    echo
    display_separator
    echo "=== SOFTWARE INFORMATION ==="
    display_separator
    
    # Current Shell
    echo
    echo "Current Shell:"
    echo "  $SHELL"
    
    # Node.js Information
    echo
    if command -v node >/dev/null 2>&1; then
        echo "Node.js Version:"
        node -v | sed 's/^/  /'
        
        echo
        echo "Node.js Platform:"
        node -p "process.platform" | sed 's/^/  /'
        
        echo
        echo "Node.js Architecture:"
        node -p "process.arch" | sed 's/^/  /'
    else
        echo "Node.js: Not installed"
    fi
}

# Main execution
main() {
    # Generate timestamp
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Display header
    echo
    display_separator
    echo "LINUX SYSTEM INFORMATION"
    echo "Generated: $TIMESTAMP"
    display_separator
    
    # Gather information
    gather_platform_info
    gather_software_info
    
    # Display footer
    echo
    display_separator
    echo
}

# Execute main function and optionally save to file
if [ "$SAVE_TO_FILE" = true ]; then
    OUTPUT_FILE="linux_info_$(date '+%Y-%m-%d_%H-%M-%S').txt"
    main | tee "$OUTPUT_FILE"
    echo "Output saved to: $OUTPUT_FILE"
else
    main
fi

# Made with Bob
