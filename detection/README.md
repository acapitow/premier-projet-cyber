# Détection

Contenu de détection du labo, organisé par outil.

| Dossier | Contenu | Déployé par |
|---------|---------|-------------|
| [`wazuh/`](wazuh/) | Règles (`local_rules.xml`) et décodeurs (`local_decoder.xml`) Wazuh, plage d'IDs 100100+ | rôle `wazuh-manager` → `/var/ossec/etc/` |
| [`sigma/`](sigma/) | Règles Sigma (format SigmaHQ) équivalentes, avec corrélation | portable (conversion via `sigma convert`) |
| [`sysmon/`](sysmon/) | Configuration Sysmon (`sysmonconfig.xml`) | rôle `ws01-workstation` → WS01/DC01 |

## Correspondance scénario → détection

| Scénario | MITRE | Règles Wazuh | Règle Sigma |
|----------|-------|--------------|-------------|
| 01 SSH brute force | T1110.001 | 100100 → 100101 → 100102 (succès après brute force) | `ssh_bruteforce.yml` |
| 02 Password spraying | T1110.003 | 100200/100201 (4625) + 100202/100203 (Kerberos 4771) | `ad_password_spraying.yml` |
| 03 Scan Nmap | T1046 | 100300 → 100301 | `nmap_network_scan.yml` |

## Tester une règle sans attendre une vraie attaque

Sur SIEM01, `wazuh-logtest` rejoue une ligne de log et montre quelle règle se déclenche :

```bash
sudo /var/ossec/bin/wazuh-logtest
# puis coller une ligne, ex. (SSH) :
# Oct 13 22:40:01 srv01 sshd[2345]: Failed password for labadmin from 10.20.0.50 port 51000 ssh2
```

## Convertir les règles Sigma

```bash
pip install sigma-cli pysigma-backend-opensearch
sigma convert -t opensearch -p sysmon detection/sigma/nmap_network_scan.yml
```

## Sources & format

Les règles Sigma suivent le format officiel **SigmaHQ** (y compris les règles de
**corrélation** `event_count` / `value_count`). La configuration Sysmon s'inspire de
**SwiftOnSecurity/sysmon-config** et **olafhartong/sysmon-modular**. Voir [`../NOTICE.md`](../NOTICE.md).
