# Elle kurulum: hangi harness'ta nereye ne yazılır

`kur.sh` bunların hepsini senin yerine yapar. Bu sayfa ne değiştiğini görmek, ya da betiği çalıştırmadan elle kurmak isteyenler için.

Her harness'ta aynı üç bilgiyi veriyorsun:

| Bilgi | Refuseless | Venice |
|---|---|---|
| Adres (base URL) | `https://api.refuseless.com/v1` | `https://api.venice.ai/api/v1` |
| Anahtar | panel > API Keys | Settings > API Keys |
| Model adı | `deepseek-v4.1-flash-abliterated`, `glm-5.3-flash-abliterated`, `glm-5.3-abliterated` | `deepseek-v4-1-flash-uncensored`, `abliteration-abliterated-model-large-v2` |
| API formatı | OpenAI uyumlu **ve** Anthropic uyumlu | yalnız OpenAI uyumlu |

Fark yaratan tek şey API formatı: Claude Code Anthropic formatı konuşur, o yüzden Claude Code'a yalnız Refuseless doğrudan bağlanır.

## 0. Anahtarı dosyaya değil, güvenli depoya koy

macOS:

```bash
security add-generic-password -U -s sansursuz-refuseless -a "$USER" -w
```

Komut anahtarı sorar, ekranda görünmez. Okumak için: `security find-generic-password -s sansursuz-refuseless -a "$USER" -w`. Venice için `sansursuz-venice`.

Linux: `secret-tool store --label="sansursuz refuseless" uygulama sansursuz servis refuseless`

Windows (PowerShell): `Read-Host -AsSecureString | ConvertFrom-SecureString | Set-Content $HOME\.config\sansursuz\refuseless.anahtar` (DPAPI ile şifreli, yalnız senin hesabın çözer). Windows'ta ortam değişkenleri `set "AD=deger"` ile bir `.cmd` dosyasında verilir; `kur.ps1`'in ürettiği `claude-sansursuz.cmd` dosyasına bakabilirsin.

Aşağıdaki örneklerde anahtar hep bu depodan okunuyor; hiçbir ayar dosyasında anahtarın kendisi yok.

## 1. Claude Code

**Nerede:** Ayar dosyası yok, ortam değişkenleri. `~/.zshrc` (ya da `~/.bashrc`) içine bir fonksiyon.

```bash
claude-sansursuz() {
  ANTHROPIC_BASE_URL="https://api.refuseless.com" \
  ANTHROPIC_AUTH_TOKEN="$(security find-generic-password -s sansursuz-refuseless -a "$USER" -w)" \
  ANTHROPIC_MODEL="deepseek-v4.1-flash-abliterated" \
  ANTHROPIC_DEFAULT_OPUS_MODEL="glm-5.3-abliterated" \
  ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-v4.1-flash-abliterated" \
  ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-5.3-flash-abliterated" \
  CLAUDE_CODE_SUBAGENT_MODEL="deepseek-v4.1-flash-abliterated" \
  CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000 \
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
  CLAUDE_CONFIG_DIR="$HOME/.claude-sansursuz" \
  command claude "$@"
}
```

| Değişken | Ne işe yarar |
|---|---|
| `ANTHROPIC_BASE_URL` | Adres. Sonuna `/v1` koyma, Claude Code kendisi ekliyor. |
| `ANTHROPIC_AUTH_TOKEN` | Anahtar. |
| `ANTHROPIC_MODEL` | Açılışta kullanılan model. |
| `ANTHROPIC_DEFAULT_OPUS/SONNET/HAIKU_MODEL` | `/model` menüsündeki Opus, Sonnet, Haiku seçenekleri hangi modele gitsin. |
| `CLAUDE_CODE_SUBAGENT_MODEL` | Alt ajanların modeli. |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | Claude Code bu modelleri tanımadığı için bağlamı 200K sanıyor; 1 milyon olduğunu söylüyoruz. |
| `CLAUDE_CONFIG_DIR` | Ayrı ayar klasörü. Asıl Claude girişin, CLAUDE.md'n, hafızan, hook ve MCP'lerin bu sağlayıcıya gitmez. |

Kullanım: `claude-sansursuz`. Normal `claude` komutu hiç değişmez. İlk açılışta tema ve klasör güveni sorar (ayrı klasör olduğu için).

Venice'i Claude Code'a bağlamak isteyen: arada OpenAI formatını Anthropic formatına çeviren bir ara katman (proxy) gerekir. Bu repo onu kurmaz.

## 2. omp (Oh My Pi)

**Nerede:** `~/.omp/agent/models.yml` (YAML; JSON da yazabilirsin, JSON geçerli YAML'dır).

```yaml
providers:
  refuseless:
    baseUrl: https://api.refuseless.com/v1
    api: openai-completions
    apiKey: "!security find-generic-password -s sansursuz-refuseless -a $USER -w"
    models:
      - { id: deepseek-v4.1-flash-abliterated, name: DeepSeek V4.1 Flash Abliterated, contextWindow: 1048576, maxTokens: 131072 }
      - { id: glm-5.3-flash-abliterated, name: GLM 5.3 Flash Abliterated, contextWindow: 1048576, maxTokens: 131072 }
      - { id: glm-5.3-abliterated, name: GLM 5.3 Abliterated, contextWindow: 1048576, maxTokens: 131072 }
  venice:
    baseUrl: https://api.venice.ai/api/v1
    api: openai-completions
    apiKey: "!security find-generic-password -s sansursuz-venice -a $USER -w"
    models:
      - { id: deepseek-v4-1-flash-uncensored, name: DeepSeek V4.1 Flash Uncensored, contextWindow: 1000000, maxTokens: 131072 }
      - { id: abliteration-abliterated-model-large-v2, name: Abliterated Large V2, contextWindow: 1000000, maxTokens: 131072 }
```

`apiKey` üç şekilde yazılabilir: `!komut` (komutun çıktısı anahtar olur, önerilen), bir ortam değişkeninin adı, ya da anahtarın kendisi (önerilmez).

Kullanım: `omp --model refuseless/deepseek-v4.1-flash-abliterated` ya da omp içinde `/model`. Kısayol ve araç onayı:

```bash
omp-sansursuz() { command omp --model refuseless/deepseek-v4.1-flash-abliterated --approval-mode always-ask "$@"; }
```

`--approval-mode always-ask` her araç çağrısında onay sorar. Bu modellere bilgisayarına erişim veriyorsun; onayı kapatma.

## 3. DeepSeek Harness

**Nerede:** Uygulamanın Models sayfası, ya da `~/.dsh/profiles/desktop/cordis.patch.yml`.

En kolay yol uygulamanın içinden: Ayarlar > Models > yeni sağlayıcı. Doldurulacaklar:

| Alan | Değer |
|---|---|
| API tipi | OpenAI completions (OpenAI uyumlu) |
| Base URL | `https://api.refuseless.com/v1` |
| API key | anahtarın (uygulama kendi deposunda saklar) |
| Modeller | `deepseek-v4.1-flash-abliterated`, `glm-5.3-flash-abliterated`, `glm-5.3-abliterated` |

Dosyadan: `cordis.patch.yml` (dikkat: `cordis.yml` değil):

```yaml
- id: llm-pi-ai
  name: "@deepseek-ai/dsh-llm-pi-ai"
  config:
    providers:
      refuseless:
        displayName: Refuseless
        apiKeyEnv: REFUSELESS_API_KEY
        api: openai-completions
        baseURL: https://api.refuseless.com/v1
        models:
          - { id: deepseek-v4.1-flash-abliterated, name: deepseek-v4.1-flash-abliterated, contextWindow: 1048576 }
```

`apiKeyEnv` anahtarın kendisi değil, adıdır. Değeri uygulamaya bir kez girersin. Uygulama değeri önce kendi deposunda, sonra ortam değişkeninde arar. Dosyayı değiştirdikten sonra uygulamayı yeniden başlat. Varsayılan model için:

```yaml
- id: agent-default-model
  name: "@deepseek-ai/dsh-agent-default-model"
  config:
    provider: refuseless
    model: deepseek-v4.1-flash-abliterated
```

## 4. OpenCode (bonus)

**Nerede:** `~/.config/opencode/opencode.json`, ya da kendi ayarına dokunmadan ayrı bir dosya + `OPENCODE_CONFIG`.

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "refuseless": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Refuseless",
      "options": { "baseURL": "https://api.refuseless.com/v1", "apiKey": "{env:REFUSELESS_API_KEY}" },
      "models": { "deepseek-v4.1-flash-abliterated": { "name": "DeepSeek V4.1 Flash Abliterated", "tool_call": true } }
    }
  }
}
```

`{env:...}` anahtarı ortam değişkeninden okur. Değişkeni sadece OpenCode açılırken ver:

```bash
opencode-sansursuz() {
  OPENCODE_CONFIG="$HOME/.config/sansursuz/opencode.json" \
  REFUSELESS_API_KEY="$(security find-generic-password -s sansursuz-refuseless -a "$USER" -w)" \
  command opencode "$@"
}
```

Venice OpenCode'un hazır kataloğunda zaten var; Refuseless yok, o yüzden elle tanımlanıyor.

## Takıldığın yerler

| Belirti | Sebep | Çözüm |
|---|---|---|
| omp: `No API key found` | İlk çağrılar paralel atıldı, Keychain okuması zaman aşımına düştü | İlk çağrıyı tek başına at |
| `omp -p` asılı kalıyor | Betikten çağırırken stdin açık | Sonuna `< /dev/null` ekle |
| Claude Code: `doesn't recognize the model` | Model adı Claude Code'un listesinde yok | `CLAUDE_CODE_AUTO_COMPACT_WINDOW` ver (uyarı zararsız) |
| Claude Code'da 404 | Sağlayıcı Anthropic formatını desteklemiyor (Venice) | Refuseless kullan ya da proxy kur |
| OpenCode: `Authentication required` | Anahtar ortam değişkeni boş | `opencode-sansursuz` ile aç |
| 503 ya da 429 | Sağlayıcı yoğun | Sıralı çalıştır, tekrar dene; model bozuk değil |
