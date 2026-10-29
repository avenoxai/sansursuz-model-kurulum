#!/usr/bin/env bash
# kur.sh'in yaptığı her şeyi geri alır: kabuk bloğu, omp sağlayıcıları, OpenCode dosyası,
# DeepSeek Harness bloğu ve depodaki anahtarlar. Yedek dosyalara dokunmaz.
set -euo pipefail

DIZIN="$HOME/.config/sansursuz"
ONEK="${SANSURSUZ_ONEK:-}"
KULLANICI="${USER:-$(id -un)}"
tamam() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
bilgi() { printf '    %s\n' "$*"; }

# Kabuk bloğu
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [[ -f "$rc" ]] || continue
  if grep -q '# >>> sansursuz >>>' "$rc"; then
    python3 -I - "$rc" <<'PY'
import sys, re
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
t = re.sub(r"\n*# >>> sansursuz >>>.*?# <<< sansursuz <<<\n?", "\n", t, flags=re.S)
open(p, "w", encoding="utf-8").write(t)
PY
    tamam "$rc: sansursuz bloğu silindi"
  fi
done

# omp: yalnız bizim yardımcıyı kullanan sağlayıcıları sil
OMP="$HOME/.omp/agent/models.yml"
if [[ -f "$OMP" ]]; then
  python3 -I - "$OMP" "$DIZIN/anahtar" <<'PY' || true
import json, sys
p, yardimci = sys.argv[1], sys.argv[2]
try:
    d = json.load(open(p, encoding="utf-8"))
except Exception:
    print("    omp: models.yml JSON değil, elle kontrol et"); sys.exit(0)
silinen = [ad for ad, s in list(d.get("providers", {}).items()) if yardimci in str(s.get("apiKey", ""))]
for ad in silinen:
    del d["providers"][ad]
json.dump(d, open(p, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
print("  \033[32m✓\033[0m omp: " + (", ".join(silinen) + " silindi" if silinen else "silinecek sağlayıcı yok"))
PY
fi

# DeepSeek Harness bloğu
DSH="$HOME/.dsh/profiles/desktop/cordis.patch.yml"
if [[ -f "$DSH" ]] && grep -q '# >>> sansursuz >>>' "$DSH"; then
  python3 -I - "$DSH" <<'PY'
import sys, re
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
t = re.sub(r"# >>> sansursuz >>>.*?# <<< sansursuz <<<\n?", "", t, flags=re.S)
open(p, "w", encoding="utf-8").write(t)
PY
  tamam "DeepSeek Harness: sağlayıcı bloğu silindi (uygulamaya girdiğin anahtarı Models sayfasından sil)"
fi

# Anahtarlar
for s in refuseless venice; do
  if [[ "$(uname)" == "Darwin" ]] && /usr/bin/security delete-generic-password -s "${ONEK}sansursuz-$s" -a "$KULLANICI" >/dev/null 2>&1; then
    tamam "Keychain: $s anahtarı silindi"
  elif command -v secret-tool >/dev/null && secret-tool clear uygulama "${ONEK}sansursuz" servis "$s" 2>/dev/null; then
    tamam "secret-tool: $s anahtarı silindi"
  fi
done

rm -rf "$DIZIN" && tamam "$DIZIN silindi"
bilgi "Claude Code'un ayrı dizini (~/.claude-sansursuz) oturum geçmişini tutuyor; istersen elle sil."
bilgi "Yeni bir terminal aç."
