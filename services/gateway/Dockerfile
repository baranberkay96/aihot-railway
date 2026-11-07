# AIHOT gateway for Railway (community template): Caddy in front of the Web service, with the
# compression and security headers of upstream's deploy/Caddyfile. Routing is in the Caddyfile;
# AIHOT_WEB_UPSTREAM (Web's private host:port) and PORT come from the service variables.
FROM caddy:2.11.9-alpine@sha256:0bbb055bda6793c999bde78b1b5ce3e89f829fb031af2cf50056ea1246559fee

COPY Caddyfile /etc/caddy/Caddyfile
# Fail the build on a Caddyfile error instead of at deploy time (placeholder upstream for the check).
RUN AIHOT_WEB_UPSTREAM=web.railway.internal:3000 caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

ENV PORT=8080
EXPOSE 8080
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
