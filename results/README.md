# Résultats

> **Transparence (important).** Les fichiers `alerts/sample-*.json` et les captures
> attendues dans `img/` sont des **sorties de RÉFÉRENCE** : elles montrent la forme
> **exacte** des alertes/preuves que le labo produit, pour pouvoir lire le projet sans
> l'avoir déployé. Elles ne sont **pas** présentées comme la preuve d'une exécution sur
> une vraie infrastructure. Après avoir lancé le labo, **remplacez-les** par vos propres
> exports et captures (voir ci-dessous).

## Ce que contient ce dossier

| Chemin | Rôle |
|--------|------|
| `alerts/sample-ssh-bruteforce.json` | Alertes de référence du scénario 01 (format `export_alerts.py`) |
| `alerts/sample-password-spraying.json` | Alertes de référence du scénario 02 |
| `alerts/sample-nmap-scan.json` | Alertes de référence du scénario 03 |
| `img/` | Emplacement des captures du dashboard Wazuh |

> `.gitignore` conserve les fichiers `sample-*.json` mais **ignore** les exports réels
> (`run-*.json`, etc.) pour éviter de polluer le dépôt avec de gros volumes.

## Générer vos propres résultats

```bash
# 1) Lancer le labo (hôte avec VirtualBox + RAM suffisante)
vagrant up                       # ou LAB_PROFILE=light vagrant up

# 2) Exécuter les scénarios pour de vrai (labo isolé)
cd scenarios && ./run_all_scenarios.sh --execute

# 3) Exporter les alertes générées (indexer Wazuh)
WAZUH_PASS='<mot_de_passe_admin>' python3 scripts/export_alerts.py \
    --since 30m --out results/alerts/run-$(date +%F).json

# 4) Prendre les captures du dashboard https://10.20.0.40 et les déposer dans results/img/
```

## Checklist de preuves pour le portfolio

- [ ] `results/img/ssh-bruteforce-alert.png` — alerte 100101/100102 dans le dashboard
- [ ] `results/img/password-spraying-alert.png` — alerte 100201
- [ ] `results/img/nmap-scan-alert.png` — alerte 100301
- [ ] `results/img/mitre-coverage.png` — module MITRE ATT&CK de Wazuh
- [ ] Exports JSON correspondants dans `results/alerts/`
- [ ] Rapports d'incident complétés dans `docs/incident-response/`
