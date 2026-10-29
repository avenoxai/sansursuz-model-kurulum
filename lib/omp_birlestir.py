"""omp models.yml dosyasına refuseless ve venice sağlayıcılarını ekler.

Kullanım: omp_birlestir.py <models.yml> <anahtar-yardımcısı> <refuseless 0/1> <venice 0/1>
Dosya yoksa ya da JSON ise birleştirir. YAML ise dokunmaz, elle eklenecek bloğu basıp 1 ile çıkar.
"""
import json
import os
import sys

dosya, yardimci, has_r, has_v = sys.argv[1], sys.argv[2], sys.argv[3] == "1", sys.argv[4] == "1"


def anahtar(servis):
    return f"!'{yardimci}' {servis}"


saglayicilar = {}
if has_r:
    saglayicilar["refuseless"] = {
        "baseUrl": "https://api.refuseless.com/v1",
        "api": "openai-completions",
        "apiKey": anahtar("refuseless"),
        "models": [
            {"id": "deepseek-v4.1-flash-abliterated", "name": "DeepSeek V4.1 Flash Abliterated", "contextWindow": 1048576, "maxTokens": 131072},
            {"id": "glm-5.3-flash-abliterated", "name": "GLM 5.3 Flash Abliterated", "contextWindow": 1048576, "maxTokens": 131072},
            {"id": "glm-5.3-abliterated", "name": "GLM 5.3 Abliterated", "contextWindow": 1048576, "maxTokens": 131072},
        ],
    }
if has_v:
    saglayicilar["venice"] = {
        "baseUrl": "https://api.venice.ai/api/v1",
        "api": "openai-completions",
        "apiKey": anahtar("venice"),
        "models": [
            {"id": "deepseek-v4-1-flash-uncensored", "name": "DeepSeek V4.1 Flash Uncensored (Venice)", "contextWindow": 1000000, "maxTokens": 131072},
            {"id": "abliteration-abliterated-model-large-v2", "name": "Abliterated Large V2 (Venice)", "contextWindow": 1000000, "maxTokens": 131072},
        ],
    }

veri = {}
if os.path.exists(dosya) and os.path.getsize(dosya) > 0:
    metin = open(dosya, encoding="utf-8").read()
    try:
        veri = json.loads(metin)
    except json.JSONDecodeError:
        print(json.dumps({"providers": saglayicilar}, indent=2, ensure_ascii=False))
        print("\nmodels.yml YAML biçiminde; yukarıdaki sağlayıcıları 'providers:' altına elle ekle.")
        sys.exit(1)

veri.setdefault("providers", {})
var_olan = [ad for ad in saglayicilar if ad in veri["providers"]]
for ad, yeni in saglayicilar.items():
    eski = veri["providers"].get(ad)
    if not isinstance(eski, dict):
        veri["providers"][ad] = yeni
        continue
    # Var olan sağlayıcı: bağlantı alanlarını güncelle, kullanıcının eklediği başka modelleri koru
    bizim = {m["id"] for m in yeni["models"]}
    korunan = [m for m in eski.get("models", []) if m.get("id") not in bizim]
    eski.update({k: v for k, v in yeni.items() if k != "models"})
    eski["models"] = yeni["models"] + korunan
maske = os.umask(0o077)
with open(dosya, "w", encoding="utf-8") as f:
    json.dump(veri, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.umask(maske)
os.chmod(dosya, 0o600)
ekler = ", ".join(saglayicilar)
print(f"{ekler} eklendi" + (f" ({', '.join(var_olan)} güncellendi)" if var_olan else ""))
