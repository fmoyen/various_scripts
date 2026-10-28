#!/usr/bin/env bash
# =============================================================================
# remote_uptycs_install.sh
#
# Remotely automates the Uptycs (osquery) uninstallation, re-installation,
# tag configuration and post-install verification on RHEL / IBM s390x systems.
#
# The RPM is copied to the remote host via SCP, then all install phases are
# executed over SSH (no agent binary required on the local machine).
#
# Usage:
#   ./remote_uptycs_install.sh --host <IP> --rpm <path-to-rpm> [OPTIONS]
#
# Options:
#   --host  <IP>     Remote host IP or hostname                               (required)
#   --rpm   <path>   Path to the uptycs-protect RPM file on the LOCAL machine (required)
#   --tags  <tags>   osquery_tags string (optional)
#                    Default: "UPDATE/PROD, UT/TechZone, CCODE/TechZone, DATACENTER/MOP"
#                    Example: "UPDATE/PROD, UT/TechZone, CCODE/TechZone, DATACENTER/MOP"
#   --pass  <pwd>    SSH password (optional — uses sshpass; omit to use key-based auth)
#   -h|--help        Show this help message
#
# Examples:
#   # Key-based auth, default tags:
#   ./remote_uptycs_install.sh \
#       --host 10.0.0.42 \
#       --rpm ./assets-uptycs-protect-5.23.1.7-Uptycs.s390x.rpm
#
#   # Password auth, custom tags:
#   ./remote_uptycs_install.sh \
#       --host 10.0.0.42 \
#       --rpm ./assets-uptycs-protect-5.23.1.7-Uptycs.s390x.rpm \
#       --pass "s3cr3t" \
#       --tags "UPDATE/PROD, UT/TechZone, CCODE/TechZone, DATACENTER/MOP"
#
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

# ── Argument parsing ──────────────────────────────────────────────────────────
usage() {
    grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \?//'
    exit 0
}

RPM_PATH=""
REMOTE_IP=""
DEFAULT_TAGS="UPDATE/PROD, UT/TechZone, CCODE/TechZone, DATACENTER/MOP"
OSQUERY_TAGS=""
PASSWORD=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)  REMOTE_IP="$2";   shift 2 ;;
        --rpm)   RPM_PATH="$2";    shift 2 ;;
        --tags)  OSQUERY_TAGS="$2"; shift 2 ;;
        --pass)  PASSWORD="$2";    shift 2 ;;
        -h|--help)  usage ;;
        *)       error "Unknown option: $1"; usage ;;
    esac
done

if [[ -z "${REMOTE_IP}" ]]; then
    error "--host <IP> is required."
    exit 1
fi

if [[ -z "${RPM_PATH}" ]]; then
    error "--rpm <path> is required."
    exit 1
fi

if [[ ! -f "${RPM_PATH}" ]]; then
    error "RPM file not found: ${RPM_PATH}"
    exit 1
fi

if [[ -z "${OSQUERY_TAGS}" ]]; then
    OSQUERY_TAGS="${DEFAULT_TAGS}"
    info "--tags not provided. Using default tags: ${OSQUERY_TAGS}"
fi

REMOTE_USER="root"
REMOTE_RPM_DIR="/tmp"
REMOTE_RPM_PATH="${REMOTE_RPM_DIR}/$(basename "${RPM_PATH}")"

# ── Build SSH / SCP commands ──────────────────────────────────────────────────
if [[ -n "${PASSWORD}" ]]; then
    if ! command -v sshpass &>/dev/null; then
        error "sshpass is not installed. Install it with: dnf install -y sshpass"
        exit 1
    fi
    SCP_CMD="sshpass -p '${PASSWORD}' scp -o StrictHostKeyChecking=no"
    SSH_CMD="sshpass -p '${PASSWORD}' ssh -o StrictHostKeyChecking=no"
else
    SCP_CMD="scp -o StrictHostKeyChecking=no"
    SSH_CMD="ssh -o StrictHostKeyChecking=no"
fi

# ── Copy RPM to remote host ───────────────────────────────────────────────────
header "Copying RPM to remote host"

info "Uploading $(basename "${RPM_PATH}") → ${REMOTE_USER}@${REMOTE_IP}:${REMOTE_RPM_DIR}/"
eval "${SCP_CMD} '${RPM_PATH}' '${REMOTE_USER}@${REMOTE_IP}:${REMOTE_RPM_DIR}/'"
success "RPM uploaded."

# ── Run all install phases on the remote host ─────────────────────────────────
header "Running install on ${REMOTE_IP}"

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

SERVICE="osqueryd"
PACKAGE="uptycs-protect"
RPM_PATH="${REMOTE_RPM_PATH}"
OSQUERY_TAGS="${OSQUERY_TAGS}"

is_installed()     { rpm -q "\${PACKAGE}" &>/dev/null; }
is_service_active() { systemctl is-active --quiet "\${SERVICE}"; }

# ── PHASE 1 – Pre-install check ───────────────────────────────────────────────
header "PHASE 1 — Pre-install check"

info "Current installed Uptycs package(s):"
if rpm -qva 2>/dev/null | grep -i upty; then
    true
else
    warn "No Uptycs package currently installed — skipping uninstall phase."
fi

info "Current osqueryd service status:"
systemctl status "\${SERVICE}" --no-pager || true

# ── PHASE 2 – Uninstallation ──────────────────────────────────────────────────
header "PHASE 2 — Uninstallation"

if is_service_active; then
    info "Stopping \${SERVICE} service…"
    systemctl stop "\${SERVICE}"
    success "\${SERVICE} stopped."
else
    info "\${SERVICE} service is not running — nothing to stop."
fi

info "Disabling \${SERVICE} service…"
systemctl disable "\${SERVICE}" 2>/dev/null || true

if is_installed; then
    info "Removing package \${PACKAGE}…"
    dnf remove -y "\${PACKAGE}"
    success "Package \${PACKAGE} removed."
else
    info "Package \${PACKAGE} is not installed — skipping removal."
fi

if is_installed; then
    error "Package \${PACKAGE} is still present after removal attempt."
    exit 1
fi
success "Uninstallation complete."

# ── PHASE 3 – Installation ────────────────────────────────────────────────────
header "PHASE 3 — Installation"

info "Installing \${PACKAGE} from: \${RPM_PATH}"
dnf install -y "\${RPM_PATH}"

if ! is_installed; then
    error "Installation failed — package \${PACKAGE} not found after install."
    exit 1
fi
success "Package installed: \$(rpm -q \${PACKAGE})"

info "Verifying installed Uptycs package(s):"
dnf list --installed 2>/dev/null | grep -i uptycs || rpm -qa | grep -i uptycs

# ── PHASE 4 – Service start & initial status ──────────────────────────────────
header "PHASE 4 — Service start"

WAIT_SECS=10
info "Waiting \${WAIT_SECS}s for \${SERVICE} to initialise…"
sleep "\${WAIT_SECS}"

if ! is_service_active; then
    warn "\${SERVICE} is not active yet — attempting to start…"
    systemctl start "\${SERVICE}"
    sleep 5
fi

if ! is_service_active; then
    error "\${SERVICE} failed to start. Check: journalctl -u \${SERVICE} -n 50"
    systemctl status "\${SERVICE}" --no-pager || true
    exit 1
fi

info "Service status after installation:"
systemctl status "\${SERVICE}" --no-pager

# ── PHASE 5 – Tag configuration ───────────────────────────────────────────────
header "PHASE 5 — Tag configuration"

info "Applying osquery_tags: \${OSQUERY_TAGS}"
osqueryd --osquery_tags "\${OSQUERY_TAGS}"
success "osquery_tags submitted."

sleep 5

info "Post-tag service status:"
systemctl status "\${SERVICE}" --no-pager

# ── PHASE 6 – Verification ────────────────────────────────────────────────────
header "PHASE 6 — Verification"

info "Querying osquery_tags table:"
TAGS_OUTPUT=\$(osqueryi "select * from osquery_tags;" 2>/dev/null || true)
echo "\${TAGS_OUTPUT}"

if echo "\${TAGS_OUTPUT}" | grep -qE '\|[[:space:]]+[A-Z]'; then
    success "osquery_tags table populated — tags applied correctly."
else
    warn "osquery_tags table appears empty or unparseable. Inspect output above."
fi

info "Querying device UUID:"
UUID_OUTPUT=\$(osqueryi "SELECT device_uuid FROM system_info;" 2>/dev/null || true)
echo "\${UUID_OUTPUT}"

DEVICE_UUID=\$(echo "\${UUID_OUTPUT}" | awk '/\|/ && !/device_uuid/ && !/---/ {gsub(/[| ]/, ""); print}' | head -1)

if [[ -n "\${DEVICE_UUID}" ]]; then
    success "device_uuid: \${DEVICE_UUID}"
else
    warn "device_uuid is empty. This may be expected on LPAR/z systems without a UUID in /proc/sysinfo."
fi

info "Final installed package verification:"
rpm -qva | grep -i upty

# ── Cleanup uploaded RPM ──────────────────────────────────────────────────────
info "Cleaning up uploaded RPM…"
rm -f "\${RPM_PATH}"

# ── Summary ───────────────────────────────────────────────────────────────────
header "SUMMARY"

echo ""
printf "  %-25s %s\n" "Host:"                "\$(hostname)"
printf "  %-25s %s\n" "Package installed:"   "\$(rpm -q \${PACKAGE} 2>/dev/null || echo 'NOT FOUND')"
printf "  %-25s %s\n" "Service status:"      "\$(systemctl is-active \${SERVICE} 2>/dev/null)"
printf "  %-25s %s\n" "Tags applied:"        "\${OSQUERY_TAGS}"
printf "  %-25s %s\n" "Device UUID:"         "\${DEVICE_UUID:-(empty - check /proc/sysinfo)}"
echo ""

success "Uptycs installation and configuration complete."
ENDSSH

success "Remote deployment completed successfully on ${REMOTE_IP}."
