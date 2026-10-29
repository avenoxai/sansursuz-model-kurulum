# Agent talimatı: sansürsüz model kurulumu

Kullanıcı bu repoyu açıp "kur" dediğinde:

1. Kullanıcıdan API anahtarını sohbete yazmasını **isteme**. Anahtar sohbete, loga ya da dosyaya düz metin olarak girmemeli.
2. `.env` var mı bak (`test -f .env`), içeriğini **okuma**. Yoksa kullanıcıya şunu söyle: "`cp .env.example .env` ile oluştur, anahtarını kendin yapıştır" ya da "`./kur.sh`'i kendi terminalinde çalıştır, anahtarı gizli olarak soracak".
3. Kullanıcı `.env`'yi doldurduğunu söyleyince `./kur.sh` çalıştır. Betik anahtarları doğrular, güvenli depoya taşır, `.env`'deki değerleri siler ve her harness'ı dener.
4. Çıktıdaki ✓ ve ✗ satırlarını kullanıcıya özetle. ✗ varsa MANUEL.md'deki "Takıldığın yerler" tablosuna bak.
5. Yeni bir terminal açması gerektiğini hatırlat; komutlar README'deki tabloda.
6. DeepSeek Harness için anahtarın uygulamanın Models sayfasına bir kez girilmesi gerektiğini söyle.

Kurallar:

- `security find-generic-password ... -w`, `secret-tool lookup` ya da `~/.config/sansursuz/anahtar` çıktısını asla ekrana basma; bunlar anahtarın kendisi.
- Kullanıcının mevcut ayarlarını silme. Betik her değişiklikten önce yedek alır; elle düzeltme gerekirse önce yedeği göster.
- Araç onayını kapatan bayrak (`--approval-mode yolo`, `--dangerously-skip-permissions`) önerme.
- Kaldırma: `./kaldir.sh`.
