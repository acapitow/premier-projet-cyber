# NOTICE — Composants tiers & licences

Ce projet (**SOC Home Lab**, © 2026 André Capito, licence MIT) s'appuie sur des projets
open source et des bases de connaissances tierces. Aucun de leurs fichiers n'est
redistribué dans ce dépôt : ils sont récupérés localement via
`scripts/fetch-references.sh` dans `references/` (dossier exclu par `.gitignore`).
Les configurations et règles présentes ici sont **écrites pour ce labo** en s'inspirant
du format et des bonnes pratiques de ces projets.

| Projet | Usage dans ce labo | Licence | Source |
|--------|--------------------|---------|--------|
| SigmaHQ/sigma | Format et conventions des règles Sigma (`detection/sigma/`) | Detection Rule License 1.1 | https://github.com/SigmaHQ/sigma |
| SwiftOnSecurity/sysmon-config | Base de la configuration Sysmon (`detection/sysmon/`) | Licence du dépôt (attribution) | https://github.com/SwiftOnSecurity/sysmon-config |
| olafhartong/sysmon-modular | Alternative modulaire de config Sysmon | GPL-3.0 | https://github.com/olafhartong/sysmon-modular |
| redcanaryco/atomic-red-team | IDs des tests Atomic mappés ATT&CK (cités dans les scénarios) | MIT | https://github.com/redcanaryco/atomic-red-team |
| wazuh/wazuh-ansible | Référence pour le déploiement Ansible de Wazuh | GPL-2.0 | https://github.com/wazuh/wazuh-ansible |
| MITRE ATT&CK® | Mapping des techniques | © The MITRE Corporation, usage selon les conditions MITRE | https://attack.mitre.org/ |

> **MITRE ATT&CK®** est une marque déposée de The MITRE Corporation. Ce projet n'est ni
> affilié ni approuvé par MITRE. L'usage des identifiants de techniques (ex. T1110.001)
> est fait à des fins pédagogiques et de référence.

Si vous redistribuez ce travail, conservez ce fichier et respectez les licences ci-dessus.
