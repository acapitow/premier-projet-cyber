# Matrice de couverture MITRE ATT&CK®

Techniques simulées par le labo et détections associées. ATT&CK® est une marque de
The MITRE Corporation (projet non affilié).

## Techniques couvertes

| Tactique              | Technique                         | ID         | Scénario | Détection |
|-----------------------|-----------------------------------|------------|----------|-----------|
| Credential Access     | Brute Force: Password Guessing    | T1110.001  | 01       | Wazuh 100100-100102, Sigma `ssh_bruteforce` |
| Credential Access     | Brute Force: Password Spraying    | T1110.003  | 02       | Wazuh 100200-100203, Sigma `ad_password_spraying` |
| Discovery             | Network Service Discovery         | T1046      | 03       | Wazuh 100300-100302, Sigma `nmap_network_scan` |

## Détail par scénario

### Scénario 01 — SSH Brute Force (T1110.001)

- **Tactique :** TA0006 Credential Access
- **Procédure :** multiples tentatives d'authentification SSH sur SRV01 avec un compte
  valide et une liste de mots de passe courts.
- **Télémétrie :** `/var/log/auth.log` → `Failed password` répétés, puis éventuel
  `Accepted password`.
- **Détection :** corrélation Wazuh par fréquence (seuil de N échecs / fenêtre),
  escalade si succès après rafale.
- **Réf. Atomic Red Team :** technique T1110.001 (tests d'authentification par force brute).

### Scénario 02 — Password Spraying AD (T1110.003)

- **Tactique :** TA0006 Credential Access
- **Procédure :** **un seul** mot de passe courant testé sur **plusieurs** comptes du
  domaine (l'inverse du brute force), pour éviter le verrouillage.
- **Télémétrie :** DC01 Security EventID **4625** (logon failure, status/sub-status
  0xC000006A), **4768/4771** (Kerberos pre-auth failed), éventuel **4740** (lockout).
- **Détection :** Wazuh corrèle *N comptes distincts* en échec depuis une même source dans
  une fenêtre courte (signature du spraying).
- **Réf. Atomic Red Team :** technique T1110.003.

### Scénario 03 — Network Service Discovery / Nmap (T1046)

- **Tactique :** TA0007 Discovery
- **Procédure :** balayage de ports/services du sous-réseau du labo depuis ATTACK01.
- **Télémétrie :** Sysmon **EventID 3** (connexions réseau) en rafale depuis une IP vers de
  nombreux ports/hôtes ; côté SRV01, pics de connexions et éventuels logs Nginx.
- **Détection :** Wazuh corrèle un nombre élevé de connexions distinctes (ports/hôtes)
  depuis une même source en peu de temps.
- **Réf. Atomic Red Team :** technique T1046.

## Pistes d'extension (non implémentées)

Idées pour enrichir le portfolio ensuite, avec le même format (attaque → logs → règle) :

| Technique | ID | Source de log |
|-----------|----|---------------|
| Valid Accounts | T1078 | 4624 type 3/10 inhabituels |
| OS Credential Dumping: LSASS | T1003.001 | Sysmon EID 10 (accès lsass.exe) |
| Kerberoasting | T1558.003 | 4769 avec chiffrement RC4 |
| Scheduled Task | T1053.005 | 4698 / Sysmon EID 1 (`schtasks`) |
| Remote Services: RDP | T1021.001 | 4624 type 10, 4778/4779 |
