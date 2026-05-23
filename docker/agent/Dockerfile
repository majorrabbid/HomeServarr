FROM alpine:3.18

LABEL org.opencontainers.image.title="HomeServarr Jarvis Agent"
LABEL org.opencontainers.image.description="Containerized stub for the HomeServarr Jarvis agent."
LABEL org.opencontainers.image.licenses="MIT"
LABEL maintainer="HomeServarr"

WORKDIR /opt/homeservarr

COPY homeservarr-agent /usr/local/bin/homeservarr-agent
RUN chmod +x /usr/local/bin/homeservarr-agent \
  && addgroup -S jarvis \
  && adduser -S -G jarvis jarvis

USER jarvis

ENTRYPOINT ["/usr/local/bin/homeservarr-agent"]
CMD []
