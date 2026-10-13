# Journaux attendus — Scénario 02 (password spraying AD)

Événements Windows Security (DC01). En labo, ils sont décodés par Wazuh en champs
`win.system.*` / `win.eventdata.*`. Ci-dessous un résumé JSON simplifié des champs clés
qu'un analyste examine (une entrée par compte visé, même IP source).

```json
[
  {"EventID":4625,"TargetUserName":"jdupont",  "IpAddress":"10.20.0.50","SubStatus":"0xC000006A","LogonType":3},
  {"EventID":4625,"TargetUserName":"amartin",  "IpAddress":"10.20.0.50","SubStatus":"0xC000006A","LogonType":3},
  {"EventID":4625,"TargetUserName":"pbernard", "IpAddress":"10.20.0.50","SubStatus":"0xC000006A","LogonType":3},
  {"EventID":4625,"TargetUserName":"svc_backup","IpAddress":"10.20.0.50","SubStatus":"0xC000006A","LogonType":3},
  {"EventID":4625,"TargetUserName":"svc_sql",  "IpAddress":"10.20.0.50","SubStatus":"0xC000006A","LogonType":3}
]
```

## Points d'analyse

- **Même `IpAddress`** (`10.20.0.50`) pour **5 `TargetUserName` distincts** en < 2 min
  → signature du spraying (déclenche Wazuh `100201`).
- `SubStatus 0xC000006A` = mot de passe incorrect (le compte existe) ; `0xC0000064` =
  compte inexistant (énumération).
- Variante Kerberos : `EventID 4771`, `Status 0x18` (pré-auth échouée, mauvais mot de passe).
- Si un seul mot de passe est testé par compte, **aucun 4740** (verrouillage) ne devrait
  apparaître — c'est justement le but du spraying.

## Event IDs de référence

| Event ID | Journal | Description |
|----------|---------|-------------|
| 4625 | Security | An account failed to log on |
| 4768 | Security | A Kerberos authentication ticket (TGT) was requested |
| 4771 | Security | Kerberos pre-authentication failed |
| 4740 | Security | A user account was locked out |
