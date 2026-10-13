# Journaux attendus — Scénario 03 (scan Nmap)

Événements Sysmon EventID 3 (connexion réseau) sur l'hôte qui lance le scan (WS01).
Résumé JSON simplifié des champs clés — une entrée par port sondé, même source.

```json
[
  {"EventID":3,"SourceIp":"10.20.0.20","DestinationIp":"10.20.0.30","DestinationPort":22, "Image":"C:\\lab\\nmap\\nmap.exe"},
  {"EventID":3,"SourceIp":"10.20.0.20","DestinationIp":"10.20.0.30","DestinationPort":80, "Image":"C:\\lab\\nmap\\nmap.exe"},
  {"EventID":3,"SourceIp":"10.20.0.20","DestinationIp":"10.20.0.10","DestinationPort":445,"Image":"C:\\lab\\nmap\\nmap.exe"},
  {"EventID":3,"SourceIp":"10.20.0.20","DestinationIp":"10.20.0.10","DestinationPort":389,"Image":"C:\\lab\\nmap\\nmap.exe"},
  {"EventID":3,"SourceIp":"10.20.0.20","DestinationIp":"10.20.0.10","DestinationPort":88, "Image":"C:\\lab\\nmap\\nmap.exe"}
]
```

## Points d'analyse

- **Même `SourceIp`** vers un **grand nombre de `DestinationPort` distincts** en peu de
  temps → signature d'un balayage (déclenche Wazuh `100301` au-delà de 20 ports/60 s).
- `Image` révèle l'outil : `nmap.exe`, ou `powershell.exe` si lancé via
  `ws01-portsweep.ps1` (à corréler alors avec PowerShell EID 4104).
- Plusieurs `DestinationIp` balayées = découverte à l'échelle du sous-réseau.

## Event IDs de référence

| Event ID | Source | Description |
|----------|--------|-------------|
| 3 | Sysmon | Network connection detected |
| 4104 | PowerShell/Operational | Script Block Logging (si sweep PowerShell) |
| 5156 | Security (WFP) | *(extension)* The Windows Filtering Platform permitted a connection |
