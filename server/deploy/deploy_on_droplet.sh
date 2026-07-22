#!/usr/bin/env bash
# DilDostu Live — DigitalOcean droplet-də deploy skripti.
# İşlətmə (droplet-də, root olaraq):
#   GROQ_API_KEY=gsk_... bash deploy_on_droplet.sh [subdomen]
# Nümunə:
#   GROQ_API_KEY=gsk_xxx ANTHROPIC_API_KEY=sk-ant-xxx bash deploy_on_droplet.sh dildostu.prdostu.com
set -euo pipefail

DOMAIN="${1:-dildostu.prdostu.com}"
REPO="https://github.com/Alihuseyn-ibrahimov/quantum-pr-monitor.git"
BASE=/opt/dildostu
SRV="$BASE/repo/dildostu/server"

if [ -z "${GROQ_API_KEY:-}" ]; then
  echo "XETA: GROQ_API_KEY environment deyiskeni verilmelidir." >&2
  exit 1
fi

echo "=== 1/6 Kod cekilir ($REPO) ==="
mkdir -p "$BASE"
if [ -d "$BASE/repo/.git" ]; then
  git -C "$BASE/repo" pull --ff-only
else
  git clone --depth 1 "$REPO" "$BASE/repo"
fi

echo "=== 2/6 venv + asililiqlar ==="
cd "$SRV"
python3 -m venv .venv
.venv/bin/pip install -q -U pip
.venv/bin/pip install -q -r requirements.txt

echo "=== 3/6 .env ==="
{
  echo "GROQ_API_KEY=$GROQ_API_KEY"
  [ -n "${ANTHROPIC_API_KEY:-}" ] && echo "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY"
} > "$SRV/.env"
chmod 600 "$SRV/.env"

echo "=== 4/6 systemd servis ==="
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

echo "=== 5/6 nginx reverse proxy ($DOMAIN) ==="
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

echo "=== 6/6 Bitdi ==="
cat <<DONE

Server localhost:8100-de isleyir, nginx $DOMAIN uzerinden port 80-e yonlendirir.

NOVBETI ADDIMLAR (sen edeceksen):
  1. Cloudflare-de DNS qeydi: $DOMAIN  A  68.183.210.59  (Proxy: OFF / boz bulud)
     — Let's Encrypt HTTP-01 challenge ucun boz bulud lazimdir.
  2. DNS yayildiqdan sonra HTTPS:
       apt-get install -y certbot python3-certbot-nginx
       certbot --nginx -d $DOMAIN --agree-tos -m sizin@email --redirect
  3. Yoxla:  curl https://$DOMAIN/health   ->  {"status":"ok"}

Yenilemek ucun sonra:  cd $BASE/repo && git pull && systemctl restart dildostu-live
DONE
