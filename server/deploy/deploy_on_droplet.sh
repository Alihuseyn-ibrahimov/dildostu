#!/usr/bin/env bash
# DilDostu Live — DigitalOcean droplet-də deploy skripti.
# Bu skript YERLƏŞDİYİ repo checkout-unu işlədir (klon etmir) — private repo üçün.
#
# İşlətmə (droplet-də, root):
#   1) Mövcud checkout-u yenilə:   git -C /opt/pr-agent/repo pull
#   2) Skripti işə sal:
#      GROQ_API_KEY=gsk_... bash /opt/pr-agent/repo/dildostu/server/deploy/deploy_on_droplet.sh dildostu.prdostu.com
set -euo pipefail

DOMAIN="${1:-dildostu.prdostu.com}"

# Skriptin yerləşdiyi server qovluğu (deploy/-in bir yuxarısı).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRV="$(dirname "$SCRIPT_DIR")"

if [ -z "${GROQ_API_KEY:-}" ]; then
  echo "XETA: GROQ_API_KEY environment deyiskeni verilmelidir." >&2
  exit 1
fi
echo "Server qovlugu: $SRV"

echo "=== 1/5 venv + asililiqlar ==="
cd "$SRV"
python3 -m venv .venv
.venv/bin/pip install -q -U pip
.venv/bin/pip install -q -r requirements.txt

echo "=== 2/5 .env ==="
{
  echo "GROQ_API_KEY=$GROQ_API_KEY"
  [ -n "${ANTHROPIC_API_KEY:-}" ] && echo "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY"
} > "$SRV/.env"
chmod 600 "$SRV/.env"

echo "=== 3/5 systemd servis ==="
cat > /etc/systemd/system/dildostu-live.service <<UNIT
[Unit]
Description=DilDostu Live FastAPI backend
After=network.target

[Service]
Type=simple
WorkingDirectory=$SRV
EnvironmentFile=$SRV/.env
ExecStart=$SRV/.venv/bin/gunicorn dildostu_server.app:app -k uvicorn.workers.UvicornWorker -w 1 -b 127.0.0.1:8100
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now dildostu-live
sleep 2
echo "--- health (localhost) ---"
curl -s http://127.0.0.1:8100/health || echo "(health cavab vermedi — jurnal: journalctl -u dildostu-live -n 30)"
echo

echo "=== 4/5 nginx reverse proxy ($DOMAIN) ==="
cat > /etc/nginx/sites-available/dildostu <<NGINX
server {
    server_name $DOMAIN;
    location / {
        proxy_pass http://127.0.0.1:8100;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 30s;
    }
    listen 80;
}
NGINX
ln -sf /etc/nginx/sites-available/dildostu /etc/nginx/sites-enabled/dildostu
nginx -t && systemctl reload nginx

echo "=== 5/5 HTTPS (certbot) ==="
if ! command -v certbot >/dev/null 2>&1; then
  apt-get update -qq && apt-get install -y -qq certbot python3-certbot-nginx
fi
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email --redirect || \
  echo "(certbot ugursuz — DNS yayilmayibsa sonra: certbot --nginx -d $DOMAIN)"

echo
echo "=== BITDI ==="
echo "Yoxla:  curl https://$DOMAIN/health"
echo "Yenilemek:  git -C /opt/pr-agent/repo pull && systemctl restart dildostu-live"
