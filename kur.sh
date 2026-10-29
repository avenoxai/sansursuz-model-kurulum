#!/usr/bin/env bash
# Sansürsüz (abliterated) modelleri Claude Code, omp, OpenCode ve DeepSeek Harness'a bağlar.
# Kullanım: ./kur.sh            (anahtarları .env'den okur, yoksa sorar)
#           ./kur.sh --test-yok (sondaki deneme çağrılarını atlar)
# Anahtarlar hiçbir ayar dosyasına yazılmaz: macOS'ta Keychain, Linux'ta secret-tool
# (yoksa yalnız senin okuyabildiğin bir dosya) kullanılır.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIZIN="$HOME/.config/sansursuz"
ONEK="${SANSURSUZ_ONEK:-}"
KC="${SANSURSUZ_KEYCHAIN:-}"   # yalnız geliştirme/test: Keychain dosyasını açıkça ver
TARIH="$(date +%Y%m%d-%H%M%S)"
KULLANICI="${USER:-$(id -un)}"
TEST=1
[[ "${1:-}" == "--test-yok" ]] && TEST=0

baslik() { printf '\n\033[1m%s\033[0m\n' "$*"; }
tamam()  { printf '  \033[32m✓\033[0m %s\n' "$*"; }
uyari()  { printf '  \033[33m!\033[0m %s\n' "$*"; }
hata()   { printf '  \033[31m✗\033[0m %s\n' "$*"; }
bilgi()  { printf '    %s\n' "$*"; }

# ---------- 1. Anahtarlar ----------
baslik "1. Anahtarlar"

env_oku() { # .env'den tek bir değeri okur, kaynak olarak çalıştırmaz
  local ad="$1" dosya="$REPO/.env"
  [[ -f "$dosya" ]] || return 0
  sed -n "s/^[[:space:]]*$ad[[:space:]]*=[[:space:]]*//p" "$dosya" | tail -1 | sed -e 's/^["'\'']//' -e 's/["'\'']$//' -e 's/[[:space:]]*$//'
}

REFUSELESS="$(env_oku REFUSELESS_API_KEY)"
VENICE="$(env_oku VENICE_API_KEY)"

sor() { # gizli giriş; boş bırakılırsa atlanır
  local etiket="$1" deger=""
  if [[ -t 0 ]]; then
    read -rsp "  $etiket API anahtarı (atlamak için Enter): " deger; echo >&2
  fi
  printf '%s' "$deger"
}
[[ -z "$REFUSELESS" ]] && REFUSELESS="$(sor Refuseless)"
[[ -z "$VENICE" ]] && VENICE="$(sor Venice)"

if [[ -z "$REFUSELESS" && -z "$VENICE" && -x "$DIZIN/anahtar" ]]; then # yeniden kurulum: depodakini kullan
  REFUSELESS="$("$DIZIN/anahtar" refuseless 2>/dev/null || true)"
  VENICE="$("$DIZIN/anahtar" venice 2>/dev/null || true)"
  [[ -n "$REFUSELESS$VENICE" ]] && tamam "Önceki kurulumdaki anahtarlar kullanılıyor"
fi
if [[ -z "$REFUSELESS" && -z "$VENICE" ]]; then
  hata "Hiç anahtar yok. .env.example'ı .env olarak kopyala ve doldur, ya da betik sorduğunda yapıştır."
  exit 1
fi

dogrula() { # yanlış anahtarı kaydetmeden yakala; anahtar komut satırına değil stdin'e gider
  local url="$1" deger="$2" kod
  kod="$(curl -s -m 20 -o /dev/null -w '%{http_code}' -H @- "$url" <<< "Authorization: Bearer $deger" || true)"
  [[ "$kod" == "200" ]]
}

if [[ -n "$REFUSELESS" ]]; then
  if dogrula https://api.refuseless.com/v1/models "$REFUSELESS"; then tamam "Refuseless anahtarı geçerli"
  else hata "Refuseless anahtarı reddedildi (ya da bağlantı yok). Atlıyorum."; REFUSELESS=""; fi
fi
if [[ -n "$VENICE" ]]; then
  if dogrula https://api.venice.ai/api/v1/api_keys/rate_limits "$VENICE"; then tamam "Venice anahtarı geçerli"
  else hata "Venice anahtarı reddedildi (ya da bağlantı yok). Atlıyorum."; VENICE=""; fi
fi
[[ -z "$REFUSELESS" && -z "$VENICE" ]] && { hata "Geçerli anahtar kalmadı."; exit 1; }

# ---------- 2. Güvenli depo ----------
baslik "2. Anahtarları güvenli depoya koyma"

DEPO="${SANSURSUZ_DEPO:-}"
if [[ -z "$DEPO" ]]; then
  if [[ "$(uname)" == "Darwin" ]] && command -v security >/dev/null; then DEPO=keychain
  elif command -v secret-tool >/dev/null && [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then DEPO=secret-tool
  else DEPO=dosya; fi
fi
mkdir -p "$DIZIN"; chmod 700 "$DIZIN"

sakla() {
  local servis="$1" deger="$2"
  case "$DEPO" in
    keychain) /usr/bin/security add-generic-password -U -s "${ONEK}sansursuz-$servis" -a "$KULLANICI" -l "sansursuz $servis" -w "$deger" ${KC:+"$KC"} >/dev/null ;;
    secret-tool) printf '%s' "$deger" | secret-tool store --label="sansursuz $servis" uygulama "${ONEK}sansursuz" servis "$servis" ;;
    dosya)
      local f="$DIZIN/anahtarlar"; ( umask 077; touch "$f" )
      grep -v "^$servis=" "$f" > "$f.yeni" || true
      printf '%s=%s\n' "$servis" "$deger" >> "$f.yeni"; mv "$f.yeni" "$f"; chmod 600 "$f" ;;
  esac
}

# Tüm harness'ların anahtarı okuduğu tek yardımcı
cat > "$DIZIN/anahtar" <<EOF
#!/usr/bin/env bash
# Kullanım: anahtar refuseless | anahtar venice  -> anahtarı ekrana değil, çağıran programa verir
s="\${1:?servis adı ver: refuseless ya da venice}"
case "$DEPO" in
  keychain) exec /usr/bin/security find-generic-password -s "${ONEK}sansursuz-\$s" -a "\${USER:-\$(id -un)}" -w ${KC:+"$KC"} ;;
  secret-tool) exec secret-tool lookup uygulama "${ONEK}sansursuz" servis "\$s" ;;
  dosya) sed -n "s/^\$s=//p" "\$HOME/.config/sansursuz/anahtarlar" ;;
esac
EOF
chmod 700 "$DIZIN/anahtar"

sakla_dogrula() { # yaz, geri oku; tutmazsa .env'ye dokunmadan dur
  local servis="$1" deger="$2" etiket="$3"
  if sakla "$servis" "$deger" && [[ "$("$DIZIN/anahtar" "$servis" 2>/dev/null)" == "$deger" ]]; then
    tamam "$etiket anahtarı depoda ($DEPO)"
  else
    hata "$etiket anahtarı depoya yazılamadı ($DEPO). .env'ye dokunmadım."
    [[ "$DEPO" == "keychain" ]] && bilgi "Keychain izin penceresi çıktıysa 'İzin ver' de ve betiği yeniden çalıştır."
    exit 1
  fi
}
if [[ -n "$REFUSELESS" ]]; then sakla_dogrula refuseless "$REFUSELESS" Refuseless; fi
if [[ -n "$VENICE" ]]; then sakla_dogrula venice "$VENICE" Venice; fi
[[ "$DEPO" == "dosya" ]] && uyari "Keychain/secret-tool bulunamadı: anahtar $DIZIN/anahtarlar dosyasında (izin 600)."
HAS_R=0; HAS_V=0; [[ -n "$REFUSELESS" ]] && HAS_R=1; [[ -n "$VENICE" ]] && HAS_V=1
REFUSELESS=""; VENICE=""

if [[ -f "$REPO/.env" ]] && grep -qE '^(REFUSELESS|VENICE)_API_KEY=.+' "$REPO/.env"; then
  sed -i.bak -E 's/^((REFUSELESS|VENICE)_API_KEY=).*/\1/' "$REPO/.env" && rm -f "$REPO/.env.bak"
  tamam ".env içindeki anahtar değerleri silindi (artık depoda)"
fi

# ---------- 3. Harness'lar ----------
baslik "3. Harness'lar"
KABUK="$DIZIN/kabuk.sh"
YARDIMCI="$DIZIN/anahtar"
{
  echo "# sansursuz-model-kurulum tarafından üretildi ($TARIH). Elle düzenleme; ./kur.sh yeniden üretir."
} > "$KABUK"
SONUC=()

# 3a. Claude Code (yalnız Refuseless: Claude Code Anthropic formatı konuşur, Venice bu formatı desteklemiyor)
if command -v claude >/dev/null; then
  if [[ $HAS_R == 1 ]]; then
    cat >> "$KABUK" <<EOF

# Claude Code + Refuseless. Ayrı config dizini: asıl Claude girişin, ayarların ve hafızan bu sağlayıcıya gitmez.
claude-sansursuz() {
  ANTHROPIC_BASE_URL="https://api.refuseless.com" \\
  ANTHROPIC_AUTH_TOKEN="\$("$YARDIMCI" refuseless)" \\
  ANTHROPIC_MODEL="deepseek-v4.1-flash-abliterated" \\
  ANTHROPIC_DEFAULT_OPUS_MODEL="glm-5.3-abliterated" \\
  ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-v4.1-flash-abliterated" \\
  ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-5.3-flash-abliterated" \\
  CLAUDE_CODE_SUBAGENT_MODEL="deepseek-v4.1-flash-abliterated" \\
  CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000 \\
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \\
  CLAUDE_CONFIG_DIR="\$HOME/.claude-sansursuz" \\
  command claude "\$@"
}
EOF
    tamam "Claude Code: claude-sansursuz komutu hazır"; SONUC+=("claude")
  else
    uyari "Claude Code: Venice Claude Code'un formatını konuşmuyor, Refuseless anahtarı gerekli. Atlandı."
  fi
else
  bilgi "Claude Code kurulu değil, atlandı."
fi

# 3b. omp (Oh My Pi): ~/.omp/agent/models.yml içine sağlayıcı ekler
if command -v omp >/dev/null; then
  OMP_DOSYA="$HOME/.omp/agent/models.yml"
  mkdir -p "$(dirname "$OMP_DOSYA")"
  [[ -f "$OMP_DOSYA" ]] && cp -p "$OMP_DOSYA" "$OMP_DOSYA.sansursuz-yedek-$TARIH"
  if OMP_SONUC="$(python3 -I "$REPO/lib/omp_birlestir.py" "$OMP_DOSYA" "$YARDIMCI" "$HAS_R" "$HAS_V" 2>&1)"; then
    tamam "omp: $OMP_SONUC"
    {
      echo; echo "# omp kısayolları: her araç çağrısında onay sorar"
      if [[ $HAS_R == 1 ]]; then
        echo 'omp-sansursuz()     { command omp --model refuseless/deepseek-v4.1-flash-abliterated --approval-mode always-ask "$@"; }'
        echo 'omp-sansursuz-glm() { command omp --model refuseless/glm-5.3-abliterated --approval-mode always-ask "$@"; }'
      fi
      if [[ $HAS_V == 1 ]]; then
        echo 'omp-venice()        { command omp --model venice/deepseek-v4-1-flash-uncensored --approval-mode always-ask "$@"; }'
        echo 'omp-venice-glm()    { command omp --model venice/abliteration-abliterated-model-large-v2 --approval-mode always-ask "$@"; }'
      fi
    } >> "$KABUK"
    SONUC+=("omp")
  else
    uyari "omp: models.yml otomatik birleştirilemedi. Elle eklenecek blok:"
    printf '%s\n' "$OMP_SONUC" | sed 's/^/      /'
  fi
else
  bilgi "omp kurulu değil, atlandı."
fi

# 3c. OpenCode: kendi ayarına dokunmaz; ayrı dosyayı OPENCODE_CONFIG ile ekler
if command -v opencode >/dev/null; then
  python3 -I "$REPO/lib/opencode_yaz.py" "$DIZIN/opencode.json" "$HAS_R" "$HAS_V"
  cat >> "$KABUK" <<EOF

# OpenCode: sansürsüz sağlayıcılar yalnız bu komutla gelir
opencode-sansursuz() {
  OPENCODE_CONFIG="$DIZIN/opencode.json" \\
  REFUSELESS_API_KEY="\$("$YARDIMCI" refuseless 2>/dev/null)" \\
  VENICE_API_KEY="\$("$YARDIMCI" venice 2>/dev/null)" \\
  command opencode "\$@"
}
EOF
  tamam "OpenCode: opencode-sansursuz komutu hazır"; SONUC+=("opencode")
else
  bilgi "OpenCode kurulu değil, atlandı."
fi

# 3d. DeepSeek Harness: sağlayıcıyı profile ekler, anahtarı uygulamanın kendi deposuna sen yapıştırırsın
DSH_PATCH="$HOME/.dsh/profiles/desktop/cordis.patch.yml"
if [[ -d "/Applications/DeepSeek Harness.app" || -d "$HOME/.dsh" ]]; then
  DSH_SONUC="$(python3 -I "$REPO/lib/dsh_yaz.py" "$DSH_PATCH" "$HAS_R" "$HAS_V" "$TARIH" 2>&1)" || true
  tamam "DeepSeek Harness: $DSH_SONUC"
  bilgi "Anahtarı uygulamanın içinden gir: Ayarlar > Models > sağlayıcıyı seç > API key."
  bilgi "Ayrıntı: MANUEL.md > DeepSeek Harness. Uygulamayı yeniden başlatmayı unutma."
  SONUC+=("dsh")
else
  bilgi "DeepSeek Harness bulunamadı, atlandı."
fi

# ---------- 4. Kabuk ----------
baslik "4. Kabuk ayarı"
BLOK_BAS="# >>> sansursuz >>>"; BLOK_SON="# <<< sansursuz <<<"
rc_yaz() {
  local rc="$1"
  [[ -f "$rc" ]] || touch "$rc"
  cp -p "$rc" "$rc.sansursuz-yedek-$TARIH"
  python3 -I - "$rc" "$BLOK_BAS" "$BLOK_SON" "$KABUK" <<'PY'
import sys, re
rc, bas, son, kabuk = sys.argv[1:]
t = open(rc, encoding="utf-8").read()
t = re.sub(re.escape(bas) + r".*?" + re.escape(son) + r"\n?", "", t, flags=re.S)
blok = f'{bas}\n[ -f "{kabuk}" ] && . "{kabuk}"\n{son}\n'
open(rc, "w", encoding="utf-8").write(t.rstrip("\n") + "\n\n" + blok)
PY
  tamam "$rc güncellendi (yedek: $(basename "$rc").sansursuz-yedek-$TARIH)"
}
RC_LER=()
[[ -f "$HOME/.zshrc" || "${SHELL:-}" == */zsh ]] && RC_LER+=("$HOME/.zshrc")
[[ -f "$HOME/.bashrc" || "${SHELL:-}" == */bash ]] && RC_LER+=("$HOME/.bashrc")
for rc in ${RC_LER[@]+"${RC_LER[@]}"}; do rc_yaz "$rc"; done

# ---------- 5. Deneme ----------
if [[ $TEST == 1 ]]; then
  baslik "5. Deneme (tek kelimelik çağrı)"
  sure() { perl -e 'alarm shift; exec @ARGV' "$@"; }
  dene() { # ad, komut
    local ad="$1"; shift
    local cikti
    cikti="$(cd /tmp && sure 120 bash -c ". '$KABUK'; $*" < /dev/null 2>/dev/null | tr -d '\r' | grep -v '^\s*$' | tail -1 || true)"
    if printf '%s' "$cikti" | grep -qi merhaba; then tamam "$ad: $cikti"; else hata "$ad: cevap alınamadı (${cikti:-boş})"; fi
  }
  P='"Reply with exactly one word: merhaba"'
  for h in ${SONUC[@]+"${SONUC[@]}"}; do
    case "$h" in
      claude) dene "Claude Code (Refuseless)" "claude-sansursuz -p $P" ;;
      omp)
        if [[ $HAS_R == 1 ]]; then dene "omp (Refuseless)" "command omp -p --no-session --no-tools --model refuseless/deepseek-v4.1-flash-abliterated $P"; fi
        if [[ $HAS_V == 1 ]]; then dene "omp (Venice)" "command omp -p --no-session --no-tools --model venice/deepseek-v4-1-flash-uncensored $P"; fi ;;
      opencode)
        if [[ $HAS_R == 1 ]]; then dene "OpenCode (Refuseless)" "opencode-sansursuz run -m refuseless/deepseek-v4.1-flash-abliterated $P"; fi
        if [[ $HAS_V == 1 ]]; then dene "OpenCode (Venice)" "opencode-sansursuz run -m venice/deepseek-v4-1-flash-uncensored $P"; fi ;;
      dsh) bilgi "DeepSeek Harness masaüstü uygulaması, denemesini uygulamada yap." ;;
    esac
  done
fi

baslik "Bitti"
bilgi "Yeni bir terminal aç (ya da: source ~/.zshrc / source ~/.bashrc). Komutlar:"
for h in ${SONUC[@]+"${SONUC[@]}"}; do
  case "$h" in
    claude) bilgi "  claude-sansursuz" ;;
    omp) bilgi "  omp-sansursuz, omp-sansursuz-glm, omp-venice, omp-venice-glm (anahtarın olanlar)" ;;
    opencode) bilgi "  opencode-sansursuz" ;;
    dsh) bilgi "  DeepSeek Harness: uygulamada model seçiciden" ;;
  esac
done
bilgi "Kaldırmak için: ./kaldir.sh"
