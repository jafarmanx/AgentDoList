FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    jq \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
    requests \
    httpx \
    beautifulsoup4 \
    pyyaml \
    markdown \
    pytest

RUN useradd -m -s /bin/bash agent
WORKDIR /home/agent/workspace
RUN chown -R agent:agent /home/agent

USER agent

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

ENTRYPOINT ["tail", "-f", "/dev/null"]
