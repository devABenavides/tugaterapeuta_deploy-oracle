#!/bin/sh
# Genera deploy/oracle/.env con secretos aleatorios. Correr UNA vez en la VM.
# No sobrescribe un .env existente: cambiar ENCRYPTION_KEY rompe las cuentas
# conectadas (hay que reconectarlas) y cambiar POSTGRES_PASSWORD deja la DB
# inaccesible.
set -eu
cd "$(dirname "$0")"

if [ -f .env ]; then
  echo ".env ya existe; no lo toco. Bórralo a mano si de verdad quieres regenerarlo." >&2
  exit 1
fi

hex() { openssl rand -hex "$1"; }

cat > .env <<EOF
# --- Completa estos ---
# Dominio público SIN https://. Sin dominio: <ip-con-guiones>.sslip.io
DOMAIN=dm.tugaterapeuta.com
# Resend (https://resend.com/api-keys). Con onboarding@resend.dev solo llega
# al correo con el que te registraste en Resend.
RESEND_API_KEY=re_xxx
EMAIL_FROM=OpenReply <onboarding@resend.dev>
# Solo estos correos pueden entrar al panel.
ALLOWED_EMAILS=alexandra.benavides@gmail.com

# --- Generados, no cambiar después del primer arranque ---
NEXTAUTH_SECRET=$(openssl rand -base64 32)
CRON_SECRET=$(hex 32)
ENCRYPTION_KEY=$(hex 32)
POSTGRES_PASSWORD=$(hex 24)
REDIS_PASSWORD=$(hex 24)

# Conexión vía Zernio: las credenciales de Zernio se ponen en Settings del
# panel, no aquí. Variables META_* / INSTAGRAM_* solo si algún día usas app
# propia de Meta.
EOF

chmod 600 .env
echo "Listo: deploy/oracle/.env creado. Edita DOMAIN, RESEND_API_KEY y ALLOWED_EMAILS."
