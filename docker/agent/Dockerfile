FROM python:3.12-slim

LABEL org.opencontainers.image.title="HomeServarr Jarvis Agent"
LABEL org.opencontainers.image.description="AI home lab assistant — Signal bot backed by Claude API."
LABEL maintainer="HomeServarr"

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY jarvis.py agent.py tools.py signal_client.py ./

RUN useradd -m -s /bin/sh jarvis && mkdir -p /home/jarvis/.ssh && chmod 700 /home/jarvis/.ssh
USER jarvis

ENTRYPOINT ["python", "jarvis.py"]
