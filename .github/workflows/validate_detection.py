#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Valide la bonne forme des fichiers de détection (CI du SOC Home Lab).

- XML Wazuh (local_rules.xml, local_decoder.xml) : enveloppés dans une racine
  car Wazuh autorise plusieurs <group> de premier niveau.
- XML Sysmon : racine unique <Sysmon>.
- Règles Sigma : YAML multi-documents, champs obligatoires présents.
"""
import glob
import sys
import xml.etree.ElementTree as ET

import yaml

errors = 0


def check_wazuh_xml(path):
    global errors
    try:
        data = open(path, encoding="utf-8").read()
        ET.fromstring(f"<root>{data}</root>")
        print(f"[OK] XML Wazuh  {path}")
    except Exception as exc:  # noqa: BLE001
        errors += 1
        print(f"[ERREUR] {path}: {exc}")


def check_sysmon_xml(path):
    global errors
    try:
        ET.parse(path)
        print(f"[OK] XML Sysmon {path}")
    except Exception as exc:  # noqa: BLE001
        errors += 1
        print(f"[ERREUR] {path}: {exc}")


def check_sigma(path):
    global errors
    try:
        docs = [d for d in yaml.safe_load_all(open(path, encoding="utf-8")) if d]
        base = docs[0]
        for field in ("title", "logsource", "detection"):
            if field not in base:
                raise ValueError(f"champ obligatoire manquant: {field}")
        # Au moins un document de corrélation attendu dans nos règles.
        if not any("correlation" in d for d in docs):
            print(f"[INFO] {path}: pas de règle de corrélation (OK si voulu)")
        print(f"[OK] Sigma      {path} ({len(docs)} documents)")
    except Exception as exc:  # noqa: BLE001
        errors += 1
        print(f"[ERREUR] {path}: {exc}")


def main():
    check_wazuh_xml("detection/wazuh/local_rules.xml")
    check_wazuh_xml("detection/wazuh/local_decoder.xml")
    check_sysmon_xml("detection/sysmon/sysmonconfig.xml")
    for f in sorted(glob.glob("detection/sigma/*.yml")):
        check_sigma(f)
    if errors:
        print(f"\n{errors} erreur(s) de validation.")
        sys.exit(1)
    print("\nTous les fichiers de détection sont valides.")


if __name__ == "__main__":
    main()
