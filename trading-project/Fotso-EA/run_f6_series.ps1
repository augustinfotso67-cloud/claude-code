$ErrorActionPreference = "SilentlyContinue"
$term = "C:\Program Files\MetaTrader 5\terminal64.exe"
$inis = @("f6_base","f6_notrail","f6_naked")
$dir  = "C:\Users\User\Fotso-EA"

foreach($n in $inis){
    Write-Output "=== Lancement $n a $(Get-Date -Format HH:mm:ss) ==="
    Start-Process -FilePath $term -ArgumentList "/config:$dir\$n.ini" | Out-Null
    Start-Sleep -Seconds 6
    $waited = 0
    while((Get-Process terminal64 -ErrorAction SilentlyContinue) -and $waited -lt 180){
        Start-Sleep -Seconds 3; $waited += 3
    }
    Start-Sleep -Seconds 2
    Write-Output "    $n termine (attente $waited s)"
}
Write-Output "=== SERIE TERMINEE a $(Get-Date -Format HH:mm:ss) ==="
# localiser les CSV produits
Get-ChildItem "C:\Users\User\AppData\Roaming\MetaQuotes\Tester" -Recurse -Filter "Fotso_F6_*.csv" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    ForEach-Object { "{0}  {1:N0} Ko  {2}" -f $_.Name, ($_.Length/1KB), $_.LastWriteTime }
