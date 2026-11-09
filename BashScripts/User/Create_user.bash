#!/bin/bash

# Exit on error, undefined vars, error in pipes
set -euo pipefail

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Create a new user, a dedicated group, and specified UID/GID.

Options:
    -n, --name USERNAME    Username to create (e.g., jdoe)
    -e, --email EMAIL      User email address for comment (e.g., jdoe@example.com)
    -i, --id UID_GID       Numeric ID to use for UID and GID (optional, defaults to first free ID >= 1000)
    -h, --help             Display this help message and exit

If options are not provided via command-line arguments, the script will prompt for them interactively (leaving ID blank will auto-assign the first free ID >= 1000).
EOF
}

# Require root privileges to manage users and groups
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root or with sudo." >&2
    exit 1
fi

myname=""
myemail=""
myid=""

# Parse command line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -n|--name)
            if [[ -z "${2:-}" || "$2" == -* ]]; then
                echo "Error: --name requires a non-empty argument." >&2
                exit 1
            fi
            myname="$2"
            shift 2
            ;;
        -e|--email)
            if [[ -z "${2:-}" || "$2" == -* ]]; then
                echo "Error: --email requires a non-empty argument." >&2
                exit 1
            fi
            myemail="$2"
            shift 2
            ;;
        -i|--id)
            if [[ -z "${2:-}" || "$2" == -* ]]; then
                echo "Error: --id requires a non-empty argument." >&2
                exit 1
            fi
            myid="$2"
            shift 2
            ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            usage
            exit 1
            ;;
    esac
done

# Prompt interactively if parameters were not provided
if [[ -z "$myname" ]]; then
    read -rp "Enter username: " myname
fi

if [[ -z "$myemail" ]]; then
    read -rp "Enter email address: " myemail
fi

if [[ -z "$myid" ]]; then
    read -rp "Enter numeric UID/GID (leave blank for first available >= 1000): " myid
fi

# Validate username and email are not empty
if [[ -z "$myname" || -z "$myemail" ]]; then
    echo "Error: Username and email must be provided." >&2
    exit 1
fi

# Check if user with the same name exists
if getent passwd "$myname" >/dev/null 2>&1; then
    echo "Error: User with name '$myname' already exists." >&2
    exit 1
fi

# Check if group with the same name exists
if getent group "$myname" >/dev/null 2>&1; then
    echo "Error: Group with name '$myname' already exists." >&2
    exit 1
fi

# If ID was provided, validate and check availability; otherwise, find the first available starting from 1000
if [[ -n "$myid" ]]; then
    if ! [[ "$myid" =~ ^[0-9]+$ ]]; then
        echo "Error: ID '$myid' is not a valid numeric integer." >&2
        exit 1
    fi

    if getent passwd "$myid" >/dev/null 2>&1; then
        echo "Error: User with UID '$myid' already exists." >&2
        exit 1
    fi

    if getent group "$myid" >/dev/null 2>&1; then
        echo "Error: Group with GID '$myid' already exists." >&2
        exit 1
    fi
else
    candidate_id=1000
    while getent passwd "$candidate_id" >/dev/null 2>&1 || getent group "$candidate_id" >/dev/null 2>&1; do
        ((candidate_id++))
    done
    myid="$candidate_id"
    echo "Auto-selected available UID/GID: $myid"
fi

# Create group (works across both RHEL/CentOS and Debian/Ubuntu)
echo "Creating group '$myname' with GID $myid..."
if command -v groupadd >/dev/null 2>&1; then
    groupadd -g "$myid" "$myname"
elif command -v addgroup >/dev/null 2>&1; then
    addgroup --gid "$myid" "$myname"
else
    echo "Error: Neither groupadd nor addgroup was found." >&2
    exit 1
fi

# Create user with home directory, shell, comment, UID and primary GID
echo "Creating user '$myname' with UID $myid and GID $myid..."
if command -v useradd >/dev/null 2>&1; then
    useradd -u "$myid" -g "$myid" -m -d "/home/$myname" -s /bin/bash -c "$myemail" "$myname"
elif command -v adduser >/dev/null 2>&1; then
    adduser --uid "$myid" --gid "$myid" --home "/home/$myname" --shell /bin/bash --gecos "$myemail" --disabled-password "$myname"
else
    echo "Error: Neither useradd nor adduser was found." >&2
    exit 1
fi

# Set password for the created user securely using passwd
echo
echo "Setting password for user '$myname'..."
passwd "$myname"

echo
echo "User '$myname' created and configured successfully."
echo

echo "=== /etc/passwd entry ==="
getent passwd "$myname" || true

echo
echo "=== /etc/group entry ==="
getent group "$myname" || true

echo
echo "=== id output ==="
id "$myname"
