"""DeepSeek Harness profiline (cordis.patch.yml) refuseless ve venice sağlayıcılarını ekler.

Kullanım: dsh_yaz.py <cordis.patch.yml> <refuseless 0/1> <venice 0/1> <tarih>
Anahtar değeri yazılmaz; yalnız referans adı (apiKeyEnv) yazılır. Değeri uygulamanın içinden girersin.
Dosyada zaten bir `llm-pi-ai` girdisi varsa dokunmaz, eklenecek bloğu basar.
"""
import os
import shutil
import sys

yol, has_r, has_v, tarih = sys.argv[1], sys.argv[2] == "1", sys.argv[3] == "1", sys.argv[4]
BAS, SON = "# >>> sansursuz >>>", "# <<< sansursuz <<<"


def saglayici(ad, gorunen, ref, url, modeller, baglam):
    satirlar = [
        f"      {ad}:",
        f"        displayName: {gorunen}",
        f"        apiKeyEnv: {ref}",
        "        api: openai-completions",
        f"        baseURL: {url}",
        "        models:",
    ]
    for m in modeller:
        satirlar += [f"          - id: {m}", f"            name: {m}", f"            contextWindow: {baglam}"]
    return satirlar


govde = []
if has_r:
    govde += saglayici("refuseless", "Refuseless", "REFUSELESS_API_KEY", "https://api.refuseless.com/v1",
                       ["deepseek-v4.1-flash-abliterated", "glm-5.3-flash-abliterated", "glm-5.3-abliterated"], 1048576)
if has_v:
    govde += saglayici("venice", "Venice", "VENICE_API_KEY", "https://api.venice.ai/api/v1",
                       ["deepseek-v4-1-flash-uncensored", "abliteration-abliterated-model-large-v2"], 1000000)

blok = "\n".join([BAS, "- id: llm-pi-ai", '  name: "@deepseek-ai/dsh-llm-pi-ai"', "  config:", "    providers:", *govde, SON]) + "\n"

metin = open(yol, encoding="utf-8").read() if os.path.exists(yol) else ""
if BAS in metin:
    bas, son = metin.index(BAS), metin.index(SON) + len(SON)
    shutil.copy2(yol, f"{yol}.sansursuz-yedek-{tarih}")
    metin = metin[:bas] + blok.rstrip("\n") + metin[son:]
    open(yol, "w", encoding="utf-8").write(metin)
    print("sağlayıcı bloğu güncellendi")
elif "id: llm-pi-ai" in metin:
    print("profilde zaten bir llm-pi-ai girdisi var, dokunmadım. Aynı sağlayıcıları uygulamanın Models sayfasından ekle (MANUEL.md).")
else:
    os.makedirs(os.path.dirname(yol), exist_ok=True)
    if os.path.exists(yol):
        shutil.copy2(yol, f"{yol}.sansursuz-yedek-{tarih}")
    open(yol, "w", encoding="utf-8").write(metin.rstrip("\n") + ("\n" if metin else "") + blok)
    print("sağlayıcılar profile eklendi")
