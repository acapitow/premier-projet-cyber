# Configuration des agents Wazuh

La configuration des agents (canaux de logs collectés) est **gérée par Ansible**, pas
par des fichiers statiques ici :

- **Agents Windows (DC01, WS01)** : `ansible/roles/wazuh-agent/templates/ossec-windows.conf.j2`
  ajoute les canaux `Security`, `System`, `Application`,
  `Microsoft-Windows-Sysmon/Operational` et `Microsoft-Windows-PowerShell/Operational`.
- **Agent Linux (SRV01)** : `ansible/roles/wazuh-agent/tasks/linux.yml` conserve la
  collecte de `/var/log/auth.log` (par défaut) et ajoute les logs Nginx.

Ce dossier est laissé pour accueillir, si besoin, des configurations d'agent centralisées
(`shared/<group>/agent.conf`) exportées depuis le manager.
