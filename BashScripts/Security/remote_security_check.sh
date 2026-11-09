#!/usr/bin/env bash
# =============================================================================
# remote_security_check.sh
#
# Remotely verifies that all security tools and configurations deployed by
# the scripts in this repository are properly installed and active:
#
#   1. Uptycs / osquery
#      - uptycs-protect package installed
#      - osqueryd service active & enabled
#      - osquery_tags table populated
#
#   2. TTY Session Recording & Secondary Logging
#      - audit package installed
#      - auditd service active & enabled
#      - pam_tty_audit.so rule present in PAM sshd config
#      - sudo logging drop-in present (/etc/sudoers.d/01-sudo-logging)
#      - sudo log file present (/var/log/sudo.log)
#
#   3. Rsyslog TLS forwarding to MAGNA collector
#      - rsyslog service active & enabled
#      - rsyslog drop-in config present (/etc/rsyslog.d/10-forward-to-collector.conf)
#      - IBM CA chain certificate present (/etc/pki/rsyslog/ibm-ca-chain.pem)
#      - TLS connectivity to collector (10.11.5.3:6514)
#
# Usage:
#   ./remote_security_check.sh <IP> [OPTIONS]
#
# Arguments:
#   <IP>               Remote host IP or hostname (required, first positional)
#
# Options:
#   --user <username>  Remote SSH user (default: root)
#   --pass <password>  SSH password (optional — uses sshpass; omit for SSH key auth)
#   --pam-file <file>  PAM config file to check for pam_tty_audit (default: /etc/pam.d/sshd)
#   --skip-uptycs      Skip Uptycs / osquery checks
#   --skip-tty         Skip TTY session recording checks
#   --skip-rsyslog     Skip rsyslog TLS forwarding checks
#   -h, --help         Show this help message
#
# Examples:
#   # Key-based authentication, check everything:
#   ./remote_security_check.sh 10.11.5.42
#
#   # Password authentication:
#   ./remote_security_check.sh 10.11.5.42 --pass "s3cr3t"
#
#   # Skip Uptycs checks, use a custom PAM file:
#   ./remote_security_check.sh 10.11.5.42 --skip-uptycs --pam-file /etc/pam.d/system-auth
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

# ── Banner ────────────────────────────────────────────────────────────────────
cat << "BANNER"


                ██╗██████╗ ███╗   ███╗
                ██║██╔══██╗████╗ ████║
                ██║██████╔╝██╔████╔██║
                ██║██╔══██╗██║╚██╔╝██║
                ██║██████╔╝██║ ╚═╝ ██║
                ╚═╝╚═════╝ ╚═╝     ╚═╝

                Montpellier zLinux Team

==============================================================
         Remote Security Configuration Checker
==============================================================
BANNER

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
    grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \?//'
    exit 0
}

# ── Argument parsing ──────────────────────────────────────────────────────────
if [[ $# -lt 1 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    [[ $# -lt 1 ]] && error "Remote host IP is required as the first argument."
    usage
fi

REMOTE_IP="$1"
shift

REMOTE_USER="root"
PASSWORD=""
PAM_TARGET_FILE="/etc/pam.d/sshd"

SKIP_UPTYCS=false
SKIP_TTY=false
SKIP_RSYSLOG=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)         REMOTE_USER="$2";     shift 2 ;;
        --pass)         PASSWORD="$2";        shift 2 ;;
        --pam-file)     PAM_TARGET_FILE="$2"; shift 2 ;;
        --skip-uptycs)  SKIP_UPTYCS=true;     shift 1 ;;
        --skip-tty)     SKIP_TTY=true;        shift 1 ;;
        --skip-rsyslog) SKIP_RSYSLOG=true;    shift 1 ;;
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

info "Target host : ${REMOTE_USER}@${REMOTE_IP}"
info "PAM file    : ${PAM_TARGET_FILE}"

# ── Run all checks on the remote host ────────────────────────────────────────
header "Running security checks on ${REMOTE_USER}@${REMOTE_IP}"

eval "${SSH_CMD} ${REMOTE_USER}@${REMOTE_IP}" <<ENDSSH
set -uo pipefail

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
fail()    { echo -e "\${RED}[FAIL]\${NC}  \$*"; }
header()  { echo -e "\n\${BOLD}\${CYAN}══════════════════════════════════════════════════\${NC}"; \\
            echo -e "\${BOLD}\${CYAN}  \$*\${NC}"; \\
            echo -e "\${BOLD}\${CYAN}══════════════════════════════════════════════════\${NC}"; }

if [[ "\${EUID}" -ne 0 ]]; then
    fail "Remote checks require root privileges."
    exit 1
fi

# Counters for final summary
CHECKS_PASSED=0
CHECKS_WARNED=0
CHECKS_FAILED=0

pass()  { success "\$*"; (( CHECKS_PASSED++ )) || true; }
warn_c(){ warn    "\$*"; (( CHECKS_WARNED++ )) || true; }
fail_c(){ fail    "\$*"; (( CHECKS_FAILED++ )) || true; }

# ── Variables injected from local script ──────────────────────────────────────
SKIP_UPTYCS="${SKIP_UPTYCS}"
SKIP_TTY="${SKIP_TTY}"
SKIP_RSYSLOG="${SKIP_RSYSLOG}"
PAM_TARGET_FILE="${PAM_TARGET_FILE}"

# ── CHECK 1: Uptycs / osquery ─────────────────────────────────────────────────
if [[ "\${SKIP_UPTYCS}" == "true" ]]; then
    header "CHECK 1 — Uptycs / osquery  [SKIPPED]"
    info "Skipping Uptycs checks (--skip-uptycs)."
else
    header "CHECK 1 — Uptycs / osquery"

    # 1a. Package installed
    info "Checking uptycs-protect package..."
    if rpm -q uptycs-protect &>/dev/null; then
        PKG_VER=\$(rpm -q uptycs-protect)
        pass "Package installed: \${PKG_VER}"
    else
        fail_c "Package 'uptycs-protect' is NOT installed."
    fi

    # 1b. osqueryd service active
    info "Checking osqueryd service state..."
    if systemctl is-active --quiet osqueryd 2>/dev/null; then
        pass "osqueryd service is active (running)."
    else
        fail_c "osqueryd service is NOT active."
        info "Service status:"
        systemctl status osqueryd --no-pager 2>/dev/null || true
    fi

    # 1c. osqueryd service enabled
    info "Checking osqueryd service enablement..."
    if systemctl is-enabled --quiet osqueryd 2>/dev/null; then
        pass "osqueryd service is enabled (starts at boot)."
    else
        warn_c "osqueryd service is NOT enabled at boot."
    fi

    # 1d. osquery_tags populated
    info "Querying osquery_tags table..."
    if command -v osqueryi &>/dev/null; then
        TAGS_OUTPUT=\$(osqueryi "select * from osquery_tags;" 2>/dev/null || true)
        echo "\${TAGS_OUTPUT}"
        if echo "\${TAGS_OUTPUT}" | grep -qE '\|[[:space:]]+[A-Z]'; then
            pass "osquery_tags table is populated."
        else
            warn_c "osquery_tags table appears empty — tags may not have been applied."
        fi
    else
        warn_c "osqueryi not found — cannot query osquery_tags table."
    fi
fi

# ── CHECK 2: TTY Session Recording & Secondary Logging ───────────────────────
if [[ "\${SKIP_TTY}" == "true" ]]; then
    header "CHECK 2 — TTY Session Recording & Secondary Logging  [SKIPPED]"
    info "Skipping TTY recording checks (--skip-tty)."
else
    header "CHECK 2 — TTY Session Recording & Secondary Logging"

    # 2a. audit package installed
    info "Checking 'audit' package..."
    if rpm -q audit &>/dev/null; then
        pass "Package installed: \$(rpm -q audit)"
    else
        fail_c "Package 'audit' is NOT installed."
    fi

    # 2b. auditd service active
    info "Checking auditd service state..."
    if systemctl is-active --quiet auditd 2>/dev/null || service auditd status &>/dev/null; then
        pass "auditd service is active (running)."
    else
        fail_c "auditd service is NOT active."
        info "Service status:"
        systemctl status auditd --no-pager 2>/dev/null || true
    fi

    # 2c. auditd service enabled
    info "Checking auditd service enablement..."
    if systemctl is-enabled --quiet auditd 2>/dev/null; then
        pass "auditd service is enabled (starts at boot)."
    else
        warn_c "auditd service is NOT enabled at boot."
    fi

    # 2d. pam_tty_audit rule in PAM config
    info "Checking pam_tty_audit rule in \${PAM_TARGET_FILE}..."
    if [[ -f "\${PAM_TARGET_FILE}" ]]; then
        if grep -E '^[[:space:]]*session[[:space:]]+.*pam_tty_audit\.so' "\${PAM_TARGET_FILE}" &>/dev/null; then
            PAM_RULE=\$(grep -E '^[[:space:]]*session[[:space:]]+.*pam_tty_audit\.so' "\${PAM_TARGET_FILE}" | head -1)
            pass "pam_tty_audit rule found in \${PAM_TARGET_FILE}:"
            info "  \${PAM_RULE}"
        else
            fail_c "pam_tty_audit.so rule NOT found in \${PAM_TARGET_FILE}."
        fi
    else
        fail_c "PAM config file not found: \${PAM_TARGET_FILE}"
    fi

    # 2e. sudo logging drop-in
    SUDOERS_DROPIN="/etc/sudoers.d/01-sudo-logging"
    info "Checking sudo logging drop-in \${SUDOERS_DROPIN}..."
    if [[ -f "\${SUDOERS_DROPIN}" ]]; then
        SUDO_LOG_CONF=\$(cat "\${SUDOERS_DROPIN}")
        pass "Sudo logging drop-in present:"
        info "  \${SUDO_LOG_CONF}"
        # Validate its syntax
        if visudo -cf "\${SUDOERS_DROPIN}" &>/dev/null; then
            pass "Sudoers drop-in syntax is valid."
        else
            warn_c "Sudoers drop-in has syntax issues (visudo -cf failed)."
        fi
    else
        fail_c "Sudo logging drop-in NOT found: \${SUDOERS_DROPIN}"
    fi

    # 2f. sudo log file exists
    SUDO_LOGFILE="/var/log/sudo.log"
    info "Checking sudo log file \${SUDO_LOGFILE}..."
    if [[ -f "\${SUDO_LOGFILE}" ]]; then
        PERMS=\$(stat -c "%a" "\${SUDO_LOGFILE}")
        pass "Sudo log file present (permissions: \${PERMS})."
        if [[ "\${PERMS}" == "600" ]]; then
            pass "Sudo log file permissions are 600 (secure)."
        else
            warn_c "Sudo log file permissions are \${PERMS} — expected 600."
        fi
    else
        warn_c "Sudo log file not yet created at \${SUDO_LOGFILE} (will appear after first sudo use)."
    fi
fi

# ── CHECK 3: Rsyslog TLS forwarding ──────────────────────────────────────────
if [[ "\${SKIP_RSYSLOG}" == "true" ]]; then
    header "CHECK 3 — Rsyslog TLS Forwarding  [SKIPPED]"
    info "Skipping rsyslog checks (--skip-rsyslog)."
else
    header "CHECK 3 — Rsyslog TLS Forwarding to MAGNA Collector"

    RSYSLOG_CONF="/etc/rsyslog.d/10-forward-to-collector.conf"
    CA_CHAIN="/etc/pki/rsyslog/ibm-ca-chain.pem"
    COLLECTOR_HOST="10.11.5.3"
    COLLECTOR_PORT="6514"

    # 3a. rsyslog service active
    info "Checking rsyslog service state..."
    if systemctl is-active --quiet rsyslog 2>/dev/null; then
        pass "rsyslog service is active (running)."
    else
        fail_c "rsyslog service is NOT active."
        info "Service status:"
        systemctl status rsyslog --no-pager 2>/dev/null || true
    fi

    # 3b. rsyslog service enabled
    info "Checking rsyslog service enablement..."
    if systemctl is-enabled --quiet rsyslog 2>/dev/null; then
        pass "rsyslog service is enabled (starts at boot)."
    else
        warn_c "rsyslog service is NOT enabled at boot."
    fi

    # 3c. rsyslog forwarding drop-in present
    info "Checking rsyslog forwarding config \${RSYSLOG_CONF}..."
    if [[ -f "\${RSYSLOG_CONF}" ]]; then
        pass "Rsyslog forwarding config present: \${RSYSLOG_CONF}"
        # Check it references the collector and TLS
        if grep -q "\${COLLECTOR_HOST}" "\${RSYSLOG_CONF}" && \
           grep -q "\${COLLECTOR_PORT}" "\${RSYSLOG_CONF}" && \
           grep -q "gtls" "\${RSYSLOG_CONF}"; then
            pass "Config references collector \${COLLECTOR_HOST}:\${COLLECTOR_PORT} with TLS (gtls)."
        else
            warn_c "Config exists but may be missing collector address, port, or TLS driver."
            info "Config content:"
            cat "\${RSYSLOG_CONF}"
        fi
    else
        fail_c "Rsyslog forwarding config NOT found: \${RSYSLOG_CONF}"
    fi

    # 3d. IBM CA chain certificate present
    info "Checking IBM CA chain certificate \${CA_CHAIN}..."
    if [[ -f "\${CA_CHAIN}" ]]; then
        CERT_SIZE=\$(wc -c < "\${CA_CHAIN}")
        pass "IBM CA chain certificate present (\${CERT_SIZE} bytes)."
        # Verify it is a valid PEM chain
        CERT_COUNT=\$(grep -c "BEGIN CERTIFICATE" "\${CA_CHAIN}" 2>/dev/null || echo 0)
        if [[ "\${CERT_COUNT}" -ge 2 ]]; then
            pass "CA chain contains \${CERT_COUNT} certificate(s) — chain looks complete."
        else
            warn_c "CA chain contains only \${CERT_COUNT} certificate(s) — expected at least 2 (intermediate + root)."
        fi
    else
        fail_c "IBM CA chain certificate NOT found: \${CA_CHAIN}"
    fi

    # 3e. TLS connectivity to collector
    info "Testing TLS connectivity to \${COLLECTOR_HOST}:\${COLLECTOR_PORT}..."
    if command -v openssl &>/dev/null; then
        if [[ -f "\${CA_CHAIN}" ]]; then
            OPENSSL_OUT=\$(openssl s_client \
                -connect "\${COLLECTOR_HOST}:\${COLLECTOR_PORT}" \
                -CAfile "\${CA_CHAIN}" \
                -brief \
                </dev/null 2>&1 || true)
            echo "\${OPENSSL_OUT}" | head -n 10
            if echo "\${OPENSSL_OUT}" | grep -q "SSL handshake has read"; then
                pass "TLS handshake successful with \${COLLECTOR_HOST}:\${COLLECTOR_PORT}."
            elif echo "\${OPENSSL_OUT}" | grep -qi "verify return:1\|Verification: OK\|connected\|CONNECTED"; then
                pass "TLS connection established with \${COLLECTOR_HOST}:\${COLLECTOR_PORT}."
            else
                warn_c "TLS connection to \${COLLECTOR_HOST}:\${COLLECTOR_PORT} may have issues — check output above."
            fi
        else
            warn_c "Skipping TLS connectivity test — CA chain not present."
        fi
    else
        warn_c "openssl not found — cannot test TLS connectivity."
    fi
fi

# ── SUMMARY ───────────────────────────────────────────────────────────────────
header "SUMMARY — \$(hostname)"

echo ""
printf "  %-36s %s\n" "Host:"                  "\$(hostname) (\$(hostname -I | awk '{print \$1}'))"
printf "  %-36s %s\n" "Kernel:"                "\$(uname -r)"
printf "  %-36s %s\n" "OS:"                    "\$(cat /etc/redhat-release 2>/dev/null || uname -o)"
echo ""

# Uptycs
if [[ "\${SKIP_UPTYCS}" != "true" ]]; then
    printf "  %-36s %s\n" "uptycs-protect package:" \
        "\$(rpm -q uptycs-protect 2>/dev/null || echo 'NOT INSTALLED')"
    printf "  %-36s %s\n" "osqueryd service:" \
        "\$(systemctl is-active osqueryd 2>/dev/null || echo 'unknown')"
    printf "  %-36s %s\n" "osqueryd enabled at boot:" \
        "\$(systemctl is-enabled osqueryd 2>/dev/null || echo 'unknown')"
fi

# TTY Recording
if [[ "\${SKIP_TTY}" != "true" ]]; then
    printf "  %-36s %s\n" "audit package:" \
        "\$(rpm -q audit 2>/dev/null || echo 'NOT INSTALLED')"
    printf "  %-36s %s\n" "auditd service:" \
        "\$(systemctl is-active auditd 2>/dev/null || echo 'unknown')"
    printf "  %-36s %s\n" "pam_tty_audit rule (\${PAM_TARGET_FILE}):" \
        "\$(grep -qE '^[[:space:]]*session[[:space:]]+.*pam_tty_audit\.so' "\${PAM_TARGET_FILE}" 2>/dev/null && echo 'PRESENT' || echo 'MISSING')"
    printf "  %-36s %s\n" "sudo logging drop-in:" \
        "\$([[ -f /etc/sudoers.d/01-sudo-logging ]] && echo 'PRESENT' || echo 'MISSING')"
fi

# Rsyslog
if [[ "\${SKIP_RSYSLOG}" != "true" ]]; then
    printf "  %-36s %s\n" "rsyslog service:" \
        "\$(systemctl is-active rsyslog 2>/dev/null || echo 'unknown')"
    printf "  %-36s %s\n" "rsyslog forwarding config:" \
        "\$([[ -f /etc/rsyslog.d/10-forward-to-collector.conf ]] && echo 'PRESENT' || echo 'MISSING')"
    printf "  %-36s %s\n" "IBM CA chain cert:" \
        "\$([[ -f /etc/pki/rsyslog/ibm-ca-chain.pem ]] && echo 'PRESENT' || echo 'MISSING')"
fi

echo ""
printf "  %-36s %s\n" "Checks passed:"  "\${CHECKS_PASSED}"
printf "  %-36s %s\n" "Warnings:"       "\${CHECKS_WARNED}"
printf "  %-36s %s\n" "Checks failed:"  "\${CHECKS_FAILED}"
echo ""

if [[ "\${CHECKS_FAILED}" -eq 0 && "\${CHECKS_WARNED}" -eq 0 ]]; then
    success "All security checks PASSED — system is fully compliant."
elif [[ "\${CHECKS_FAILED}" -eq 0 ]]; then
    warn "All mandatory checks passed, but \${CHECKS_WARNED} warning(s) require attention."
else
    fail  "Security check completed with \${CHECKS_FAILED} failure(s) and \${CHECKS_WARNED} warning(s)."
    exit 1
fi
ENDSSH

success "Remote security check completed on ${REMOTE_IP}."
