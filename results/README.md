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
| `alerts/sample-*.json` | Alertes de **référence** (forme attendue depuis un vrai Wazuh) |
| `alerts/simulated-*.json` | Alertes **réellement produites** par le moteur hors-ligne `simulate_detection.py` |
| `img/` | Emplacement des captures du dashboard Wazuh |

### `sample-*` vs `simulated-*` : la différence (transparence)

- **`sample-*.json`** = exemples écrits à la main montrant le format exact d'une alerte
  Wazuh (utile pour lire le projet sans rien lancer).
- **`simulated-*.json`** = sortie **générée par du code exécuté** : le moteur
  [`scripts/simulate_detection.py`](../scripts/simulate_detection.py) rejoue une trace
  d'attaque et applique la **même logique de corrélation** que les règles Wazuh/Sigma.
  Ce n'est pas un vrai SIEM, mais c'est une **preuve reproductible** que les seuils de
  détection fonctionnent — sur n'importe quelle machine avec Python 3 :

  ```bash
  python3 scripts/simulate_detection.py --out-dir results/alerts
  # ou : cd scenarios && ./run_all_scenarios.sh --simulate
  ```

  Pour une preuve « SIEM réel », déployez le labo puis utilisez `export_alerts.py` (ci-dessous).

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
