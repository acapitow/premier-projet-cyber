#!/usr/bin/env bash
# =============================================================================
# lab_guard.sh — garde-fou commun à TOUS les scénarios du SOC Home Lab
# Auteur : André Capito (@acapitow)
#
# Rôle : empêcher tout usage hors du laboratoire.
#   - refuse toute cible hors du sous-réseau du labo (10.20.0.0/24) ;
#   - impose le mode simulation (--check) par défaut : rien de réel ne part
#     tant que l'opérateur n'a pas explicitement passé --execute ;
#   - vérifie la présence des outils attendus.
#
# À sourcer en tête de chaque script : source ../lib/lab_guard.sh
# =============================================================================

# Ce fichier est SOURCÉ : plusieurs variables (IP du labo, couleurs) sont
# consommées par les scripts appelants, pas dans ce fichier — on neutralise
# donc l'avertissement "variable inutilisée".
# shellcheck disable=SC2034
set -euo pipefail

# --- Périmètre autorisé ------------------------------------------------------
# Sous-réseau du labo. Modifier ici si vous changez le plan d'adressage.
LAB_SUBNET_PREFIX="${LAB_SUBNET_PREFIX:-10.20.0.}"   # => 10.20.0.0/24
LAB_SUBNET_CIDR="${LAB_SUBNET_CIDR:-10.20.0.0/24}"

# Cibles connues du labo (pour information / valeurs par défaut).
DC01_IP="10.20.0.10"
WS01_IP="10.20.0.20"
SRV01_IP="10.20.0.30"
SIEM01_IP="10.20.0.40"
ATTACK01_IP="10.20.0.50"

# --- Couleurs / log ----------------------------------------------------------
if [[ -t 1 ]]; then C_R=$'\e[31m'; C_G=$'\e[32m'; C_Y=$'\e[33m'; C_B=$'\e[34m'; C_0=$'\e[0m'
else C_R=; C_G=; C_Y=; C_B=; C_0=; fi
log()  { echo "${C_B}[*]${C_0} $*"; }
ok()   { echo "${C_G}[+]${C_0} $*"; }
warn() { echo "${C_Y}[!]${C_0} $*"; }
err()  { echo "${C_R}[x]${C_0} $*" >&2; }

# --- Mode d'exécution --------------------------------------------------------
# MODE=check (défaut) : on affiche ce qui SERAIT lancé, sans rien exécuter.
# MODE=execute        : exécution réelle (labo uniquement), après garde-fou.
MODE="check"

guard::parse_mode() {
  for arg in "$@"; do
    case "$arg" in
      --execute) MODE="execute" ;;
      --check)   MODE="check" ;;
    esac
  done
}

# --- Garde-fou : la cible DOIT être dans le sous-réseau du labo --------------
guard::require_lab_target() {
  local target="$1"
  # Autorise une IP du /24 ou la notation réseau exacte du labo.
  if [[ "$target" == "$LAB_SUBNET_CIDR" ]]; then return 0; fi
  if [[ "$target" == ${LAB_SUBNET_PREFIX}* ]]; then return 0; fi
  err "Cible refusée : « $target » n'est pas dans le périmètre du labo (${LAB_SUBNET_CIDR})."
  err "Ces scripts sont STRICTEMENT réservés aux VM du laboratoire isolé."
  exit 2
}

# --- Garde-fou : exécuter une commande réelle seulement si --execute --------
# Usage : guard::run "description humaine" cmd arg1 arg2...
guard::run() {
  local desc="$1"; shift
  if [[ "$MODE" == "check" ]]; then
    warn "[SIMULATION] $desc"
    echo "            commande : $*"
    echo "            (relancez avec --execute pour exécuter réellement — labo uniquement)"
    return 0
  fi
  log "$desc"
  echo "    → $*"
  "$@"
}

# --- Vérifier qu'un outil est présent ---------------------------------------
guard::need_tool() {
  local tool="$1" hint="${2:-}"
  if ! command -v "$tool" >/dev/null 2>&1; then
    if [[ "$MODE" == "check" ]]; then
      warn "Outil absent : '$tool' ${hint:+($hint)} — OK en mode --check, requis pour --execute."
      return 0
    fi
    err "Outil requis manquant : '$tool'. ${hint:-}"
    exit 3
  fi
}

# --- Bannière ----------------------------------------------------------------
guard::banner() {
  echo "────────────────────────────────────────────────────────────"
  echo " SOC Home Lab — $1"
  echo " Périmètre autorisé : ${LAB_SUBNET_CIDR} (isolé)   Mode : ${MODE}"
  echo "────────────────────────────────────────────────────────────"
}
