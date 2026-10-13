<#
    ws01-portsweep.ps1 — Scénario 03 (variante Windows, profil léger)
    Auteur : André Capito (@acapitow)

    Balayage TCP simple depuis WS01 avec PowerShell natif (Test-NetConnection),
    quand ATTACK01 (Kali) est désactivée. Objectif : générer des connexions
    visibles par Sysmon (EventID 3) et PowerShell (EventID 4104) pour tester la
    détection de scan (MITRE T1046).

    Mode simulation par défaut. Utiliser -Execute pour lancer réellement.
    Garde-fou : refuse toute cible hors du sous-réseau du labo 10.20.0.0/24.

    Exemple :
      powershell -ExecutionPolicy Bypass -File .\ws01-portsweep.ps1
      powershell -ExecutionPolicy Bypass -File .\ws01-portsweep.ps1 -Execute
#>
[CmdletBinding()]
param(
    [string]   $Subnet  = "10.20.0.",                 # préfixe /24 du labo
    [int[]]    $Hosts   = @(10, 20, 30, 40),          # DC01, WS01, SRV01, SIEM01
    [int[]]    $Ports   = @(21,22,23,25,53,80,88,135,139,389,443,445,464,636,3268,3389,5985,5986),
    [switch]   $Execute
)

# --- Garde-fou : périmètre labo uniquement ---
if ($Subnet -ne "10.20.0.") {
    Write-Host "[x] Sous-réseau refusé : '$Subnet'. Labo isolé 10.20.0.0/24 uniquement." -ForegroundColor Red
    exit 2
}

Write-Host "────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host " SOC Home Lab — 03 · Port sweep PowerShell (T1046)"
Write-Host (" Cibles : {0}x hôtes, {1} ports   Mode : {2}" -f $Hosts.Count, $Ports.Count, $(if($Execute){"EXECUTE"}else{"SIMULATION"}))
Write-Host "────────────────────────────────────────────────" -ForegroundColor DarkGray

if (-not $Execute) {
    Write-Host "[!] SIMULATION : aucune connexion lancée. Ajoutez -Execute pour exécuter (labo)." -ForegroundColor Yellow
    foreach ($h in $Hosts) { Write-Host ("    scannerait {0}{1} sur {2} ports" -f $Subnet, $h, $Ports.Count) }
    return
}

foreach ($h in $Hosts) {
    $ip = "$Subnet$h"
    foreach ($p in $Ports) {
        # -InformationLevel Quiet => booléen ; chaque essai génère une connexion (Sysmon EID3).
        $open = Test-NetConnection -ComputerName $ip -Port $p -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($open) { Write-Host ("[+] {0}:{1} OUVERT" -f $ip, $p) -ForegroundColor Green }
    }
}
Write-Host "[+] Terminé. Vérifiez Sysmon (EID 3) et PowerShell (EID 4104) sur WS01, puis le dashboard Wazuh." -ForegroundColor Green
