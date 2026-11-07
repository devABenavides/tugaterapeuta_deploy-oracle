# OpenReply para TuGaterapeuta — guía de despliegue (stack gratis)

Objetivo: alguien comenta una palabra clave (ej. `GUIA`) en un post o reel de
Instagram de TuGaterapeuta → le llega un DM automático con el link.

## Arquitectura elegida

| Pieza | Dónde | Costo |
| --- | --- | --- |
| Web (panel + webhook), worker, cron | VM Oracle Cloud Always Free, Docker | 0 € |
| PostgreSQL + Redis | Misma VM, red interna Docker (no expuestos) | 0 € |
| HTTPS | Caddy + Let's Encrypt | 0 € |
| Backups | `pg_dump` diario en `deploy/oracle/backups/`, 7 días | 0 € |
| Correo de login | Resend free (3k/mes) | 0 € |
| Conexión Instagram | Zernio (sin app propia de Meta) | 0 € hasta 2 cuentas / 10k mensajes al mes (según la guía de marbuilds, verificar en zernio.com/pricing) |

Cambios frente a la guía original y por qué:

- **Sin Vercel**: Vercel Hobby prohíbe uso comercial; TuGaterapeuta es negocio.
  Todo corre en la VM.
- **Postgres en la VM, no Neon**: el worker consulta la DB cada 5 min, Neon
  nunca se dormiría y agotaría sus horas de cómputo gratis.
- **Redis en la VM, no Redis Cloud**: Redis Cloud free no tiene TLS. Local en la
  red de Docker no sale a internet.
- **Cron incluido**: fuera de Vercel nadie corre `/api/cron/*`. Sin
  `refresh-tokens` las automatizaciones se apagan en silencio.

Archivos: [deploy/oracle/](../deploy/oracle/) — `docker-compose.yml`,
`Caddyfile`, `setup-vm.sh`, `gen-env.sh`.

---

## 0. Cuentas que necesitas

1. **GitHub** — haz fork de https://github.com/diwenne/openreply y sube la rama
   `tugaterapeuta/deploy-oracle` a tu fork (ver paso 3).
2. **Oracle Cloud** — https://signup.cloud.oracle.com (pide tarjeta para
   verificar, no cobra en Always Free).
3. **Resend** — https://resend.com. Crea API key. Si no verificas dominio, usa
   `EMAIL_FROM=OpenReply <onboarding@resend.dev>`: solo entrega al correo con
   que te registraste en Resend (sirve, porque solo tú entras al panel).
4. **Zernio** — https://zernio.com. Crea un perfil y conecta ahí el Instagram de
   TuGaterapeuta (cuenta Business o Creator).
5. **Dominio (opcional)** — subdominio tipo `dm.tugaterapeuta.com` con registro
   DNS **A** apuntando a la IP pública de la VM. Sin dominio:
   `<ip-con-guiones>.sslip.io` (ej. IP `129.146.10.20` → `129-146-10-20.sslip.io`).
6. **Segunda cuenta de Instagram** para probar (no puedes comentarte a ti misma).

## 1. Crear la VM en Oracle

Consola Oracle → Compute → Instances → Create instance:

- Imagen: **Ubuntu 22.04** (o 24.04).
- Shape: **VM.Standard.A1.Flex** (Ampere ARM) con 2 OCPU y 12 GB si hay
  capacidad en tu región. Si no, **VM.Standard.E2.1.Micro** (1 GB; funciona
  gracias a la swap, el primer build tarda ~15–20 min).
- Descarga la llave SSH.
- Tras crearla: Networking → la VCN → Security List → **Add Ingress Rules**:
  TCP 80 y TCP 443 desde `0.0.0.0/0`.

> Oracle puede reclamar instancias Always Free inactivas (CPU baja 7 días).
> Pasar la cuenta a **Pay As You Go** evita eso y sigue en 0 € si no sales de
> los límites Always Free. Pon una alerta de presupuesto en 1 €.

## 2. Subir la rama a tu fork (desde tu PC)

En la carpeta `AgenteMK/openreply`:

```bash
git remote rename origin upstream
git remote add origin https://github.com/TU_USUARIO/openreply.git
git push -u origin tugaterapeuta/deploy-oracle
```

## 3. Preparar la VM

```bash
ssh -i tu-llave.key ubuntu@IP_DE_LA_VM
git clone https://github.com/TU_USUARIO/openreply.git
cd openreply
git checkout tugaterapeuta/deploy-oracle
sudo sh deploy/oracle/setup-vm.sh
exit   # vuelve a entrar por SSH para que docker funcione sin sudo
```

## 4. Configurar y arrancar

```bash
cd ~/openreply/deploy/oracle
sh gen-env.sh        # genera secretos aleatorios en .env (chmod 600)
nano .env            # DOMAIN, RESEND_API_KEY, EMAIL_FROM, ALLOWED_EMAILS
docker compose up -d --build
docker compose logs -f web worker
```

Comprueba `https://TU_DOMINIO/api/health`: database, redis, queue y worker
deben salir OK.

**Nunca cambies** `ENCRYPTION_KEY` ni `POSTGRES_PASSWORD` después del primer
arranque. Guarda una copia del `.env` en tu gestor de contraseñas.

## 5. Entrar y conectar Instagram vía Zernio

1. Abre `https://TU_DOMINIO/login`, pon tu correo, abre el magic link.
2. **Settings** → sección Zernio:
   - En Zernio crea una API key **sin restricción de perfil, lectura/escritura,
     con acceso a Inbox** (una key restringida o read-only no funciona).
   - Pégala en OpenReply, elige el perfil, importa la cuenta de Instagram.
3. **No** crees automatizaciones en Zernio: se duplicarían los DMs.

## 6. ¿Instagram usó ManyChat? (respondiste "no sé")

Revisa en dos sitios:

- App de Instagram → Configuración → **Apps y sitios web** → Activas / Caducadas.
- Meta Business Suite → Configuración → **Integraciones → Enrutamiento de
  conversaciones** (Conversation routing).

Si aparece ManyChat (u otra app de mensajes):

1. Apaga sus automatizaciones de comentarios (o elimina la app) para evitar
   DMs dobles.
2. En Enrutamiento de conversaciones → Apps asociadas → la app de Zernio /
   OpenReply → activa **Acceder a todas las conversaciones** y **Tomar el
   control de las conversaciones**. Sin esto los botones del DM fallan con
   "not the thread owner".

Si no aparece nada, no hay que hacer nada.

## 7. Primera prueba

1. Campaigns → nueva campaña en un post, palabra clave `TEST`, DM con un link → Go Live.
2. Desde la **otra** cuenta comenta `TEST` en ese post.
3. DM Logs debe mostrar **Sent** y el DM llega a la otra cuenta.

## 8. Ideas de campañas para TuGaterapeuta

Completa los links reales. Instagram solo permite 1 respuesta privada por
comentario y ~750 por hora.

| Palabra clave | DM | Link |
| --- | --- | --- |
| `GUIA` | "¡Hola {username}! 🐾 Aquí tienes la guía gratis para entender por qué tu gato hace lo que hace:" | `[link guía]` |
| `ASESORIA` | "Gracias por escribir, {username}. Si quieres trabajar el caso de tu michi conmigo, aquí puedes agendar tu sesión de diagnóstico:" | `[link agenda]` |
| `FLORES` | "Aquí tienes la info sobre esencias florales para gatos que mencioné en el video 🌼" | `[link]` |

Usa la opción "next reel" para dejar la campaña lista antes de publicar: el cron
la engancha al siguiente reel en ≤5 min.

## Mantenimiento

```bash
cd ~/openreply/deploy/oracle
docker compose ps                       # estado
docker compose logs --tail 100 worker   # errores de envío
docker compose logs cron                # refresh-tokens debe decir "ok" a diario
ls backups/                             # backups diarios
```

Actualizar a la última versión de OpenReply:

```bash
cd ~/openreply
git fetch upstream && git merge upstream/main
docker compose -f deploy/oracle/docker-compose.yml up -d --build
```

(En la VM, `upstream` no existe hasta que lo agregues:
`git remote add upstream https://github.com/diwenne/openreply.git`.)

Restaurar un backup:

```bash
gunzip -c backups/openreply-AAAAMMDD-HHMM.sql.gz | \
  docker compose exec -T postgres psql -U openreply openreply
```

Si cambias de dominio: actualiza `DOMAIN` en `.env`, `docker compose up -d`, y
reconfigura la conexión Zernio en Settings para que el webhook apunte al nuevo
dominio.
