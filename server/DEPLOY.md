# DilDostu Live — VPS Deploy Təlimatı

Məqsəd: FastAPI backend-i VPS-də HTTPS ilə işə salmaq ki, telefon USB olmadan
internetlə qoşulsun. MasterNR1 ilə eyni VPS/pattern.

## 0. Səndən lazım olanlar
| Nə | Qeyd |
|----|------|
| VPS SSH girişi | Deploy ediləcək host (user@ip) |
| Subdomen | Məs. `dildostu.prdostu.com` — DNS (Cloudflare) VPS IP-yə A qeydi |
| `GROQ_API_KEY` | server/.env (MasterNR1-dan AYRI açar tövsiyə — limit paylaşılmasın) |
| `ANTHROPIC_API_KEY` (istəyə görə) | personal mode-lar (sadələşdir/çətinləşdir) canlı işləsin |
| `FOURSQUARE_API_KEY` | Məkan tanıma (pulsuz). foursquare.com/developers → yeni layihə → **Service Key** kopyala. Olmasa app OSM ehtiyatına düşür |
| `JWT_SECRET` | **MƏCBURİ** — istifadəçi giriş tokenləri bununla imzalanır (≥32 simvol). Yaratmaq: `python -c "import secrets; print(secrets.token_urlsafe(48))"`. Dəyişdikdə bütün istifadəçilər sistemdən çıxarılır |

## 1. Kod deploy (VPS-də)
```bash
cd /opt/quantum && git pull            # (repo artıq /opt/quantum-dadırsa)
cd dildostu/server
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
cp .env.example .env    # sonra doldur (aşağı)
```

## 2. `.env` (prod)
```
GROQ_API_KEY=...
ANTHROPIC_API_KEY=...        # istəyə görə
FOURSQUARE_API_KEY=...       # məkan tanıma (pulsuz service key)
JWT_SECRET=...               # MƏCBURİ — giriş tokenləri (≥32 simvol)
# llama-3.3-70b-versatile Groq-dan çıxarılıb (404) — köhnə .env-də bu sətri dəyiş
GROQ_MODEL=openai/gpt-oss-120b
CLAUDE_MODEL=claude-sonnet-5
```

## 3. systemd
```bash
sudo cp deploy/dildostu-live.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now dildostu-live
curl -s localhost:8100/health      # {"status":"ok"}
```

## 4. nginx + HTTPS
```bash
# nginx-dildostu.conf-da SEND_DOMAIN-i real domenlə əvəz et
sudo cp deploy/nginx-dildostu.conf /etc/nginx/sites-available/dildostu
sudo ln -sf /etc/nginx/sites-available/dildostu /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d dildostu.<domen>    # HTTPS sertifikatı
```

## 5. App-ı yeni URL ilə yenidən qur
`dildostu/app/lib/src/config.dart`-da `serverBaseUrl`-i
`https://dildostu.<domen>` et (və ya build zamanı --dart-define). Sonra
`build_apk.bat` ilə yenidən qur, telefona qur. `adb reverse` ARTIQ LAZIM DEYİL.

## Yeniləmə (növbəti dəfə)
```bash
cd /opt/quantum && git pull
cd dildostu/server && .venv/bin/pip install -r requirements.txt
sudo systemctl restart dildostu-live
```
