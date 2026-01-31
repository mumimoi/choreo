FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Basic tools + SSH + Python + tini
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl \
    openssh-server \
    python3 \
    tini \
  && rm -rf /var/lib/apt/lists/*

# Install cloudflared dari repo resmi Cloudflare (APT)
RUN mkdir -p --mode=0755 /usr/share/keyrings \
  && curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
    | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null \
  && echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" \
    > /etc/apt/sources.list.d/cloudflared.list \
  && apt-get update && apt-get install -y --no-install-recommends cloudflared \
  && rm -rf /var/lib/apt/lists/*

# Create non-root user (contoh UID 10014)
RUN groupadd -g 10014 app \
  && useradd -m -u 10014 -g 10014 -s /bin/bash app

# Prepare dirs (keep /run/sshd so sshd doesn't complain)
RUN mkdir -p /run/sshd /var/www \
  && printf "Hello World\n" > /var/www/index.html \
  && chown -R app:app /var/www \
  && mkdir -p /home/app/.ssh /home/app/ssh /home/app/run \
  && chmod 700 /home/app/.ssh \
  && chown -R app:app /home/app

COPY --chown=app:app entrypoint.sh /home/app/entrypoint.sh
RUN chmod +x /home/app/entrypoint.sh

EXPOSE 2222 6080

USER 10014

ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/home/app/entrypoint.sh"]
