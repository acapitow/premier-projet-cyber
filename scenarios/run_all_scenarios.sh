#!/usr/bin/env bash
# =============================================================================
# run_all_scenarios.sh — lance les 3 scénarios d'attaque du SOC Home Lab
# Auteur : André Capito (@acapitow)
#
# Mode simulation (--check) par défaut : affiche ce qui serait lancé, sans rien
# exécuter. Avec --execute, lance réellement les attaques CONTRE LE LABO ISOLÉ,
# en laissant le temps aux alertes de remonter, puis exporte les alertes Wazuh.
#
# Usage :
#   ./run_all_scenarios.sh              # simulation (sûr)
#   ./run_all_scenarios.sh --execute    # exécution réelle (labo uniquement)
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/lab_guard.sh"

guard::parse_mode "$@"
MODE_FLAG="--check"; [[ "$MODE" == "execute" ]] && MODE_FLAG="--execute"

# Pause entre scénarios pour laisser les alertes se corréler côté Wazuh.
SLEEP_BETWEEN="${SLEEP_BETWEEN:-20}"

guard::banner "Exécution de tous les scénarios"
echo

SCENARIOS=(
  "01-ssh-bruteforce/attack.sh"
  "02-password-spraying/attack.sh"
  "03-nmap-scan/attack.sh"
)

for s in "${SCENARIOS[@]}"; do
  echo "═══════════════════════════════════════════════════════════════"
  echo "▶ Scénario : $s"
  echo "═══════════════════════════════════════════════════════════════"
  bash "${SCRIPT_DIR}/${s}" "$MODE_FLAG"
  echo
  if [[ "$MODE" == "execute" ]]; then
    log "Pause ${SLEEP_BETWEEN}s pour laisser les alertes remonter..."
    sleep "$SLEEP_BETWEEN"
  fi
done

echo "═══════════════════════════════════════════════════════════════"
if [[ "$MODE" == "execute" ]]; then
  log "Export des alertes Wazuh générées vers results/ ..."
  if python3 "${SCRIPT_DIR}/../scripts/export_alerts.py" \
        --since "15m" --out "${SCRIPT_DIR}/../results/alerts/run-$(date +%Y%m%d-%H%M%S).json" 2>/dev/null; then
    ok "Alertes exportées dans results/alerts/."
  else
    warn "Export automatique indisponible (API Wazuh non jointe ?)."
    warn "Lancez manuellement : python3 scripts/export_alerts.py --help"
  fi
  ok "Tous les scénarios ont été exécutés. Consultez le dashboard : https://${SIEM01_IP}"
else
  ok "Simulation terminée. Relancez avec --execute pour exécuter réellement (labo isolé)."
fi
