#!/usr/bin/env bash
# =============================================================================
# remote_install_tty_recording.sh
#
# Remotely automates the configuration of Secondary Logging & TTY Session
# Recording on Linux systems over SSH.
#
# Tasks executed on the remote host:
#   1. Sudo command logging configuration (/var/log/sudo.log via /etc/sudoers.d/)
#   2. Audit package installation, auditd service enablement & startup
#   3. PAM TTY Session Recording enablement (/etc/pam.d/sshd via pam_tty_audit.so)
#   4. Post-configuration verification & report (visudo, auditd status, aureport)
#
# Usage:
#   ./remote_install_tty_recording.sh <IP> [OPTIONS]
#
# Arguments:
#   <IP>               Remote host IP or hostname (required, first positional)
#
# Options:
#   --user <username>  Remote SSH user (default: root)
#   --pass <password>  SSH password (optional — uses sshpass; omit for SSH key auth)
#   --logfile <path>   Custom path for sudo logfile (default: /var/log/sudo.log)
#   --pam-file <file>  PAM configuration file to target (default: /etc/pam.d/sshd)
#   --enable-users     Users pattern to audit in pam_tty_audit (default: "*")
#   --skip-sudo        Skip sudo logging configuration
#   --skip-auditd      Skip auditd installation & enablement
#   --skip-tty         Skip PAM TTY session recording configuration
#   -h, --help         Show this help message
#
# Examples:
#   # Key-based authentication:
#   ./remote_install_tty_recording.sh 10.11.5.42
#
#   # Password authentication with custom options:
#   ./remote_install_tty_recording.sh 10.11.5.42 --pass "secret" --enable-users "*"
# =============================================================================

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
header()  { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════════════${NC}"; \
            echo -e "${BOLD}${CYAN}  $*${NC}"; \
            echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════${NC}"; }

usage() {
    grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \?//'
    exit 0
}

if [[ $# -lt 1 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    [[ $# -lt 1 ]] && error "Remote host IP is required as the first argument."
    usage
fi

REMOTE_IP="$1"
shift

# ── Defaults ──────────────────────────────────────────────────────────────────
REMOTE_USER="root"
PASSWORD=""
SUDO_LOGFILE="/var/log/sudo.log"
PAM_TARGET_FILE="/etc/pam.d/sshd"
TTY_AUDIT_USERS="*"

SKIP_SUDO=false
SKIP_AUDITD=false
SKIP_TTY=false

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)         REMOTE_USER="$2";       shift 2 ;;
        --pass)         PASSWORD="$2";          shift 2 ;;
        --logfile)      SUDO_LOGFILE="$2";      shift 2 ;;
        --pam-file)     PAM_TARGET_FILE="$2";   shift 2 ;;
        --enable-users) TTY_AUDIT_USERS="$2";   shift 2 ;;
        --skip-sudo)    SKIP_SUDO=true;         shift 1 ;;
        --skip-auditd)  SKIP_AUDITD=true;       shift 1 ;;
        --skip-tty)     SKIP_TTY=true;          shift 1 ;;
        -h|--help)      usage ;;
        *)              error "Unknown option: $1"; usage ;;
    esac
done

# ── Build SSH command ─────────────────────────────────────────────────────────
if [[ -n "${PASSWORD}" ]]; then
    if ! command -v sshpass &>/dev/null; then
        error "sshpass is not installed. Install it with: dnf install -y sshpass"
        exit 1
    fi
    SSH_CMD="sshpass -p '${PASSWORD}' ssh -o StrictHostKeyChecking=no"
else
    SSH_CMD="ssh -o StrictHostKeyChecking=no"
fi

# ── Execute configuration remotely ───────────────────────────────────────────
header "Running TTY Recording setup on ${REMOTE_USER}@${REMOTE_IP}"

eval "${SSH_CMD} ${REMOTE_USER}@${REMOTE_IP}" <<ENDSSH
set -euo pipefail

# ── Colour helpers (remote) ───────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "\${CYAN}[INFO]\${NC}  \$*"; }
success() { echo -e "\${GREEN}[OK]\${NC}    \$*"; }
warn()    { echo -e "\${YELLOW}[WARN]\${NC}  \$*"; }
error()   { echo -e "\${RED}[ERROR]\${NC} \$*" >&2; }
header()  { echo -e "\n\${BOLD}\${CYAN}══════════════════════════════════════════════════\${NC}"; \\
            echo -e "\${BOLD}\${CYAN}  \$*\${NC}"; \\
            echo -e "\${BOLD}\${CYAN}══════════════════════════════════════════════════\${NC}"; }

if [[ "\${EUID}" -ne 0 ]]; then
    error "Remote operations require root privileges."
    exit 1
fi

SUDO_LOGFILE="${SUDO_LOGFILE}"
SUDOERS_DROPIN="/etc/sudoers.d/01-sudo-logging"
PAM_TARGET_FILE="${PAM_TARGET_FILE}"
TTY_AUDIT_USERS="${TTY_AUDIT_USERS}"
SKIP_SUDO="${SKIP_SUDO}"
SKIP_AUDITD="${SKIP_AUDITD}"
SKIP_TTY="${SKIP_TTY}"

# ── STEP 1: Enable sudo Command Logging ───────────────────────────────────────
header "STEP 1 — Enable sudo Command Logging"

if [[ "\${SKIP_SUDO}" = "true" ]]; then
    info "Skipping sudo logging configuration."
else
    info "Configuring sudo logfile: \${SUDO_LOGFILE}"
    mkdir -p /etc/sudoers.d
    chmod 750 /etc/sudoers.d

    TMP_SUDOERS=\$(mktemp /tmp/sudoers_logging.XXXXXX)
    echo "Defaults logfile=\"\${SUDO_LOGFILE}\"" > "\${TMP_SUDOERS}"

    if visudo -cf "\${TMP_SUDOERS}" &>/dev/null; then
        install -m 0440 "\${TMP_SUDOERS}" "\${SUDOERS_DROPIN}"
        rm -f "\${TMP_SUDOERS}"
        success "Sudo logging drop-in installed at: \${SUDOERS_DROPIN}"
    else
        rm -f "\${TMP_SUDOERS}"
        error "Validation failed for sudoers drop-in configuration. Aborting."
        exit 1
    fi

    if [[ ! -f "\${SUDO_LOGFILE}" ]]; then
        touch "\${SUDO_LOGFILE}"
        chmod 600 "\${SUDO_LOGFILE}"
        info "Created \${SUDO_LOGFILE} with 0600 permissions."
    fi

    if visudo -c &>/dev/null; then
        success "Global sudoers configuration is valid."
    else
        warn "visudo -c returned warnings or errors."
    fi
fi

# ── STEP 2: Enable and Start auditd ───────────────────────────────────────────
header "STEP 2 — Enable and Start auditd"

if [[ "\${SKIP_AUDITD}" = "true" ]]; then
    info "Skipping auditd configuration."
else
    if ! rpm -q audit &>/dev/null; then
        info "Package 'audit' not found. Installing via package manager..."
        if command -v dnf &>/dev/null; then
            dnf install -y audit
        elif command -v yum &>/dev/null; then
            yum install -y audit
        else
            error "Neither dnf nor yum was found."
            exit 1
        fi
        success "Package 'audit' installed."
    else
        success "Package 'audit' is already installed (\$(rpm -q audit))."
    fi

    info "Enabling and starting auditd service..."
    systemctl enable auditd 2>/dev/null || true

    if ! systemctl is-active --quiet auditd; then
        systemctl start auditd 2>/dev/null || service auditd start || true
    fi

    if systemctl is-active --quiet auditd; then
        success "auditd is active and running."
    else
        if service auditd status &>/dev/null; then
            success "auditd is running (via service)."
        else
            error "auditd failed to start. Check 'journalctl -u auditd'."
            exit 1
        fi
    fi
fi

# ── STEP 3: Enable TTY Session Recording (pam_tty_audit) ───────────────────────
header "STEP 3 — Enable TTY Session Recording (pam_tty_audit)"

if [[ "\${SKIP_TTY}" = "true" ]]; then
    info "Skipping TTY session recording configuration."
else
    if [[ ! -f "\${PAM_TARGET_FILE}" ]]; then
        error "PAM configuration file not found: \${PAM_TARGET_FILE}"
        exit 1
    fi

    PAM_RULE="session    required     pam_tty_audit.so enable=\${TTY_AUDIT_USERS}"
    info "Target PAM file: \${PAM_TARGET_FILE}"
    info "PAM audit rule: \${PAM_RULE}"

    if grep -E '^[[:space:]]*session[[:space:]]+.*pam_tty_audit\.so' "\${PAM_TARGET_FILE}" >/dev/null; then
        CURRENT_LINE=\$(grep -E '^[[:space:]]*session[[:space:]]+.*pam_tty_audit\.so' "\${PAM_TARGET_FILE}" | head -1)
        info "pam_tty_audit rule already exists in \${PAM_TARGET_FILE}:"
        echo "       \${CURRENT_LINE}"
        success "TTY session recording is already configured in PAM."
    else
        BACKUP_FILE="\${PAM_TARGET_FILE}.bak.\$(date +%Y%m%d%H%M%S)"
        cp -p "\${PAM_TARGET_FILE}" "\${BACKUP_FILE}"
        info "Created backup: \${BACKUP_FILE}"

        if grep -q '^[[:space:]]*session' "\${PAM_TARGET_FILE}"; then
            LAST_SESSION_LINE=\$(grep -n '^[[:space:]]*session' "\${PAM_TARGET_FILE}" | tail -1 | cut -d: -f1)
            sed -i "\${LAST_SESSION_LINE}a \${PAM_RULE}" "\${PAM_TARGET_FILE}"
        else
            echo -e "\n# TTY Session Recording\n\${PAM_RULE}" >> "\${PAM_TARGET_FILE}"
        fi

        success "pam_tty_audit rule successfully added to \${PAM_TARGET_FILE}."
    fi
fi

# ── STEP 4: Verification and Sanity Checks ────────────────────────────────────
header "STEP 4 — Verification and Sanity Checks"

info "Checking sudo configuration:"
if sudo -V 2>/dev/null | grep -i "log" | head -2; then
    true
fi
if [[ -f "\${SUDO_LOGFILE}" ]]; then
    success "Sudo log file present: \${SUDO_LOGFILE}"
else
    warn "Sudo log file not yet created at: \${SUDO_LOGFILE}"
fi

info "Checking auditd daemon status:"
systemctl status auditd --no-pager || true

info "Querying recent audit records (ausearch -ts recent):"
ausearch -ts recent 2>/dev/null | head -n 15 || true

info "Querying TTY report (aureport --tty):"
aureport --tty 2>/dev/null | head -n 20 || true

# ── SUMMARY ───────────────────────────────────────────────────────────────────
header "SUMMARY"

echo ""
printf "  %-32s %s\n" "Host:"                      "\$(hostname)"
printf "  %-32s %s\n" "Sudo logging:"             "\$([[ -f \${SUDOERS_DROPIN} ]] && echo "Enabled (\${SUDO_LOGFILE})" || echo "Disabled/Skipped")"
printf "  %-32s %s\n" "auditd service:"           "\$(systemctl is-active auditd 2>/dev/null || echo 'inactive')"
printf "  %-32s %s\n" "TTY recording (PAM):"      "\$(grep -q 'pam_tty_audit.so' "\${PAM_TARGET_FILE}" 2>/dev/null && echo "Enabled in \${PAM_TARGET_FILE}" || echo "Disabled/Skipped")"
echo ""

success "Secondary Logging & TTY Session Recording configuration completed on \$(hostname)."
ENDSSH

success "Remote deployment completed successfully on ${REMOTE_IP}."
