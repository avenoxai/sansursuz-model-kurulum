# Sansürsüz (abliterated) modelleri Windows'ta Claude Code, omp, OpenCode ve DeepSeek Harness'a bağlar.
# Kullanım (PowerShell):  powershell -ExecutionPolicy Bypass -File .\kur.ps1
#                         powershell -ExecutionPolicy Bypass -File .\kur.ps1 -TestYok
# Anahtar hiçbir ayar dosyasına düz metin yazılmaz: Windows'un kullanıcıya bağlı şifrelemesiyle (DPAPI)
# saklanır; yalnız senin Windows hesabın çözebilir.
param([switch]$TestYok)
$ErrorActionPreference = 'Stop'

$Repo   = Split-Path -Parent $MyInvocation.MyCommand.Path
$Dizin  = Join-Path $HOME '.config\sansursuz'
$Bin    = Join-Path $Dizin 'bin'
$Tarih  = Get-Date -Format 'yyyyMMdd-HHmmss'
$Windows = ($env:OS -eq 'Windows_NT')
$TestOrtami = ($env:SANSURSUZ_TEST -eq '1')   # yalnız geliştirme: Windows dışı pwsh'ta mantığı denemek için

function Baslik($t) { Write-Host ''; Write-Host $t -ForegroundColor White }
function Tamam($t)  { Write-Host "  [OK] $t" -ForegroundColor Green }
function Uyari($t)  { Write-Host "  [!]  $t" -ForegroundColor Yellow }
function Hata($t)   { Write-Host "  [X]  $t" -ForegroundColor Red }
function Bilgi($t)  { Write-Host "       $t" }
function YazUtf8($yol, $metin) { [IO.File]::WriteAllText($yol, $metin, (New-Object Text.UTF8Encoding $false)) }

if (-not $Windows -and -not $TestOrtami) {
  Hata 'Bu betik Windows içindir. macOS ve Linux için ./kur.sh kullan.'
  exit 1
}

# ---------- 1. Anahtarlar ----------
Baslik '1. Anahtarlar'

function EnvOku($ad) {
  $f = Join-Path $Repo '.env'
  if (-not (Test-Path $f)) { return '' }
  $deger = ''
  foreach ($satir in Get-Content $f) {
    if ($satir -match "^\s*$ad\s*=\s*(.*)$") { $deger = $Matches[1].Trim().Trim('"').Trim("'") }
  }
  return $deger
}

function Sor($etiket) {
  if ([Console]::IsInputRedirected) { return '' }
  $sec = Read-Host -AsSecureString "  $etiket API anahtarı (atlamak için Enter)"
  $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
}

$Refuseless = EnvOku 'REFUSELESS_API_KEY'
$Venice = EnvOku 'VENICE_API_KEY'

$Yardimci = Join-Path $Dizin 'anahtar.ps1'
if (-not $Refuseless -and -not $Venice -and (Test-Path $Yardimci)) {
  # yeniden kurulum: depodakini kullan
  try { $Refuseless = (& $Yardimci refuseless | Out-String).Trim() } catch { $Refuseless = '' }
  try { $Venice = (& $Yardimci venice | Out-String).Trim() } catch { $Venice = '' }
  if ($Refuseless -or $Venice) { Tamam 'Önceki kurulumdaki anahtarlar kullanılıyor' }
}
if (-not $Refuseless) { $Refuseless = Sor 'Refuseless' }
if (-not $Venice) { $Venice = Sor 'Venice' }
if (-not $Refuseless -and -not $Venice) {
  Hata 'Hiç anahtar yok. .env.example dosyasını .env olarak kopyala ve doldur, ya da betik sorduğunda yapıştır.'
  exit 1
}

function Dogrula($url, $deger) {
  try {
    $r = Invoke-WebRequest -Uri $url -Headers @{ Authorization = "Bearer $deger" } -UseBasicParsing -TimeoutSec 20
    return ($r.StatusCode -eq 200)
  } catch { return $false }
}
if ($Refuseless) {
  if (Dogrula 'https://api.refuseless.com/v1/models' $Refuseless) { Tamam 'Refuseless anahtarı geçerli' }
  else { Hata 'Refuseless anahtarı reddedildi (ya da bağlantı yok). Atlıyorum.'; $Refuseless = '' }
}
if ($Venice) {
  if (Dogrula 'https://api.venice.ai/api/v1/api_keys/rate_limits' $Venice) { Tamam 'Venice anahtarı geçerli' }
  else { Hata 'Venice anahtarı reddedildi (ya da bağlantı yok). Atlıyorum.'; $Venice = '' }
}
if (-not $Refuseless -and -not $Venice) { Hata 'Geçerli anahtar kalmadı.'; exit 1 }

# ---------- 2. Güvenli depo ----------
Baslik '2. Anahtarları güvenli depoya koyma'
New-Item -ItemType Directory -Force -Path $Dizin, $Bin | Out-Null

# Tüm harness'ların anahtarı okuduğu tek yardımcı
@'
param([Parameter(Mandatory=$true)][string]$Servis)
# Anahtarı ekrana değil, çağıran programa verir. Yalnız bu Windows hesabı çözebilir (DPAPI).
$f = Join-Path $HOME ".config\sansursuz\$Servis.anahtar"
if (-not (Test-Path $f)) { exit 1 }
if ($env:OS -eq 'Windows_NT') {
  $sec = Get-Content $f | ConvertTo-SecureString
  $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
} else {
  (Get-Content $f -Raw).Trim()
}
'@ | Set-Content -Path $Yardimci -Encoding UTF8

function Sakla($servis, $deger) {
  $f = Join-Path $Dizin "$servis.anahtar"
  if ($Windows) {
    ConvertTo-SecureString $deger -AsPlainText -Force | ConvertFrom-SecureString | Set-Content -Path $f
  } else {
    Set-Content -Path $f -Value $deger -NoNewline; chmod 600 $f
  }
  $geri = (& $Yardimci $servis | Out-String).Trim()
  return ($geri -eq $deger)
}
foreach ($s in @(@('refuseless', $Refuseless, 'Refuseless'), @('venice', $Venice, 'Venice'))) {
  if (-not $s[1]) { continue }
  if (Sakla $s[0] $s[1]) { Tamam "$($s[2]) anahtarı şifreli depoda (DPAPI)" }
  else { Hata "$($s[2]) anahtarı depoya yazılamadı. .env'ye dokunmadım."; exit 1 }
}
$HasR = [bool]$Refuseless; $HasV = [bool]$Venice
$Refuseless = $null; $Venice = $null

$EnvDosya = Join-Path $Repo '.env'
if (Test-Path $EnvDosya) {
  $icerik = Get-Content $EnvDosya
  if ($icerik -match '^(REFUSELESS|VENICE)_API_KEY=.+') {
    ($icerik -replace '^((REFUSELESS|VENICE)_API_KEY=).*', '$1') | Set-Content $EnvDosya
    Tamam '.env içindeki anahtar değerleri silindi (artık depoda)'
  }
}

# ---------- 3. Harness'lar ----------
Baslik "3. Harness'lar"
$AnahtarKomutu = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$Yardimci`""
$Sonuc = @()

function Yaz-Cmd($ad, $satirlar) {
  $yol = Join-Path $Bin "$ad.cmd"
  (@('@echo off', 'setlocal') + $satirlar) -join "`r`n" | Set-Content -Path $yol -Encoding ASCII
}
function AnahtarSatiri($degisken, $servis) {
  return "for /f `"usebackq delims=`" %%k in (``$AnahtarKomutu $servis``) do set `"$degisken=%%k`""
}
function Var($komut) { return [bool](Get-Command $komut -ErrorAction SilentlyContinue) }

# 3a. Claude Code (yalnız Refuseless: Claude Code Anthropic formatı konuşur, Venice desteklemiyor)
if (Var 'claude') {
  if ($HasR) {
    Yaz-Cmd 'claude-sansursuz' @(
      'set "ANTHROPIC_BASE_URL=https://api.refuseless.com"',
      (AnahtarSatiri 'ANTHROPIC_AUTH_TOKEN' 'refuseless'),
      'set "ANTHROPIC_MODEL=deepseek-v4.1-flash-abliterated"',
      'set "ANTHROPIC_DEFAULT_OPUS_MODEL=glm-5.3-abliterated"',
      'set "ANTHROPIC_DEFAULT_SONNET_MODEL=deepseek-v4.1-flash-abliterated"',
      'set "ANTHROPIC_DEFAULT_HAIKU_MODEL=glm-5.3-flash-abliterated"',
      'set "CLAUDE_CODE_SUBAGENT_MODEL=deepseek-v4.1-flash-abliterated"',
      'set "CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000"',
      'set "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"',
      'set "CLAUDE_CONFIG_DIR=%USERPROFILE%\.claude-sansursuz"',
      'call claude %*')
    Tamam 'Claude Code: claude-sansursuz komutu hazır'; $Sonuc += 'claude'
  } else { Uyari "Claude Code: Venice Claude Code'un formatını konuşmuyor, Refuseless anahtarı gerekli. Atlandı." }
} else { Bilgi 'Claude Code kurulu değil, atlandı.' }

# 3b. omp: ~/.omp/agent/models.yml (JSON, geçerli YAML)
function Model($id, $ad, $baglam) { return [ordered]@{ id = $id; name = $ad; contextWindow = $baglam; maxTokens = 131072 } }
if (Var 'omp') {
  $OmpDosya = Join-Path $HOME '.omp\agent\models.yml'
  New-Item -ItemType Directory -Force -Path (Split-Path $OmpDosya) | Out-Null
  $yeni = [ordered]@{}
  if ($HasR) { $yeni['refuseless'] = [ordered]@{ baseUrl = 'https://api.refuseless.com/v1'; api = 'openai-completions'; apiKey = "!$AnahtarKomutu refuseless"
      models = @((Model 'deepseek-v4.1-flash-abliterated' 'DeepSeek V4.1 Flash Abliterated' 1048576), (Model 'glm-5.3-flash-abliterated' 'GLM 5.3 Flash Abliterated' 1048576), (Model 'glm-5.3-abliterated' 'GLM 5.3 Abliterated' 1048576)) } }
  if ($HasV) { $yeni['venice'] = [ordered]@{ baseUrl = 'https://api.venice.ai/api/v1'; api = 'openai-completions'; apiKey = "!$AnahtarKomutu venice"
      models = @((Model 'deepseek-v4-1-flash-uncensored' 'DeepSeek V4.1 Flash Uncensored (Venice)' 1000000), (Model 'abliteration-abliterated-model-large-v2' 'Abliterated Large V2 (Venice)' 1000000)) } }
  $birlesti = $true
  $veri = [pscustomobject]@{ providers = [pscustomobject]@{} }
  if ((Test-Path $OmpDosya) -and (Get-Item $OmpDosya).Length -gt 0) {
    Copy-Item $OmpDosya "$OmpDosya.sansursuz-yedek-$Tarih"
    try { $veri = Get-Content $OmpDosya -Raw | ConvertFrom-Json } catch { $birlesti = $false }
    if ($birlesti -and -not $veri.PSObject.Properties['providers']) { $veri | Add-Member providers ([pscustomobject]@{}) }
  }
  if ($birlesti) {
    foreach ($ad in $yeni.Keys) {
      $eski = $veri.providers.PSObject.Properties[$ad]
      if ($eski) {
        $bizim = $yeni[$ad].models | ForEach-Object { $_.id }
        $korunan = @($eski.Value.models | Where-Object { $bizim -notcontains $_.id })
        $yeni[$ad].models = @($yeni[$ad].models) + $korunan
        $veri.providers.PSObject.Properties.Remove($ad)
      }
      $veri.providers | Add-Member -NotePropertyName $ad -NotePropertyValue ([pscustomobject]$yeni[$ad])
    }
    YazUtf8 $OmpDosya ($veri | ConvertTo-Json -Depth 20)
    Tamam "omp: $($yeni.Keys -join ', ') eklendi"
    $kisayol = @()
    if ($HasR) { $kisayol += ,@('omp-sansursuz', 'refuseless/deepseek-v4.1-flash-abliterated'); $kisayol += ,@('omp-sansursuz-glm', 'refuseless/glm-5.3-abliterated') }
    if ($HasV) { $kisayol += ,@('omp-venice', 'venice/deepseek-v4-1-flash-uncensored'); $kisayol += ,@('omp-venice-glm', 'venice/abliteration-abliterated-model-large-v2') }
    foreach ($k in $kisayol) { Yaz-Cmd $k[0] @("call omp --model $($k[1]) --approval-mode always-ask %*") }
    $Sonuc += 'omp'
  } else {
    Uyari "omp: models.yml YAML biçiminde, otomatik birleştirmedim. MANUEL.md > omp bölümündeki bloğu 'providers:' altına ekle."
  }
} else { Bilgi 'omp kurulu değil, atlandı.' }

# 3c. OpenCode: kendi ayarına dokunmaz, ayrı dosya OPENCODE_CONFIG ile yüklenir
if (Var 'opencode') {
  $saglayici = [ordered]@{}
  function OcModel($ad, $baglam) { return [ordered]@{ name = $ad; tool_call = $true; limit = [ordered]@{ context = $baglam; output = 131072 } } }
  if ($HasR) { $saglayici['refuseless'] = [ordered]@{ npm = '@ai-sdk/openai-compatible'; name = 'Refuseless'; options = [ordered]@{ baseURL = 'https://api.refuseless.com/v1'; apiKey = '{env:REFUSELESS_API_KEY}' }
      models = [ordered]@{ 'deepseek-v4.1-flash-abliterated' = (OcModel 'DeepSeek V4.1 Flash Abliterated' 1048576); 'glm-5.3-flash-abliterated' = (OcModel 'GLM 5.3 Flash Abliterated' 1048576); 'glm-5.3-abliterated' = (OcModel 'GLM 5.3 Abliterated' 1048576) } } }
  if ($HasV) { $saglayici['venice'] = [ordered]@{ npm = '@ai-sdk/openai-compatible'; name = 'Venice'; options = [ordered]@{ baseURL = 'https://api.venice.ai/api/v1'; apiKey = '{env:VENICE_API_KEY}' }
      models = [ordered]@{ 'deepseek-v4-1-flash-uncensored' = (OcModel 'DeepSeek V4.1 Flash Uncensored' 1000000); 'abliteration-abliterated-model-large-v2' = (OcModel 'Abliterated Large V2' 1000000) } } }
  $OcDosya = Join-Path $Dizin 'opencode.json'
  YazUtf8 $OcDosya ([ordered]@{ '$schema' = 'https://opencode.ai/config.json'; provider = $saglayici } | ConvertTo-Json -Depth 20)
  $satirlar = @("set `"OPENCODE_CONFIG=$OcDosya`"")
  if ($HasR) { $satirlar += (AnahtarSatiri 'REFUSELESS_API_KEY' 'refuseless') }
  if ($HasV) { $satirlar += (AnahtarSatiri 'VENICE_API_KEY' 'venice') }
  Yaz-Cmd 'opencode-sansursuz' ($satirlar + @('call opencode %*'))
  Tamam 'OpenCode: opencode-sansursuz komutu hazır'; $Sonuc += 'opencode'
} else { Bilgi 'OpenCode kurulu değil, atlandı.' }

# 3d. DeepSeek Harness: sağlayıcıyı profile ekler, anahtarı uygulamanın Models sayfasına sen girersin
$DshPatch = Join-Path $HOME '.dsh\profiles\desktop\cordis.patch.yml'
if (Test-Path (Join-Path $HOME '.dsh')) {
  $BAS = '# >>> sansursuz >>>'; $SON = '# <<< sansursuz <<<'
  function DshSaglayici($ad, $gorunen, $ref, $url, $modeller, $baglam) {
    $s = @("      ${ad}:", "        displayName: $gorunen", "        apiKeyEnv: $ref", '        api: openai-completions', "        baseURL: $url", '        models:')
    foreach ($m in $modeller) { $s += @("          - id: $m", "            name: $m", "            contextWindow: $baglam") }
    return $s
  }
  $govde = @()
  if ($HasR) { $govde += DshSaglayici 'refuseless' 'Refuseless' 'REFUSELESS_API_KEY' 'https://api.refuseless.com/v1' @('deepseek-v4.1-flash-abliterated', 'glm-5.3-flash-abliterated', 'glm-5.3-abliterated') 1048576 }
  if ($HasV) { $govde += DshSaglayici 'venice' 'Venice' 'VENICE_API_KEY' 'https://api.venice.ai/api/v1' @('deepseek-v4-1-flash-uncensored', 'abliteration-abliterated-model-large-v2') 1000000 }
  $blok = (@($BAS, '- id: llm-pi-ai', '  name: "@deepseek-ai/dsh-llm-pi-ai"', '  config:', '    providers:') + $govde + @($SON)) -join "`n"
  $metin = ''
  if (Test-Path $DshPatch) { $metin = Get-Content $DshPatch -Raw; Copy-Item $DshPatch "$DshPatch.sansursuz-yedek-$Tarih" }
  if ($metin -and $metin.Contains($BAS)) {
    $metin = [regex]::Replace($metin, [regex]::Escape($BAS) + '[\s\S]*?' + [regex]::Escape($SON), $blok.Replace('$', '$$'))
    YazUtf8 $DshPatch $metin; Tamam 'DeepSeek Harness: sağlayıcı bloğu güncellendi'
  } elseif ($metin -and $metin -match 'id:\s*llm-pi-ai') {
    Uyari 'DeepSeek Harness: profilde zaten bir llm-pi-ai girdisi var, dokunmadım. Sağlayıcıyı uygulamanın Models sayfasından ekle (MANUEL.md).'
  } else {
    New-Item -ItemType Directory -Force -Path (Split-Path $DshPatch) | Out-Null
    $yeniMetin = $metin.TrimEnd("`r", "`n"); if ($yeniMetin) { $yeniMetin += "`n" }
    YazUtf8 $DshPatch ($yeniMetin + $blok + "`n")
    Tamam 'DeepSeek Harness: sağlayıcılar profile eklendi'
  }
  Bilgi 'Anahtarı uygulamanın içinden gir: Ayarlar > Models > sağlayıcı > API key. Sonra uygulamayı yeniden başlat.'
  $Sonuc += 'dsh'
} else { Bilgi 'DeepSeek Harness bulunamadı, atlandı.' }

# ---------- 4. PATH ----------
Baslik '4. Komutları PATH''e ekleme'
if ($Windows) {
  $yol = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (-not $yol) { $yol = '' }
  if (($yol -split ';') -notcontains $Bin) {
    [Environment]::SetEnvironmentVariable('Path', ($yol.TrimEnd(';') + ';' + $Bin).TrimStart(';'), 'User')
    Tamam "$Bin kullanıcı PATH'ine eklendi"
  } else { Tamam "$Bin zaten PATH'te" }
  $env:Path = $env:Path + ';' + $Bin
} else { Bilgi 'Test ortamı: PATH değiştirilmedi.' }

# ---------- 5. Deneme ----------
if (-not $TestYok -and $Windows) {
  Baslik '5. Deneme (tek kelimelik çağrı)'
  $P = '"Reply with exactly one word: merhaba"'
  function Dene($ad, $komut) {
    Push-Location $env:TEMP
    try { $cikti = (cmd /c "$komut < NUL 2>NUL") | Where-Object { $_.Trim() } | Select-Object -Last 1 } catch { $cikti = '' }
    Pop-Location
    if ($cikti -match 'merhaba') { Tamam "${ad}: $cikti" } else { Hata "${ad}: cevap alınamadı ($cikti)" }
  }
  foreach ($h in $Sonuc) {
    switch ($h) {
      'claude'   { Dene 'Claude Code (Refuseless)' "claude-sansursuz -p $P" }
      'omp'      { if ($HasR) { Dene 'omp (Refuseless)' "omp -p --no-session --no-tools --model refuseless/deepseek-v4.1-flash-abliterated $P" }
                   if ($HasV) { Dene 'omp (Venice)' "omp -p --no-session --no-tools --model venice/deepseek-v4-1-flash-uncensored $P" } }
      'opencode' { if ($HasR) { Dene 'OpenCode (Refuseless)' "opencode-sansursuz run -m refuseless/deepseek-v4.1-flash-abliterated $P" }
                   if ($HasV) { Dene 'OpenCode (Venice)' "opencode-sansursuz run -m venice/deepseek-v4-1-flash-uncensored $P" } }
      'dsh'      { Bilgi 'DeepSeek Harness masaüstü uygulaması, denemesini uygulamada yap.' }
    }
  }
}

Baslik 'Bitti'
Bilgi 'Yeni bir terminal aç (PowerShell ya da cmd). Komutlar:'
foreach ($h in $Sonuc) {
  switch ($h) {
    'claude'   { Bilgi '  claude-sansursuz' }
    'omp'      { Bilgi '  omp-sansursuz, omp-sansursuz-glm, omp-venice, omp-venice-glm (anahtarın olanlar)' }
    'opencode' { Bilgi '  opencode-sansursuz' }
    'dsh'      { Bilgi '  DeepSeek Harness: uygulamada model seçiciden' }
  }
}
Bilgi 'Kaldırmak için: powershell -ExecutionPolicy Bypass -File .\kaldir.ps1'
