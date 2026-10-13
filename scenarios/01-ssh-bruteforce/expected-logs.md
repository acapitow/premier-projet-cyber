# Journaux attendus — Scénario 01 (SSH brute force)

Lignes `/var/log/auth.log` copiables dans `wazuh-logtest` (SRV01) pour tester les règles.

## Échecs (répéter ≥ 8 fois pour déclencher la règle de corrélation 100101)

```
Oct 13 22:40:01 srv01 sshd[2345]: Failed password for labadmin from 10.20.0.50 port 51000 ssh2
Oct 13 22:40:01 srv01 sshd[2346]: Failed password for labadmin from 10.20.0.50 port 51002 ssh2
Oct 13 22:40:02 srv01 sshd[2347]: Failed password for labadmin from 10.20.0.50 port 51004 ssh2
Oct 13 22:40:02 srv01 sshd[2348]: Failed password for invalid user admin from 10.20.0.50 port 51006 ssh2
Oct 13 22:40:03 srv01 sshd[2349]: Failed password for labadmin from 10.20.0.50 port 51008 ssh2
Oct 13 22:40:03 srv01 sshd[2350]: Failed password for labadmin from 10.20.0.50 port 51010 ssh2
Oct 13 22:40:04 srv01 sshd[2351]: Failed password for labadmin from 10.20.0.50 port 51012 ssh2
Oct 13 22:40:04 srv01 sshd[2352]: Failed password for labadmin from 10.20.0.50 port 51014 ssh2
```

## Succès (déclenche l'escalade 100102 si précédé d'un brute force)

```
Oct 13 22:40:05 srv01 sshd[2399]: Accepted password for labadmin from 10.20.0.50 port 51090 ssh2
```

## Event IDs / rules de référence

| Source | Identifiant | Signification |
|--------|-------------|---------------|
| auth.log | `Failed password` | Échec d'authentification (Wazuh natif 5716) |
| auth.log | `Failed password for invalid user` | Utilisateur inexistant (Wazuh natif 5710) |
| auth.log | `Accepted password` | Connexion réussie (Wazuh natif 5715) |
| Wazuh | 100101 | Brute force (corrélation ≥ 8/60 s) |
| Wazuh | 100102 | Succès après brute force (compromission) |
