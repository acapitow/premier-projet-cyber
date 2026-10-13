# Décisions techniques (ADR)

Ce document récapitule les choix d'architecture et leur justification, comme demandé :
le labo prend des décisions raisonnables par défaut et les explique ici. Format inspiré
des *Architecture Decision Records* (ADR).

---

## ADR-001 — Vagrant + VirtualBox + Ansible

**Choix.** Vagrant (provider VirtualBox) pour le cycle de vie des VM, Ansible pour la
configuration.

**Pourquoi.** C'est la combinaison IaC la plus répandue pour les labos de sécurité
auto-hébergés (cf. *DetectionLab*). VirtualBox est gratuit et multi-plateforme ; Vagrant
offre un `Vagrantfile` unique et déclaratif ; Ansible est agentless et idempotent, avec
un support Windows (WinRM) mûr. Alternatives écartées : Terraform (plutôt cloud/infra
long-vécu), Packer (utile pour fabriquer des images, hors périmètre ici), Hyper-V (lié à
Windows uniquement).

---

## ADR-002 — SIEM : Wazuh *all-in-one*

**Choix.** Wazuh 4.x en mode *all-in-one* (manager + indexer + dashboard sur SIEM01).

**Pourquoi.** Open source, gratuit, très utilisé en SOC junior/PME ; intègre nativement
collecte de logs, règles, décodeurs, FIM, et un dashboard. Alternatives écartées :
Elastic + Elastic Agent + détections Kibana (plus lourd à câbler), Splunk (licence),
Graylog (moins orienté détection prête à l'emploi). Le mode *all-in-one* simplifie le labo ;
en production on séparerait indexer et dashboard.

---

## ADR-003 — Domaine Active Directory `lab.local`

**Choix.** Domaine `lab.local`, forêt mono-domaine, niveau fonctionnel Windows Server 2016+.

**Pourquoi.** `lab.local` est explicite et sans risque de collision avec un domaine réel
routable. On peuple des OU, groupes et utilisateurs fictifs par script
(`ansible/roles/dc01-domain-controller`). La **politique d'audit avancée** est activée
(ouvertures de session, gestion des comptes, Kerberos) pour produire les Event IDs 4624,
4625, 4768, 4771, 4740, etc. indispensables à la détection.

> Note : `*.local` est techniquement réservé au mDNS multicast, mais reste la convention
> la plus courante en labo AD. Le labo étant isolé, aucun conflit n'est possible.

---

## ADR-004 — Endpoint Windows : Sysmon + PowerShell logging

**Choix.** Sysmon avec une configuration reconnue (SwiftOnSecurity par défaut, variante
Olaf Hartong documentée) + PowerShell **Script Block Logging** (Event ID 4104) et
**Module Logging**.

**Pourquoi.** Les journaux Windows natifs sont insuffisants pour la détection *endpoint*.
Sysmon apporte la création de processus (EID 1), les connexions réseau (EID 3), le
chargement d'images (EID 7), etc. Ces événements alimentent les détections de scan et de
mouvement. La config SwiftOnSecurity est un standard pédagogique bien commenté.

---

## ADR-005 — Cible Linux : Ubuntu 22.04 + SSH + Nginx

**Choix.** SRV01 sous Ubuntu Server 22.04 LTS, OpenSSH et Nginx exposés sur le réseau interne.

**Pourquoi.** Fournit une surface réaliste pour le scénario SSH brute force (T1110.001) et
pour le scan Nmap (T1046). `auth.log` est collecté par l'agent Wazuh. Nginx ajoute un
service web pour enrichir le scan et de futurs scénarios (ex. logs d'accès).

---

## ADR-006 — Réseau isolé 10.20.0.0/24

**Choix.** Réseau **interne** VirtualBox `soc-lab` en `10.20.0.0/24`, sans accès Internet
pour le trafic du labo. Une interface NAT n'est utilisée que par Vagrant pour le
provisioning (téléchargement des boxes, paquets), et peut être coupée ensuite pour un
air-gap complet (voir `docs/architecture.md`).

**Pourquoi.** Isolation = sécurité : les attaques simulées ne peuvent pas sortir du labo.
Le garde-fou `scenarios/lib/lab_guard.sh` refuse en plus toute cible hors `10.20.0.0/24`.

---

## ADR-007 — Scripts d'attaque bridés + mode `--check`

**Choix.** Les scripts de scénario s'appuient sur des outils standards et publics (`nmap`,
`hydra`, `kerbrute`/`crackmapexec`) ; ils tournent en **mode `--check` (simulation) par
défaut** et n'exécutent l'attaque réelle qu'avec `--execute`, après validation du
garde-fou labo. Les listes de mots sont **minuscules et fictives** (uniquement les comptes
de test créés par le labo).

**Pourquoi.** Objectif pédagogique = comprendre la technique et surtout la **détecter**,
pas fournir un outil offensif réutilisable. Le mode `--check` permet de relire et de tester
la chaîne de détection sans générer d'attaque réelle.

---

## ADR-008 — Profils *full* / *light*

**Choix.** Variable d'environnement `LAB_PROFILE` (`full` par défaut, `light`).

**Pourquoi.** Rendre le labo utilisable sur un PC 16 Go sans réécrire le `Vagrantfile`.
Le profil *light* réduit la RAM et désactive ATTACK01. Compromis documentés dans
`docs/light-profile.md`.

---

## ADR-009 — Identifiants de test & secrets

**Choix.** Mots de passe de test fictifs centralisés dans
`ansible/group_vars/vault.yml.example` (à copier en `vault.yml`, chiffrable via
`ansible-vault`). Aucun secret réel n'est commité ; `.gitignore` bloque `vault.yml`.

**Pourquoi.** Reproductibilité du labo tout en évitant de versionner des secrets.
Les mots de passe sont volontairement faibles **uniquement** parce que l'environnement est
jetable et isolé.
