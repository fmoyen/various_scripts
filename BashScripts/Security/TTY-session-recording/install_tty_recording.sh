#!/usr/bin/env bash
# =============================================================================
# install_tty_recording.sh
#
# Automates the configuration of Secondary Logging & TTY Session Recording
# on Linux systems (RHEL / CentOS / Rocky / Alma / IBM zSystems s390x / x86_64).
#
# Implemented Actions:
#   1. Enable sudo Command Logging
#      - Adds 'Defaults logfile="/var/log/sudo.log"' safely via /etc/sudoers.d/
#      - Validates syntax using visudo -cf
#   2. Enable and Start auditd
#      - Installs 'audit' package if missing (via dnf / yum)
#      - Enables and starts auditd service (handles service/systemctl semantics)
#   3. Enable TTY Session Recording via PAM (pam_tty_audit)
#      - Configures pam_tty_audit.so enable=* in /etc/pam.d/sshd (or system-auth/password-auth)
#      - Idempotent: checks before inserting and creates backups
#   4. Post-configuration Validation
#      - Validates sudo log config, auditd running status, ausearch, and aureport --tty
#
# Usage:
#   sudo ./install_tty_recording.sh [OPTIONS]
#
# Options:
#   --logfile <path>   Custom path for sudo logfile (default: /var/log/sudo.log)
#   --pam-file <file>  PAM configuration file to target (default: /etc/pam.d/sshd)
#   --enable-users     Users pattern to audit in pam_tty_audit (default: "*")
#   --skip-sudo        Skip sudo logging configuration
#   --skip-auditd      Skip auditd installation & enablement
#   --skip-tty         Skip PAM TTY session recording configuration
#   -h, --help         Show this help message
#
# Examples:
#   sudo ./install_tty_recording.sh
#   sudo ./install_tty_recording.sh --logfile /var/log/sudo.log --enable-users "*"
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

# ── Root privilege check ──────────────────────────────────────────────────────
if [[ "${EUID}" -ne 0 ]]; then
    error "This script must be run as root (sudo)."
    exit 1
fi

# ── Default settings ──────────────────────────────────────────────────────────
SUDO_LOGFILE="/var/log/sudo.log"
SUDOERS_DROPIN="/etc/sudoers.d/01-sudo-logging"
PAM_TARGET_FILE="/etc/pam.d/sshd"
TTY_AUDIT_USERS="*"

SKIP_SUDO=false
SKIP_AUDITD=false
SKIP_TTY=false

usage() {
    grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \?//'
    exit 0
}

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
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

# ── STEP 1: Enable sudo Command Logging ───────────────────────────────────────
header "STEP 1 — Enable sudo Command Logging"

if [[ "${SKIP_SUDO}" = true ]]; then
    info "Skipping sudo logging configuration (--skip-sudo)."
else
    info "Configuring sudo logfile: ${SUDO_LOGFILE}"

    # Ensure /etc/sudoers.d directory exists and has 0750 permissions
    mkdir -p /etc/sudoers.d
    chmod 750 /etc/sudoers.d

    # Create temporary drop-in file
    TMP_SUDOERS=$(mktemp /tmp/sudoers_logging.XXXXXX)
    echo "Defaults logfile=\"${SUDO_LOGFILE}\"" > "${TMP_SUDOERS}"

    # Validate syntax with visudo
    if visudo -cf "${TMP_SUDOERS}" &>/dev/null; then
        # Install drop-in file with strict permissions (0440)
        install -m 0440 "${TMP_SUDOERS}" "${SUDOERS_DROPIN}"
        rm -f "${TMP_SUDOERS}"
        success "Sudo logging drop-in installed at: ${SUDOERS_DROPIN}"
    else
        rm -f "${TMP_SUDOERS}"
        error "Validation failed for sudoers drop-in configuration. Aborting sudo step."
        exit 1
    fi

    # Ensure log file exists with proper restrictive permissions
    if [[ ! -f "${SUDO_LOGFILE}" ]]; then
        touch "${SUDO_LOGFILE}"
        chmod 600 "${SUDO_LOGFILE}"
        info "Created ${SUDO_LOGFILE} with 0600 permissions."
    fi

    # Verify sudoers configuration syntax
    if visudo -c &>/dev/null; then
        success "Global sudoers configuration is valid."
    else
        warn "visudo -c returned warnings or errors. Check /etc/sudoers and /etc/sudoers.d/"
    fi
fi

# ── STEP 2: Enable and Start auditd ───────────────────────────────────────────
header "STEP 2 — Enable and Start auditd"

if [[ "${SKIP_AUDITD}" = true ]]; then
    info "Skipping auditd configuration (--skip-auditd)."
else
    # Check if audit package is installed
    if ! rpm -q audit &>/dev/null; then
        info "Package 'audit' not found. Installing via package manager..."
        if command -v dnf &>/dev/null; then
            dnf install -y audit
        elif command -v yum &>/dev/null; then
            yum install -y audit
        else
            error "Neither dnf nor yum was found. Please install the 'audit' package manually."
            exit 1
        fi
        success "Package 'audit' installed."
    else
        success "Package 'audit' is already installed ($(rpm -q audit))."
    fi

    # Enable and start auditd
    info "Enabling and starting auditd service..."
    systemctl enable auditd 2>/dev/null || true

    # auditd service management sometimes refuses 'systemctl restart/start auditd' directly on some distros
    if ! systemctl is-active --quiet auditd; then
        systemctl start auditd 2>/dev/null || service auditd start || true
    fi

    if systemctl is-active --quiet auditd; then
        success "auditd is active and running."
    else
        # Try service command fallback for systems with custom auditd service restrictions
        if service auditd status &>/dev/null; then
            success "auditd is running (via service)."
        else
            error "auditd failed to start. Check 'journalctl -u auditd' or '/var/log/audit/audit.log'."
            exit 1
        fi
    fi
fi

# ── STEP 3: Enable TTY Session Recording (pam_tty_audit) ───────────────────────
header "STEP 3 — Enable TTY Session Recording (pam_tty_audit)"

if [[ "${SKIP_TTY}" = true ]]; then
    info "Skipping TTY session recording configuration (--skip-tty)."
else
    if [[ ! -f "${PAM_TARGET_FILE}" ]]; then
        error "PAM configuration file not found: ${PAM_TARGET_FILE}"
        exit 1
    fi

    PAM_RULE="session    required     pam_tty_audit.so enable=${TTY_AUDIT_USERS}"
    info "Target PAM file: ${PAM_TARGET_FILE}"
    info "PAM audit rule: ${PAM_RULE}"

    # Check if pam_tty_audit is already present in target PAM file
    if grep -E '^[[:space:]]*session[[:space:]]+.*pam_tty_audit\.so' "${PAM_TARGET_FILE}" >/dev/null; then
        CURRENT_LINE=$(grep -E '^[[:space:]]*session[[:space:]]+.*pam_tty_audit\.so' "${PAM_TARGET_FILE}" | head -1)
        info "pam_tty_audit rule already exists in ${PAM_TARGET_FILE}:"
        echo "       ${CURRENT_LINE}"
        success "TTY session recording is already configured in PAM."
    else
        # Create a timestamped backup of the PAM configuration file
        BACKUP_FILE="${PAM_TARGET_FILE}.bak.$(date +%Y%m%d%H%M%S)"
        cp -p "${PAM_TARGET_FILE}" "${BACKUP_FILE}"
        info "Created backup: ${BACKUP_FILE}"

        # Insert the rule after the last 'session' directive or append to the session section
        if grep -q '^[[:space:]]*session' "${PAM_TARGET_FILE}"; then
            # Insert after the last session line
            LAST_SESSION_LINE=$(grep -n '^[[:space:]]*session' "${PAM_TARGET_FILE}" | tail -1 | cut -d: -f1)
            sed -i "${LAST_SESSION_LINE}a ${PAM_RULE}" "${PAM_TARGET_FILE}"
        else
            # Append if no session lines were found
            echo -e "\n# TTY Session Recording\n${PAM_RULE}" >> "${PAM_TARGET_FILE}"
        fi

        success "pam_tty_audit rule successfully added to ${PAM_TARGET_FILE}."
    fi
fi

# ── STEP 4: Verification and Sanity Checks ────────────────────────────────────
header "STEP 4 — Verification and Sanity Checks"

# 4a. Verify sudo log configuration
info "Checking sudo configuration:"
if sudo -V 2>/dev/null | grep -i "log" | head -2; then
    true
fi
if [[ -f "${SUDO_LOGFILE}" ]]; then
    success "Sudo log file present: ${SUDO_LOGFILE}"
else
    warn "Sudo log file not yet created at: ${SUDO_LOGFILE}"
fi

# 4b. Verify auditd status
info "Checking auditd daemon status:"
systemctl status auditd --no-pager || true

# 4c. Verify recent audit events
info "Querying recent audit records (ausearch -ts recent):"
ausearch -ts recent 2>/dev/null | head -n 15 || true

# 4d. Check aureport TTY status
info "Querying TTY report (aureport --tty):"
aureport --tty 2>/dev/null | head -n 20 || true

# ── SUMMARY ───────────────────────────────────────────────────────────────────
header "SUMMARY"

echo ""
printf "  %-32s %s\n" "Host:"                      "$(hostname)"
printf "  %-32s %s\n" "Sudo logging:"             "$([[ -f ${SUDOERS_DROPIN} ]] && echo "Enabled (${SUDO_LOGFILE})" || echo "Disabled/Skipped")"
printf "  %-32s %s\n" "auditd service:"           "$(systemctl is-active auditd 2>/dev/null || echo 'inactive')"
printf "  %-32s %s\n" "TTY recording (PAM):"      "$(grep -q 'pam_tty_audit.so' "${PAM_TARGET_FILE}" 2>/dev/null && echo "Enabled in ${PAM_TARGET_FILE}" || echo "Disabled/Skipped")"
echo ""

success "Secondary Logging & TTY Session Recording installation complete."
