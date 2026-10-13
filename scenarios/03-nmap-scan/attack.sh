#!/usr/bin/env bash
# =============================================================================
# Scénario 03 — Scan réseau Nmap   (MITRE ATT&CK T1046)
# Auteur : André Capito (@acapitow)
#
# Découverte de services : balayage de ports du sous-réseau du labo.
# S'appuie sur l'outil standard `nmap`. Mode simulation (--check) par défaut.
#
# Usage :
#   ./attack.sh              # simulation
#   ./attack.sh --execute    # scan réel du sous-réseau DU LABO uniquement
#
# Cible : sous-réseau du labo 10.20.0.0/24 (isolé).
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/lab_guard.sh
source "${SCRIPT_DIR}/../lib/lab_guard.sh"

guard::parse_mode "$@"

TARGET="${TARGET:-$LAB_SUBNET_CIDR}"       # 10.20.0.0/24 par défaut
SCAN_PROFILE="${SCAN_PROFILE:-top}"        # top | full

guard::banner "03 · Scan réseau Nmap (T1046)"
guard::require_lab_target "$TARGET"
guard::need_tool nmap "sur Kali : préinstallé ; Debian/Ubuntu : apt install nmap"

# -sS scan SYN, -T4 rapide, -Pn ne pas pinger d'abord, --open seulement ports ouverts.
if [[ "$SCAN_PROFILE" == "full" ]]; then
  NMAP_ARGS=(-sS -T4 -Pn -p- --open "$TARGET")
  log "Profil de scan   : complet (-p- tous les ports)"
else
  NMAP_ARGS=(-sS -T4 -Pn --top-ports 100 --open "$TARGET")
  log "Profil de scan   : rapide (--top-ports 100)"
fi

log "Cible            : ${TARGET}"
log "Technique MITRE  : T1046 (Network Service Discovery)"
echo

guard::run "Scan Nmap du sous-réseau ${TARGET}" nmap "${NMAP_ARGS[@]}"

echo
ok "Terminé (mode ${MODE})."
cat <<EOF

Pour une bonne visibilité côté endpoint, lancez de préférence le scan depuis WS01
(Windows, équipé de Sysmon) ; voir README.md pour l'équivalent PowerShell natif.

Journaux attendus :
  - WS01/DC01 Sysmon EventID 3 : rafale de connexions vers de nombreux ports/hôtes
  - SRV01 : pics de connexions ; requêtes Nginx si le port 80 est sondé
Détection : Wazuh 100300→100301 (20+ ports distincts depuis une même source).
Export des alertes : ../../scripts/export_alerts.py --rule 100301
EOF
