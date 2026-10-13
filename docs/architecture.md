# Architecture détaillée

## Vue d'ensemble

Le labo simule un petit système d'information d'entreprise supervisé par un SOC :
un domaine Active Directory, un poste de travail, un serveur Linux exposant des services,
un SIEM centralisant les journaux, et une machine d'attaque — le tout sur un réseau
**interne isolé**.

```
                        Réseau interne VirtualBox « soc-lab » — 10.20.0.0/24
   ┌───────────┐          ┌───────────┐        ┌───────────┐        ┌───────────┐
   │ ATTACK01  │          │   DC01    │        │   WS01    │        │  SRV01    │
   │  Kali     │          │ Win 2022  │        │ Win 10/11 │        │ Ubuntu    │
   │ 10.20.0.50│          │ 10.20.0.10│        │ 10.20.0.20│        │ 10.20.0.30│
   └─────┬─────┘          └─────┬─────┘        └─────┬─────┘        └─────┬─────┘
         │                      │ AD DS/DNS          │ domain-join        │ SSH+Nginx
         │ attaques             │ audit avancé       │ Sysmon, PS log     │
         │ (labo only)          ▼                    ▼                    ▼
         │              ┌──────────────────────────────────────────────────────┐
         └─────────────▶│                         SIEM01                        │
                        │        Wazuh manager + indexer + dashboard            │
                        │                  10.20.0.40 (https)                   │
                        └──────────────────────────────────────────────────────┘
                        Agents Wazuh : DC01, WS01, SRV01 (et ATTACK01 si présent)
```

## Plan d'adressage

| Hôte      | IP (interne) | FQDN                  | Ports ouverts (labo)             |
|-----------|--------------|-----------------------|----------------------------------|
| DC01      | 10.20.0.10   | dc01.lab.local        | 53, 88, 135, 389, 445, 464, 636, 3268, 5985 (WinRM) |
| WS01      | 10.20.0.20   | ws01.lab.local        | 135, 445, 3389, 5985             |
| SRV01     | 10.20.0.30   | srv01.lab.local       | 22 (SSH), 80 (Nginx)             |
| SIEM01    | 10.20.0.40   | siem01.lab.local      | 443/1514/1515 (Wazuh), 22        |
| ATTACK01  | 10.20.0.50   | attack01.lab.local    | 22                               |

`DC01` fait aussi office de **DNS** du domaine ; les clients Windows pointent vers
`10.20.0.10`. Le suffixe DNS est `lab.local`.

## Deux interfaces par VM

1. **Interface NAT (Vagrant/management)** — créée par défaut par Vagrant. Utilisée
   uniquement pour : télécharger la *box*, installer les paquets, et le canal de contrôle
   SSH/WinRM d'Ansible. Elle **ne porte pas** le trafic des scénarios.
2. **Interface réseau interne `soc-lab`** — porte **tout** le trafic du labo
   (AD, logs, attaques). Isolée : aucun paquet ne sort vers Internet.

### Air-gap complet (optionnel)

Après le premier `vagrant up` réussi, pour couper totalement Internet :

```ruby
# Dans le Vagrantfile, mettre AIRGAP = true puis `vagrant reload`
# -> l'interface NAT est retirée ; seul le réseau interne subsiste.
```

Voir le commentaire `AIRGAP` dans le `Vagrantfile`. Par défaut `AIRGAP = false` pour
laisser passer les mises à jour pendant le provisioning.

## Flux de journaux

| Source  | Événements clés                                   | Transport            |
|---------|---------------------------------------------------|----------------------|
| DC01    | Security 4624/4625/4768/4771/4740, audit avancé   | Agent Wazuh → 1514   |
| WS01    | Sysmon 1/3/7/11, PowerShell 4104, Security 4688   | Agent Wazuh → 1514   |
| SRV01   | `/var/log/auth.log`, `/var/log/nginx/access.log`  | Agent Wazuh → 1514   |
| SIEM01  | Règles/décodeurs, corrélation, alertes            | local                |

## Séquence de provisioning (`vagrant up`)

1. **SIEM01** d'abord : installation de Wazuh *all-in-one* (indexer, manager, dashboard).
2. **SRV01** : SSH + Nginx + agent Wazuh (collecte `auth.log` / `nginx`).
3. **DC01** : promotion AD DS, DNS, OU/utilisateurs/groupes, **politique d'audit avancée**,
   puis agent Wazuh.
4. **WS01** : jonction au domaine `lab.local`, Sysmon (config reconnue), PowerShell logging,
   puis agent Wazuh.
5. **ATTACK01** (profil *full*) : Kali + outils de scénario (`nmap`, `hydra`, `kerbrute`).

L'ordre est imposé dans le `Vagrantfile` (SIEM01 avant les agents) pour que l'enrôlement
des agents réussisse du premier coup.

## Choix des *boxes* Vagrant

| VM        | Box par défaut                              | Remarque |
|-----------|---------------------------------------------|----------|
| DC01      | `gusztavvargadr/windows-server-2022-standard` | Boxes Windows maintenues et populaires |
| WS01      | `gusztavvargadr/windows-11`                 | Remplaçable par `windows-10`           |
| SRV01     | `bento/ubuntu-22.04`                        | Légère, bien maintenue                 |
| SIEM01    | `bento/ubuntu-22.04`                        | Idem                                   |
| ATTACK01  | `kalilinux/rolling`                         | Image officielle Kali                  |

Les noms de boxes sont centralisés en haut du `Vagrantfile` pour être changés facilement.
