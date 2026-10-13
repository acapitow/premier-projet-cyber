# Scénario 01 — Brute force SSH sur SRV01

| | |
|---|---|
| **Technique MITRE** | [T1110.001 — Brute Force: Password Guessing](https://attack.mitre.org/techniques/T1110/001/) |
| **Tactique** | TA0006 Credential Access |
| **Cible** | SRV01 (`10.20.0.30`), service SSH, compte `labadmin` |
| **Lancé depuis** | ATTACK01 (`hydra`) — ou SIEM01 en profil léger |
| **Réf. Atomic Red Team** | T1110.001 |

## Principe

L'attaquant essaie de nombreux mots de passe sur **un même compte** jusqu'à trouver le bon.
Ici, `hydra` teste la liste `passwords.txt` (fictive, propre au labo) contre `labadmin@SRV01`.

## Exécuter

```bash
./attack.sh            # simulation : montre la commande hydra, ne lance rien
./attack.sh --execute  # lance le brute force contre SRV01 (labo isolé)
```

Commande sous-jacente :

```bash
hydra -l labadmin -P passwords.txt -t 4 -I -f ssh://10.20.0.30
```

## Journaux attendus — SRV01 `/var/log/auth.log`

```
sshd[2345]: Failed password for labadmin from 10.20.0.50 port 51000 ssh2
sshd[2346]: Failed password for labadmin from 10.20.0.50 port 51002 ssh2
...   (rafale rapide depuis la même IP)
sshd[2399]: Accepted password for labadmin from 10.20.0.50 port 51090 ssh2   <-- si succès
```

Voir [`expected-logs.md`](expected-logs.md) pour des lignes copiables (test `wazuh-logtest`).

## Détection

- **Wazuh** — [`detection/wazuh/local_rules.xml`](../../detection/wazuh/local_rules.xml)
  - `100100` (échec SSH) → `100101` (≥ 8 échecs/60 s = brute force, niveau 10)
  - `100102` : **connexion réussie après brute force** (niveau 13, compromission probable)
  - S'appuie aussi sur les règles natives Wazuh 5710/5712/5716/5720.
- **Sigma** — [`detection/sigma/ssh_bruteforce.yml`](../../detection/sigma/ssh_bruteforce.yml)
  (règle de base + corrélation `event_count` ≥ 8 / 1 min par `src_ip`).

### Valider sans attaque réelle

```bash
sudo /var/ossec/bin/wazuh-logtest
# coller une ligne de expected-logs.md ; répéter 8× pour déclencher 100101.
```

## Réponse à incident

Rapport : [`docs/incident-response/IR-001-ssh-bruteforce.md`](../../docs/incident-response/IR-001-ssh-bruteforce.md).
