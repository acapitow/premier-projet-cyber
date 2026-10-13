<#
    configure-audit-policy.ps1 — SOC Home Lab / DC01
    Auteur : André Capito (@acapitow)

    Active la POLITIQUE D'AUDIT AVANCÉE nécessaire pour produire les Event IDs
    exploités par les détections (ouvertures de session, Kerberos, comptes...).

    Référence Microsoft : "Advanced security audit policy settings".
    Exécuté par Ansible (voir tasks/main.yml).
#>

$ErrorActionPreference = "Stop"
Write-Host "[*] Configuration de la politique d'audit avancee..."

# Table : "Sous-catégorie d'audit" => succès/échec à activer.
# Ces sous-catégories génèrent notamment :
#   Logon           -> 4624 (succès) / 4625 (échec)
#   Kerberos Auth   -> 4768 (TGT) / 4771 (pre-auth échouée)
#   Kerberos Svc    -> 4769 (TGS, utile Kerberoasting)
#   Account Lockout -> 4740
#   User Account Mgmt / Security Group Mgmt -> 4720/4722/4724/4728...
$subcategories = @{
    "Logon"                         = "enable:enable"   # success:failure
    "Logoff"                        = "enable:disable"
    "Account Lockout"               = "disable:enable"
    "Kerberos Authentication Service" = "enable:enable"
    "Kerberos Service Ticket Operations" = "enable:enable"
    "Credential Validation"         = "enable:enable"
    "User Account Management"       = "enable:enable"
    "Security Group Management"     = "enable:enable"
    "Computer Account Management"   = "enable:enable"
    "Process Creation"              = "enable:enable"   # 4688 (si activé côté stratégie)
    "Special Logon"                 = "enable:enable"   # 4672
}

foreach ($name in $subcategories.Keys) {
    $parts   = $subcategories[$name].Split(":")
    $success = if ($parts[0] -eq "enable") { "enable" } else { "disable" }
    $failure = if ($parts[1] -eq "enable") { "enable" } else { "disable" }
    Write-Host ("    - {0,-38} success:{1} failure:{2}" -f $name, $success, $failure)
    & auditpol /set /subcategory:"$name" /success:$success /failure:$failure | Out-Null
}

# Activer la capture de la ligne de commande dans l'event 4688 (très utile en SOC).
$key = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit"
if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
New-ItemProperty -Path $key -Name "ProcessCreationIncludeCmdLine_Enabled" `
    -Value 1 -PropertyType DWord -Force | Out-Null

Write-Host "[+] Politique d'audit avancee appliquee."
& auditpol /get /category:"Logon/Logoff","Account Logon","Account Management" | Out-String | Write-Host
