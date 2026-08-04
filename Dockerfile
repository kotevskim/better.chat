# Better.Chat — static client + tiny proxy in one image.
# The Rocket.Chat hostname is never baked in; pass it at run time:
#
#   docker run -d --name better-chat --restart unless-stopped \
#     -p 127.0.0.1:9000:9000 -e BC_SERVER=your.rocketchat.host \
#     ghcr.io/kotevskim/better.chat:latest
#
# The container always listens on 9000 internally; pick the host port with -p
# (e.g. -p 127.0.0.1:80:9000 for a port-less http://chat.localhost URL).
FROM python:3.12-alpine
WORKDIR /app
COPY proxy.py index.html ./
# 0.0.0.0 inside the container only — the -p 127.0.0.1:... mapping keeps it
# loopback-only on the host.
ENV BC_BIND=0.0.0.0
EXPOSE 9000
CMD ["python", "proxy.py"]
