---
name: sansursuz-kurulum
description: Sansürsüz (abliterated) modelleri (Refuseless, Venice) Claude Code, omp, DeepSeek Harness ve OpenCode'a tek komutla bağlar. Kullanıcı "sansürsüz modeli kur", "abliterated kur", "refuseless/venice bağla", "kur.sh çalıştır" ya da "bu repoyu kur" dediğinde kullan.
---

# Sansürsüz model kurulumu

Repo kökündeki [AGENTS.md](../../../AGENTS.md) talimatını izle. Özet:

1. Anahtarı sohbete yazdırma, `.env` içeriğini okuma.
2. `.env` yoksa: kullanıcı `cp .env.example .env` yapıp anahtarını kendisi yapıştırsın, ya da `./kur.sh`'i kendi terminalinde çalıştırsın.
3. `.env` hazırsa `./kur.sh` çalıştır, çıktıdaki ✓ / ✗ satırlarını özetle.
4. Sorun varsa [MANUEL.md](../../../MANUEL.md) > "Takıldığın yerler".
5. Yeni terminal açmasını, DeepSeek Harness için anahtarı uygulamanın Models sayfasına girmesini hatırlat.

Anahtar okuyan komutların çıktısını (`security ... -w`, `secret-tool lookup`, `~/.config/sansursuz/anahtar`) asla ekrana basma.
