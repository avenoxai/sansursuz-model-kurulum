# Sansürsüz Model Kurulumu

Sansürsüz (abliterated) modelleri tek komutla kendi agent'ına bağlar: **Claude Code**, **omp (Oh My Pi)**, **DeepSeek Harness** ve **OpenCode**.

Anahtarın hiçbir ayar dosyasına yazılmaz. macOS'ta Keychain'e, Linux'ta sistemin şifre deposuna (secret-tool) konur; harness'lar anahtarı oradan okur.

## Kurulum

### macOS ve Linux

```bash
git clone https://github.com/avenoxai/sansursuz-model-kurulum.git
cd sansursuz-model-kurulum
cp .env.example .env
```

`.env` dosyasını aç, anahtarını yapıştır (kullanmadığın sağlayıcıyı boş bırak), sonra:

```bash
./kur.sh
```

### Windows (PowerShell)

```powershell
git clone https://github.com/avenoxai/sansursuz-model-kurulum.git
cd sansursuz-model-kurulum
copy .env.example .env
notepad .env
powershell -ExecutionPolicy Bypass -File .\kur.ps1
```

Windows'ta anahtar, Windows'un kullanıcıya bağlı şifrelemesiyle (DPAPI) saklanır; yalnız senin Windows hesabın çözebilir. Komutlar `%USERPROFILE%\.config\sansursuz\bin` klasörüne `.cmd` olarak kurulur ve bu klasör kullanıcı PATH'ine eklenir, yani hem PowerShell'de hem cmd'de çalışır.

`.env` oluşturmak istemezsen betiği doğrudan çalıştır, anahtarı gizli olarak sorar.

Betik sırasıyla şunları yapar:

1. Anahtarı sağlayıcıya sorup doğrular (yanlış anahtarı kaydetmez).
2. Güvenli depoya koyar, geri okuyarak kontrol eder, `.env`'deki değeri siler.
3. Bilgisayarında kurulu olan harness'ları bulur ve ayarlar (değiştirdiği her dosyanın yedeğini alır).
4. macOS/Linux'ta `~/.zshrc` / `~/.bashrc` içine tek satırlık bir blok ekler; Windows'ta komut klasörünü PATH'e ekler.
5. Her harness'a tek kelimelik bir deneme çağrısı atar ve sonucu gösterir.

Bittiğinde yeni bir terminal aç. Komutlar:

| Harness | Komut |
|---|---|
| Claude Code | `claude-sansursuz` (normal `claude` komutun değişmez) |
| omp | `omp-sansursuz`, `omp-sansursuz-glm`, `omp-venice`, `omp-venice-glm` |
| OpenCode | `opencode-sansursuz` |
| DeepSeek Harness | uygulamada model seçiciden; anahtarı bir kez uygulamanın Models sayfasına gir |

Kaldırmak için: `./kaldir.sh` (Windows: `powershell -ExecutionPolicy Bypass -File .\kaldir.ps1`)

## Sağlayıcılar

| Sağlayıcı | Modeller | Claude Code |
|---|---|---|
| [Refuseless](https://refuseless.com) | DeepSeek V4.1 Flash Abliterated, GLM 5.3 Flash Abliterated, GLM 5.3 Abliterated | Evet (Anthropic formatını da destekliyor) |
| [Venice](https://venice.ai) | DeepSeek V4.1 Flash Uncensored, Abliterated Large V2 | Hayır (yalnız OpenAI formatı) |

İki sağlayıcıdan biri yeterli. Fiyatlar değişebiliyor, sağlayıcının kendi sayfasına bak. Kullandıkça ödersin; abonelik gibi değil. Küçük bir miktarla dene.

## Elle kurmak ya da ne değiştiğini görmek

Her harness'ta hangi dosyaya ne yazıldığı, hangi alana ne girildiği: [MANUEL.md](MANUEL.md)

Aynısının slayt hali: `sunum/index.html` (tarayıcıda aç, ok tuşlarıyla ilerle).

## Bir agent'a kurdurmak

Bu repoyu Claude Code, omp ya da Codex ile açıp "bunu kur" diyebilirsin; talimat [AGENTS.md](AGENTS.md)'de. Anahtarı agent'a söyleme: `.env`'yi kendin doldur ya da `./kur.sh`'i kendi terminalinde çalıştır.

## Kullanmadan önce

- **Araç çağrılarını onaya bağla.** Bu modellere bilgisayarına erişim veriyorsun ve modelin ayarlarıyla oynanmış. omp kısayolları her araç çağrısında onay sorar; Claude Code da varsayılan olarak sorar. Bunu kapatma.
- **İhtiyacın yoksa normal modeli kullan.** Sansürsüz hale getirilen modeller biraz aptallaşıyor ve tuhaf davranabiliyor.
- **Sorumluluk sende.** Arkada "bunu yapamazsın" diyen bir şirket olmaması, yaptığın her şeyin sorunsuz olduğu anlamına gelmez. Yasa dışı işlere girme.
- Yazdığın her şey (promptlar, açtığın dosyalar) seçtiğin sağlayıcıya gider. Hassas projelerde kullanma.

## Destek

| Sistem | Betik | Anahtar deposu | Gerekenler |
|---|---|---|---|
| macOS | `kur.sh` | Keychain | `bash`, `curl`, `python3` |
| Linux | `kur.sh` | secret-tool (yoksa yalnız senin okuyabildiğin dosya, izin 600) | `bash`, `curl`, `python3` |
| Windows | `kur.ps1` | DPAPI ile şifreli dosya | PowerShell 5.1 ya da 7 |

WSL kullanıyorsan WSL içinde `kur.sh` çalıştır.
- Bu repo sağlayıcılarla bağlantılı değildir.

Lisans: MIT
