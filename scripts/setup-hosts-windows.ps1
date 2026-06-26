# Run as Administrator in PowerShell:
#   Right-click PowerShell -> Run as administrator
#   cd C:\Users\guslc\project\terraform\scripts
#   .\setup-hosts-windows.ps1

$ErrorActionPreference = "Stop"

$LbHost = "a1189548d18be43258d6420f9e45fb7c-1131554573.us-east-1.elb.amazonaws.com"
$Ip = ([System.Net.Dns]::GetHostAddresses($LbHost) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1).IPAddressToString

if (-not $Ip) {
    Write-Error "Could not resolve $LbHost"
}

$Hosts = @(
    "credit.local",
    "mlflow.local",
    "llm.local",
    "langgraph.local",
    "trino.local",
    "minio.local",
    "airflow.local"
)

$Marker = "# data-platform EKS ingress"
$Line = "$Ip  $($Hosts -join ' ')"
$HostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"

$content = Get-Content $HostsPath -Raw
$pattern = "(?ms)^$([regex]::Escape($Marker)).*?$(?=\r?\n#|\r?\n[^\r\n#]|\z)"
$content = [regex]::Replace($content, $pattern, "").TrimEnd()

$newBlock = "`r`n`r`n$Marker`r`n$Line`r`n"
Set-Content -Path $HostsPath -Value ($content + $newBlock) -Encoding ascii

Write-Host "Updated $HostsPath"
Write-Host "IP: $Ip"
Write-Host ""
Write-Host "Open in browser:"
foreach ($h in $Hosts) {
    Write-Host "  http://$h"
}
