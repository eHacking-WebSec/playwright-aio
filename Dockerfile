ARG PLAYWRIGHT_VERSION=1.55.0
FROM mcr.microsoft.com/playwright/python:v${PLAYWRIGHT_VERSION}-jammy

# Build-time overridable versions (re-declare PLAYWRIGHT_VERSION so it is
# visible in this build stage; the others get their defaults here)
ARG PLAYWRIGHT_VERSION
ARG NOVNC_VERSION=v1.5.0
ARG WEBSOCKIFY_VERSION=v0.12.0

LABEL org.opencontainers.image.source="https://github.com/eHacking-WebSec/playwright-aio" \
      org.opencontainers.image.title="Playwright AIO Runner" \
      org.opencontainers.image.description="All-in-one Playwright Python runner with web IDE, terminal and noVNC browser viewer" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${PLAYWRIGHT_VERSION}"

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    DISPLAY=:99 \
    RESOLUTION=1920x1080x24 \
    VNC_RESOLUTION=1920x1080

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    x11vnc \
    xvfb \
    feh \
    fluxbox \
    websockify \
    net-tools \
    python3-pip \
    git \
    curl \
    thunar \
    tini \
    tzdata \
    x11-utils \
    xclip \
    xsel \
    && rm -rf /var/lib/apt/lists/*

# Install noVNC (pinned for reproducible builds — versions defined as ARG above)
RUN git clone --depth 1 --branch ${NOVNC_VERSION} https://github.com/novnc/noVNC.git /opt/novnc && \
    git clone --depth 1 --branch ${WEBSOCKIFY_VERSION} https://github.com/novnc/websockify /opt/novnc/utils/websockify && \
    ln -s /opt/novnc/vnc.html /opt/novnc/index.html

# Install Python packages
# Pin playwright to the base-image version so the bundled browser binaries
# stay in sync (avoid implicit upgrade by pip)
RUN pip install --no-cache-dir \
    playwright==${PLAYWRIGHT_VERSION} \
    flask \
    flask-cors \
    flask-socketio \
    eventlet

# Create working directory
WORKDIR /workspace

# Copy the default Playwright script
COPY scripts/main.py /workspace/main.py

# Copy Flask app and web interface
COPY src/app.py /app/app.py
COPY src/web /app/web

# Copy startup script
COPY --chmod=0755 scripts/docker-entrypoint.sh /docker-entrypoint.sh

# Expose ports
# 8080: Web interface
# 6080: noVNC
# 5900: VNC
EXPOSE 8080 6080 5900

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl -fsS http://localhost:8080/ >/dev/null || exit 1

# Start services (tini as PID 1 for proper signal handling and zombie reaping)
ENTRYPOINT ["/usr/bin/tini", "--", "/docker-entrypoint.sh"]
