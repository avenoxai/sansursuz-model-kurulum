# kur.ps1'in yaptığı her şeyi geri alır. Yedek dosyalara dokunmaz.
# Kullanım: powershell -ExecutionPolicy Bypass -File .\kaldir.ps1
$ErrorActionPreference = 'Stop'
$Dizin = Join-Path $HOME '.config\sansursuz'
$Bin = Join-Path $Dizin 'bin'
function Tamam($t) { Write-Host "  [OK] $t" -ForegroundColor Green }

# omp: yalnız bizim yardımcıyı kullanan sağlayıcıları sil
$Omp = Join-Path $HOME '.omp\agent\models.yml'
if (Test-Path $Omp) {
  try {
    $veri = Get-Content $Omp -Raw | ConvertFrom-Json
    $silinen = @()
    foreach ($p in @($veri.providers.PSObject.Properties)) {
      if ("$($p.Value.apiKey)" -like '*sansursuz*anahtar.ps1*') { $veri.providers.PSObject.Properties.Remove($p.Name); $silinen += $p.Name }
    }
    [IO.File]::WriteAllText($Omp, ($veri | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding $false))
    if ($silinen) { Tamam "omp: $($silinen -join ', ') silindi" }
  } catch { Write-Host '  omp: models.yml JSON değil, elle kontrol et' }
}

# DeepSeek Harness bloğu
$Dsh = Join-Path $HOME '.dsh\profiles\desktop\cordis.patch.yml'
if ((Test-Path $Dsh) -and ((Get-Content $Dsh -Raw).Contains('# >>> sansursuz >>>'))) {
  $t = [regex]::Replace((Get-Content $Dsh -Raw), '# >>> sansursuz >>>[\s\S]*?# <<< sansursuz <<<\r?\n?', '')
  [IO.File]::WriteAllText($Dsh, $t, (New-Object Text.UTF8Encoding $false))
  Tamam "DeepSeek Harness: sağlayıcı bloğu silindi (uygulamaya girdiğin anahtarı Models sayfasından sil)"
}

# PATH
if ($env:OS -eq 'Windows_NT') {
  $yol = [Environment]::GetEnvironmentVariable('Path', 'User')
  if ($yol) {
    $yeni = (($yol -split ';') | Where-Object { $_ -and $_ -ne $Bin }) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $yeni, 'User'); Tamam "PATH'ten $Bin çıkarıldı"
  }
}

if (Test-Path $Dizin) { Remove-Item -Recurse -Force $Dizin; Tamam "$Dizin silindi (şifreli anahtarlar dahil)" }
Write-Host "       Claude Code'un ayrı dizini (%USERPROFILE%\.claude-sansursuz) oturum geçmişini tutuyor; istersen elle sil."
Write-Host '       Yeni bir terminal aç.'
