"""OpenCode için ayrı bir config dosyası yazar (OPENCODE_CONFIG ile yüklenir, kendi ayarına dokunmaz).

Kullanım: opencode_yaz.py <hedef.json> <refuseless 0/1> <venice 0/1>
"""
import json
import os
import sys

hedef, has_r, has_v = sys.argv[1], sys.argv[2] == "1", sys.argv[3] == "1"


def model(ad, baglam, akil=False):
    m = {"name": ad, "tool_call": True, "limit": {"context": baglam, "output": 131072}}
    if akil:
        m["reasoning"] = True
    return m


saglayicilar = {}
if has_r:
    saglayicilar["refuseless"] = {
        "npm": "@ai-sdk/openai-compatible",
        "name": "Refuseless",
        "options": {"baseURL": "https://api.refuseless.com/v1", "apiKey": "{env:REFUSELESS_API_KEY}"},
        "models": {
            "deepseek-v4.1-flash-abliterated": model("DeepSeek V4.1 Flash Abliterated", 1048576),
            "glm-5.3-flash-abliterated": model("GLM 5.3 Flash Abliterated", 1048576),
            "glm-5.3-abliterated": model("GLM 5.3 Abliterated", 1048576),
        },
    }
if has_v:
    saglayicilar["venice"] = {
        "npm": "@ai-sdk/openai-compatible",
        "name": "Venice",
        "options": {"baseURL": "https://api.venice.ai/api/v1", "apiKey": "{env:VENICE_API_KEY}"},
        "models": {
            "deepseek-v4-1-flash-uncensored": model("DeepSeek V4.1 Flash Uncensored", 1000000),
            "abliteration-abliterated-model-large-v2": model("Abliterated Large V2", 1000000, akil=True),
        },
    }

eski = os.umask(0o077)
with open(hedef, "w", encoding="utf-8") as f:
    json.dump({"$schema": "https://opencode.ai/config.json", "provider": saglayicilar}, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.umask(eski)
