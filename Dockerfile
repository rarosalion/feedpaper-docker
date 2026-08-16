FROM python:3.14.7-slim

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY . /tmp/build-context/

RUN set -eux; \
    if [ -d /tmp/build-context/feedpaper ]; then \
        SOURCE_DIR=/tmp/build-context/feedpaper; \
    else \
        SOURCE_DIR=/tmp/build-context; \
    fi; \
    cp -a "$SOURCE_DIR" /tmp/feedpaper; \
    rm -rf /tmp/build-context

WORKDIR /tmp/feedpaper

RUN python -m venv /opt/venv \
    && . /opt/venv/bin/activate \
    && pip install --no-cache-dir --upgrade pip setuptools wheel \
    && pip install --no-cache-dir .

ENV PATH="/opt/venv/bin:$PATH" \
    XDG_CONFIG_HOME=/root/.config

RUN mkdir -p /output /root/.config/feedpaper

COPY scripts/run-feedpaper.sh /usr/local/bin/run-feedpaper.sh
COPY scripts/send-feedpaper-email.py /usr/local/bin/send-feedpaper-email.py
RUN chmod +x /usr/local/bin/run-feedpaper.sh /usr/local/bin/send-feedpaper-email.py

ENTRYPOINT ["/usr/local/bin/run-feedpaper.sh"]
CMD []
