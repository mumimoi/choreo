FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl \
    openssh-server \
    python3 \
    tini \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p --mode=0755 /usr/share/keyrings \
  && curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
    | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null \
  && echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" \
    > /etc/apt/sources.list.d/cloudflared.list \
  && apt-get update && apt-get install -y --no-install-recommends cloudflared \
  && rm -rf /var/lib/apt/lists/*

RUN groupadd -g 10014 app \
  && useradd -m -u 10014 -g 10014 -s /bin/bash app

RUN mkdir -p /var/www \
  && printf "Hello World\n" > /var/www/index.html \
  && chown -R app:app /var/www

# penting: entrypoint di luar /home/app supaya gak ketutup volume mount
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 2222 6080

USER 10014

ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/usr/local/bin/entrypoint.sh"]EXPOSE 2222 6080

USER 10014

ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/home/app/entrypoint.sh"]
