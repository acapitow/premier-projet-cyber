# Profil léger (hôte 16 Go)

Le profil *light* permet de faire tourner le labo sur un PC à **16 Go** de RAM.
Il s'active ainsi :

```bash
LAB_PROFILE=light vagrant up          # Linux/macOS/WSL
set LAB_PROFILE=light && vagrant up    # Windows cmd
$env:LAB_PROFILE="light"; vagrant up   # Windows PowerShell
```

## Ce que change le profil léger

| Élément            | Full            | Light            |
|--------------------|-----------------|------------------|
| DC01 (RAM)         | 4096 Mo         | **2048 Mo**      |
| WS01 (RAM)         | 4096 Mo         | **2048 Mo**      |
| SRV01 (RAM)        | 1024 Mo         | 1024 Mo          |
| SIEM01 (RAM)       | 6144 Mo         | **3072 Mo**      |
| ATTACK01 (Kali)    | 2048 Mo         | **désactivée**   |
| Empreinte totale   | ≈ 16 Go         | **≈ 8 Go**       |

## Conséquences & contournements

- **ATTACK01 désactivée.** Les attaques se lancent depuis d'autres VM :
  - **SSH brute force (T1110.001)** et **Nmap (T1046)** → depuis `SIEM01`
    (les outils `nmap`/`hydra` y sont installés par le rôle `common` en mode light)
    ou depuis l'hôte.
  - **Password spraying AD (T1110.003)** → depuis `WS01` (script PowerShell natif) ou
    depuis `SIEM01` via `crackmapexec`/`kerbrute`.
  Les scripts de `scenarios/` détectent automatiquement l'absence d'ATTACK01 et proposent
  l'alternative.

- **SIEM01 à 3072 Mo.** L'indexer (JVM) est plus lent et peut mettre ~2–3 min à répondre
  après le boot. Si le dashboard rame, fermez les autres applications ou repassez en *full*.
  Minimum conseillé réaliste : 4 Go si votre hôte le permet (`LAB_SIEM_RAM=4096`).

- **DC01/WS01 à 2048 Mo.** Suffisant pour un labo ; évitez d'ouvrir des sessions RDP
  graphiques lourdes simultanément.

## Leviers supplémentaires

Variables d'environnement lues par le `Vagrantfile` (toutes optionnelles) :

| Variable          | Effet                                         | Défaut (full/light) |
|-------------------|-----------------------------------------------|---------------------|
| `LAB_PROFILE`     | `full` ou `light`                             | `full`              |
| `LAB_SIEM_RAM`    | RAM de SIEM01 (Mo)                            | 6144 / 3072         |
| `LAB_DISABLE_WS01`| `true` pour ne pas créer WS01 (encore + léger) | false              |
| `LAB_DISABLE_DC01`| `true` pour un labo Linux-seul                | false               |
| `LAB_CPUS`        | vCPU par VM                                    | 2 / 1               |

### Encore plus léger : labo « Linux-only » (~4 Go)

Pour tester uniquement les scénarios SSH brute force et Nmap :

```bash
LAB_PROFILE=light LAB_DISABLE_DC01=true LAB_DISABLE_WS01=true vagrant up
```

Ne crée que `SIEM01` + `SRV01`. On perd les scénarios AD/Sysmon mais l'empreinte tombe
à ≈ 4 Go.
