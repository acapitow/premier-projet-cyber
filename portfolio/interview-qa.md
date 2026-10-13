# 10 questions d'entretien SOC sur ce projet (avec réponses modèles)

> Questions qu'un recruteur / lead SOC pourrait poser sur le SOC Home Lab.
> Les réponses sont des modèles : appropriez-vous-les et adaptez-les à votre expérience.

---

### 1. C'est quoi un SIEM, et pourquoi Wazuh dans ton labo ?

Un **SIEM** (Security Information and Event Management) centralise les journaux de tout le
parc, les **normalise/décode**, applique des **règles de corrélation** pour générer des
alertes, et offre recherche + tableaux de bord. Wazuh se décompose en trois briques :
le **manager** (décodeurs, règles, corrélation, génération d'alertes), l'**indexer**
(stockage/recherche, basé sur OpenSearch) et le **dashboard** (visualisation).
J'ai choisi Wazuh car il est **open source**, très utilisé en SOC junior/PME, et combine
nativement collecte d'agents, détection, FIM et mapping MITRE ATT&CK. En production, on
séparerait l'indexer et le dashboard pour la montée en charge ; en labo j'utilise le mode
*all-in-one*.

### 2. Quelle est la différence entre brute force et password spraying ? Pourquoi ça change la détection ?

- **Brute force** (T1110.001) : *beaucoup de mots de passe* sur **un seul compte**. On le
  détecte en comptant les échecs **par compte** (ex. ≥ 8 échecs/60 s).
- **Password spraying** (T1110.003) : **un seul** mot de passe testé sur **beaucoup de
  comptes**, espacé pour **rester sous le seuil de verrouillage**.

Compter les échecs par compte **rate** le spraying (1-2 échecs par compte seulement). Il
faut donc corréler **« N comptes distincts échoués depuis une même source »** dans une
fenêtre de temps. C'est exactement ce que fait ma règle Wazuh `100201` (`different_field`
sur `targetUserName`, `same_field` sur `ipAddress`).

### 3. Comment détectes-tu le spraying sans te reposer sur le verrouillage de compte ?

Le verrouillage (Event **4740**) est justement ce que l'attaquant évite. Je me base donc
sur les **échecs 4625** et je corrèle le **nombre de comptes distincts** visés par une
même IP source sur une courte fenêtre (5 comptes / 120 s dans ma règle). J'ajoute une
variante **Kerberos** (4771, échec de pré-authentification) pour couvrir les attaques qui
passent par Kerberos plutôt que NTLM. Le `SubStatus 0xC000006A` (mauvais mot de passe)
distingue un compte existant d'un `0xC0000064` (compte inexistant = énumération).

### 4. Pourquoi installer Sysmon alors que Windows journalise déjà ? Quels Event IDs regardes-tu ?

Les journaux natifs sont lacunaires côté endpoint. **Sysmon** (System Monitor, Sysinternals)
apporte une télémétrie riche et stable. Les Event IDs que j'exploite :
- **1** : création de processus (avec **ligne de commande** et hash) — exécution.
- **3** : connexion réseau — c'est la base de ma détection de **scan** (T1046).
- **7** : chargement d'image/DLL. **8** : CreateRemoteThread (injection).
- **10** : accès à un processus — utile pour l'accès à **lsass.exe** (dump de creds).
- **11** : création de fichier. **12/13** : registre (persistance). **22** : requêtes DNS.

J'ajoute aussi le **PowerShell Script Block Logging** (Event **4104**) pour voir le code
PowerShell réellement exécuté.

### 5. C'est quoi MITRE ATT&CK et comment tu t'en sers dans le projet ?

ATT&CK est une **base de connaissances** des comportements adverses, organisée en
**tactiques** (le « pourquoi » : Credential Access, Discovery…) et **techniques** (le
« comment » : T1110.003…). Je m'en sers comme **langage commun** : chaque scénario est
mappé à une technique, chaque règle Wazuh/Sigma porte le tag ATT&CK, et je tiens une
**matrice de couverture** (`docs/mitre-attack-matrix.md`). Ça permet de raisonner en
termes de **couverture de détection** et de repérer les trous (ex. je n'ai pas encore
T1003 LSASS dump — c'est une extension identifiée).

### 6. Sigma vs règles Wazuh : pourquoi écrire les deux ?

Les règles **Wazuh** sont le format **natif** de mon SIEM (XML, décodeurs, corrélation par
fréquence) : c'est ce qui tourne réellement. **Sigma** est un format **générique et
portable** (« le YAML des règles de détection ») : une même règle Sigma se convertit vers
Splunk, Elastic, Sentinel, etc. via `sigma convert`. Écrire les deux montre que je
comprends la logique de détection **indépendamment de l'outil**, et rend mes détections
réutilisables. J'ai même utilisé les **règles de corrélation Sigma** (`event_count`,
`value_count`) pour exprimer brute force et spraying.

### 7. Sur une alerte 4625, qu'est-ce que tu regardes en premier ?

Les champs clés : **`TargetUserName`** (compte visé), **`IpAddress`/`WorkstationName`**
(origine), **`LogonType`** (3 = réseau, 10 = RDP…), et surtout le **`SubStatus`** :
- `0xC000006A` : mauvais mot de passe (le compte **existe**) ;
- `0xC0000064` : utilisateur **inexistant** (énumération) ;
- `0xC0000234` : compte **verrouillé** ; `0xC0000072` : compte désactivé.
Ensuite je **corrèle** : un seul 4625 isolé = bruit courant ; 4625 répétés multi-comptes
depuis une IP = spraying ; 4625 suivis d'un **4624** (succès) = accès potentiellement
réussi à investiguer.

### 8. Que t'indiquent les Event IDs Kerberos 4768 / 4771 / 4769 ?

- **4768** : demande de **TGT** (une authentification Kerberos a lieu). Des 4768 en rafale
  pour de nombreux comptes = authentifications massives.
- **4771** : **échec de pré-authentification** (ex. `0x18` = mauvais mot de passe) — mon
  signal de spraying côté Kerberos.
- **4769** : demande de **ticket de service (TGS)**. Un pic de 4769 avec chiffrement
  **RC4 (0x17)** sur des comptes de service est un indicateur de **Kerberoasting**
  (T1558.003) — une extension que je veux ajouter.

### 9. Une de tes règles génère trop de faux positifs. Comment tu la tunes ?

Méthode : 1) **mesurer** le taux et identifier les sources légitimes (scanner de vuln,
sauvegarde, appli mal configurée) ; 2) **affiner le périmètre** (filtrer par champ, ex.
exclure une IP d'admin connue via une *allowlist*) ; 3) **ajuster le seuil et la fenêtre**
de corrélation (fréquence/temps) ; 4) **enrichir** (contexte utilisateur/actif) ; 5)
documenter et **versionner** la règle. L'objectif est d'améliorer le rapport
**signal/bruit** sans créer d'angle mort — chaque exclusion est tracée et justifiée.

### 10. Décris ta réponse à incident sur le brute force SSH détecté.

Je suis la méthode **PICERL** (cf. `docs/incident-response/IR-001`) :
- **Identification** : alerte Wazuh `100101`, source `10.20.0.50`, compte `labadmin` ;
  je vérifie s'il y a eu un **succès** après la rafale (règle `100102`).
- **Confinement** : blocage de l'IP (pare-feu ou *active response* Wazuh), verrouillage du
  compte, coupure des sessions actives.
- **Éradication** : réinitialisation du mot de passe, contrôle des `authorized_keys`.
- **Rétablissement** : réactivation avec mot de passe fort, surveillance renforcée.
- **Lessons learned** : passer SSH en **clés only**, déployer **fail2ban**, restreindre
  les IP sources. Je documente la chronologie et les IOC dans le rapport.

---

### Bonus — SIEM vs EDR ?

Un **SIEM** centralise et corrèle des **logs de sources hétérogènes** (réseau, AD, serveurs).
Un **EDR** est centré **endpoint**, avec télémétrie fine et capacité de **réponse**
(isolation, kill process). Ils sont **complémentaires** : dans mon labo, Wazuh joue le rôle
SIEM, et Sysmon apporte une partie de la visibilité endpoint qu'un EDR fournirait.

### Bonus — Comment tu passerais ce labo en production ?

Séparer indexer/dashboard et les redonder, gérer les secrets correctement (coffre),
collecter via des **groupes d'agents** et une config centralisée, ajouter des sources
(pare-feu, proxy, DNS), intégrer la **threat intel**, et brancher un **SOAR** pour
automatiser la réponse. Et surtout : mesurer la couverture ATT&CK et le taux de faux positifs.
