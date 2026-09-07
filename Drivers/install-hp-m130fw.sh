#!/usr/bin/env bash
#
# install-hp-m130fw.sh
# CLI install/configure script for HP LaserJet MFP M130fw on Arch Linux
# Target: CUPS + HPLIP + foomatic (hpcups PPD), network printer.
#
# Usage:
#   chmod +x install-hp-m130fw.sh
#   ./install-hp-m130fw.sh [PRINTER_IP] [PRINTER_NAME] [--driverless]
#
# Defaults to hpcups (HPLIP + foomatic PPD) — this is the CONFIRMED
# WORKING method for this unit's firmware. Driverless/IPP Everywhere
# (-m everywhere) adds the queue without error but the printer's own
# firmware fails real jobs with "URP ERROR / NotImplemented /
# urp_urf_processor.c" — a firmware bug, not fixable from Arch. Only
# pass --driverless to try it anyway (e.g. after a firmware update).

set -euo pipefail

PRINTER_IP="${1:-192.168.30.25}"
PRINTER_NAME="${2:-HP_LaserJet_M130fw}"
PRINTER_LOCATION="${PRINTER_LOCATION:-Home Office}"
PRINTER_DESC="HP LaserJet MFP M130fw"
TRY_DRIVERLESS=false
for arg in "$@"; do
  [[ "$arg" == "--driverless" ]] && TRY_DRIVERLESS=true
done

log()  { printf '\033[1;32m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$1"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$1" >&2; exit 1; }

command -v pacman >/dev/null || die "This script is written for Arch Linux (pacman not found)."

# foomatic-db is a "possible additional package" that pacman does NOT pull in
# automatically — without it, lpinfo -m has no real HPLIP/foomatic PPDs for
# this model family, only unusable 'driverless:' placeholder entries.
log "Installing required packages (cups, hplip, sane, avahi, nss-mdns, foomatic-db)"
sudo pacman -S --needed --noconfirm cups hplip sane avahi nss-mdns foomatic-db

log "Enabling and starting cups.service and avahi-daemon.service"
sudo systemctl enable --now cups.service
sudo systemctl enable --now avahi-daemon.service

if ! groups "$USER" | grep -q '\bsys\b'; then
  warn "User '$USER' is not in the 'sys' group. CUPS admin actions from lp-tools may need sudo every time."
  warn "Fix with: sudo usermod -aG sys $USER   (then log out/in)"
fi

if ! grep -Eq '^\s*hosts:.*mdns' /etc/nsswitch.conf; then
  warn "mDNS resolution not configured in /etc/nsswitch.conf — fixing it (backup at /etc/nsswitch.conf.bak)."
  if grep -Eq '^hosts:.*resolve ' /etc/nsswitch.conf; then
    sudo sed -i.bak 's/^hosts:\(.*\)resolve /hosts:\1mdns_minimal [NOTFOUND=return] resolve /' /etc/nsswitch.conf
    log "Updated hosts line: $(grep '^hosts:' /etc/nsswitch.conf)"
  else
    warn "Could not auto-patch (unexpected hosts: line format). Add 'mdns_minimal [NOTFOUND=return]' before 'resolve' manually:"
    grep '^hosts:' /etc/nsswitch.conf || true
  fi
fi

DEVICE_URI=""
PPD=""
MODE=""

# --- Optional: driverless (IPP Everywhere) ----------------------------------
# NOTE: known broken on this unit's firmware (URP ERROR on real jobs) even
# though lpadmin accepts it without error. Only tried if --driverless passed.
if [[ "${TRY_DRIVERLESS}" == "true" ]]; then
  log "Looking for a driverless (IPP Everywhere) URI via mDNS for ${PRINTER_IP}"
  warn "Driverless is known broken on this printer's firmware (URP ERROR on real print jobs)."
  warn "Only proceeding because --driverless was passed explicitly."
  sleep 2   # give avahi a moment after service start to populate its cache
  DNSSD_LINE="$(lpinfo -v 2>/dev/null | grep -iE 'dnssd://|ipps?://' | grep -i 'm130\|laserjet' | head -n1 || true)"
  DNSSD_URI="$(echo "${DNSSD_LINE}" | awk '{print $2}')"

  if [[ -n "${DNSSD_URI}" ]]; then
    log "Found driverless URI: ${DNSSD_URI}"
    DEVICE_URI="${DNSSD_URI}"
    PPD="everywhere"
    MODE="driverless"
  else
    warn "No driverless/mDNS URI found — falling back to HPLIP + foomatic PPD."
  fi
fi

# --- Default / fallback: HPLIP URI + foomatic/hpcups PPD --------------------
if [[ -z "${DEVICE_URI}" ]]; then
  log "Querying the printer at ${PRINTER_IP} for its HPLIP CUPS/SANE URIs"
  URI_OUTPUT="$(hp-makeuri "${PRINTER_IP}" 2>&1)" || true
  echo "${URI_OUTPUT}"

  CUPS_URI="$(echo "${URI_OUTPUT}" | grep -oP 'hp:/net/\S+' | head -n1 || true)"
  if [[ -z "${CUPS_URI}" ]]; then
    die "Could not auto-detect the CUPS URI. Run 'hp-makeuri ${PRINTER_IP}' manually, check the printer is reachable (ping ${PRINTER_IP}), and re-run."
  fi
  log "Detected CUPS URI: ${CUPS_URI}"

  log "Looking up a matching foomatic/hpcups PPD (model M129-M134 family covers the M130fw)"
  # Exclude 'driverless:' placeholder entries — those are NOT valid -m values
  # here and caused 'Missing PPD-Adobe-4.x header' errors previously.
  PPD="$(lpinfo -m 2>/dev/null \
    | grep -viE '^driverless' \
    | grep -iE 'm129.?m134|m127.?m128' \
    | grep -i hpcups \
    | head -n1 | awk '{print $1}' || true)"

  if [[ -z "${PPD}" ]]; then
    warn "No exact PPD auto-match. Listing HP candidates — pick one and re-run with it hardcoded if needed:"
    lpinfo -m 2>/dev/null | grep -viE '^driverless' | grep -i hp || true
    die "Aborting: set PPD manually in this script (search output above) and re-run."
  fi

  DEVICE_URI="${CUPS_URI}"
  MODE="hplip"
  log "Using PPD: ${PPD}"
fi

log "Adding printer '${PRINTER_NAME}' to CUPS (mode: ${MODE})"
sudo lpadmin -p "${PRINTER_NAME}" \
  -E \
  -v "${DEVICE_URI}" \
  -m "${PPD}" \
  -L "${PRINTER_LOCATION}" \
  -D "${PRINTER_DESC}"

sudo cupsenable "${PRINTER_NAME}"
sudo cupsaccept "${PRINTER_NAME}"

if [[ "${MODE}" == "hplip" ]]; then
  log "Checking whether this model needs HP's proprietary plugin"
  if lpinfo -m 2>/dev/null | grep -i "${PPD}" | grep -qi proprietary; then
    warn "Proprietary plugin required — launching hp-plugin"
    sudo hp-plugin -i
  else
    log "No proprietary plugin required for this model."
  fi
else
  log "Driverless mode — no HPLIP plugin needed."
  warn "Remember: driverless is known broken on this unit's firmware. If prints come out as a URP ERROR page, re-run without --driverless."
fi

log "Printer '${PRINTER_NAME}' installed."
log "Send a test print (avoid the built-in CUPS testprint file — it can misfire through pdftopdf/bannertopdf unrelated to the printer driver):"
echo "    echo \"test\" > /tmp/printtest.txt && lp -d ${PRINTER_NAME} /tmp/printtest.txt"
log "Set as default printer with:"
echo "    sudo lpadmin -d ${PRINTER_NAME}"
log "Manage/monitor at: http://localhost:631/printers/${PRINTER_NAME}"
