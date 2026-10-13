#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
export_alerts.py — SOC Home Lab
Auteur : André Capito (@acapitow)

Exporte les alertes Wazuh générées par les scénarios, au format JSON, pour
constituer des preuves (dossier results/) ou alimenter un rapport d'incident.

Deux sources possibles :
  1) l'indexer Wazuh (OpenSearch) — par défaut https://10.20.0.40:9200,
     index « wazuh-alerts-* » (nécessite --user/--password, ou les variables
     d'environnement WAZUH_USER / WAZUH_PASS) ;
  2) le fichier local du manager : /var/ossec/logs/alerts/alerts.json
     (option --from-file, pratique si on lance le script sur SIEM01).

Le script n'utilise que la bibliothèque standard (pas de dépendance à installer).

Exemples :
  # Depuis l'hôte, via l'indexer, 15 dernières minutes, règles de brute force :
  WAZUH_PASS='...' python3 export_alerts.py --since 15m --rule 100101,100102 \
      --out ../results/alerts/ssh.json

  # Sur SIEM01, à partir du fichier local :
  python3 export_alerts.py --from-file /var/ossec/logs/alerts/alerts.json \
      --rule 100201 --out /tmp/spray.json
"""

import argparse
import json
import os
import re
import ssl
import sys
import urllib.request
from datetime import datetime, timedelta, timezone

DEFAULT_INDEXER = "https://10.20.0.40:9200"
DEFAULT_INDEX = "wazuh-alerts-*"
LOCAL_ALERTS = "/var/ossec/logs/alerts/alerts.json"


def parse_since(value: str) -> datetime:
    """Convertit '15m', '2h', '7d' en datetime UTC de début de fenêtre."""
    m = re.fullmatch(r"(\d+)\s*([smhd])", value.strip())
    if not m:
        raise argparse.ArgumentTypeError("format --since invalide (ex. 15m, 2h, 7d)")
    n, unit = int(m.group(1)), m.group(2)
    delta = {"s": "seconds", "m": "minutes", "h": "hours", "d": "days"}[unit]
    return datetime.now(timezone.utc) - timedelta(**{delta: n})


def query_indexer(url, index, user, password, since_dt, rules, limit):
    """Interroge l'indexer Wazuh (OpenSearch _search) et renvoie une liste d'alertes."""
    must = [{"range": {"timestamp": {"gte": since_dt.isoformat()}}}]
    if rules:
        must.append({"terms": {"rule.id": [str(r) for r in rules]}})
    body = {
        "size": limit,
        "sort": [{"timestamp": {"order": "desc"}}],
        "query": {"bool": {"must": must}},
    }
    endpoint = f"{url.rstrip('/')}/{index}/_search"
    data = json.dumps(body).encode("utf-8")

    # Authentification basique
    auth_mgr = urllib.request.HTTPPasswordMgrWithDefaultRealm()
    auth_mgr.add_password(None, url, user, password)
    # Contexte SSL : l'indexer du labo utilise un certificat auto-signé.
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    opener = urllib.request.build_opener(
        urllib.request.HTTPBasicAuthHandler(auth_mgr),
        urllib.request.HTTPSHandler(context=ctx),
    )
    req = urllib.request.Request(endpoint, data=data,
                                 headers={"Content-Type": "application/json"},
                                 method="POST")
    with opener.open(req, timeout=30) as resp:
        payload = json.loads(resp.read().decode("utf-8"))
    return [hit.get("_source", {}) for hit in payload.get("hits", {}).get("hits", [])]


def read_local_file(path, since_dt, rules, limit):
    """Lit le fichier alerts.json (NDJSON) du manager et filtre localement."""
    out = []
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                alert = json.loads(line)
            except json.JSONDecodeError:
                continue
            # Filtre par règle
            if rules:
                rid = str(alert.get("rule", {}).get("id", ""))
                if rid not in {str(r) for r in rules}:
                    continue
            out.append(alert)
    # Les plus récentes d'abord, limitées
    return out[-limit:][::-1]


def summarize(alerts):
    """Petit récapitulatif lisible par règle."""
    counts = {}
    for a in alerts:
        rule = a.get("rule", {})
        key = f"{rule.get('id','?')} (niv. {rule.get('level','?')}) — {rule.get('description','')[:60]}"
        counts[key] = counts.get(key, 0) + 1
    return counts


def main(argv=None):
    p = argparse.ArgumentParser(description="Exporte les alertes Wazuh du SOC Home Lab.")
    p.add_argument("--indexer", default=os.environ.get("WAZUH_INDEXER", DEFAULT_INDEXER),
                   help=f"URL de l'indexer (défaut {DEFAULT_INDEXER})")
    p.add_argument("--index", default=DEFAULT_INDEX, help="Index à interroger")
    p.add_argument("--user", default=os.environ.get("WAZUH_USER", "admin"))
    p.add_argument("--password", default=os.environ.get("WAZUH_PASS", ""))
    p.add_argument("--from-file", dest="from_file", nargs="?", const=LOCAL_ALERTS,
                   help=f"Lire depuis un alerts.json local (défaut {LOCAL_ALERTS})")
    p.add_argument("--since", type=parse_since, default="24h",
                   help="Fenêtre temporelle (ex. 15m, 2h, 7d). Défaut 24h")
    p.add_argument("--rule", default="",
                   help="IDs de règles à filtrer, séparés par des virgules (ex. 100101,100102)")
    p.add_argument("--limit", type=int, default=1000, help="Nombre max d'alertes")
    p.add_argument("--out", help="Fichier de sortie JSON (sinon stdout)")
    args = p.parse_args(argv)

    # --since peut arriver en str (valeur par défaut) : on normalise.
    since_dt = args.since if isinstance(args.since, datetime) else parse_since(args.since)
    rules = [r.strip() for r in args.rule.split(",") if r.strip()]

    try:
        if args.from_file:
            if not os.path.exists(args.from_file):
                print(f"[x] Fichier introuvable : {args.from_file}", file=sys.stderr)
                return 1
            alerts = read_local_file(args.from_file, since_dt, rules, args.limit)
            source = f"fichier {args.from_file}"
        else:
            if not args.password:
                print("[x] Mot de passe indexer manquant : --password ou WAZUH_PASS.",
                      file=sys.stderr)
                return 2
            alerts = query_indexer(args.indexer, args.index, args.user,
                                   args.password, since_dt, rules, args.limit)
            source = f"indexer {args.indexer}"
    except Exception as exc:  # noqa: BLE001 — on veut un message clair en labo
        print(f"[x] Échec de l'export ({source if 'source' in dir() else '?'}) : {exc}",
              file=sys.stderr)
        return 3

    # Récapitulatif
    print(f"[+] {len(alerts)} alerte(s) récupérée(s) depuis {source}", file=sys.stderr)
    for key, n in sorted(summarize(alerts).items(), key=lambda kv: -kv[1]):
        print(f"      {n:4d}  rule {key}", file=sys.stderr)

    output = json.dumps(alerts, indent=2, ensure_ascii=False)
    if args.out:
        os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as fh:
            fh.write(output)
        print(f"[+] Écrit : {args.out}", file=sys.stderr)
    else:
        print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
