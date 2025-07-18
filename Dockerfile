FROM python:3.11-slim AS base

# Install common system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install uv
RUN pip install uv

# Set working directory
WORKDIR /app

# Install browser-use with CLI extras
RUN pip install "browser-use[cli]"

# Install Playwright system dependencies as root
RUN playwright install-deps chromium

# Create a non-root user for security
RUN useradd -m -s /bin/bash browseruse

# Switch to browseruse user and install Playwright browsers
USER browseruse
RUN playwright install chromium

# Switch back to root for configuration
USER root

# =======================================================
# HEADLESS MODE
# =======================================================
FROM base AS headless

# Set environment variables for headless mode
ENV PYTHONUNBUFFERED=1
ENV BROWSER_USE_HEADLESS=true

# Switch to browseruse user for running the server
USER browseruse

# Run the browser-use MCP server in headless mode
CMD ["python", "-m", "browser_use.cli", "--mcp"]

# =======================================================
# VNC MODE
# =======================================================
FROM base AS vnc

# Install additional VNC-specific dependencies
RUN apt-get update && apt-get install -y \
    xvfb \
    x11vnc \
    fluxbox \
    tigervnc-standalone-server \
    && rm -rf /var/lib/apt/lists/*

# Set up VNC for root user
RUN mkdir -p /root/.vnc && \
    echo 'browseruse' | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Set environment variables for VNC mode
ENV PYTHONUNBUFFERED=1
ENV DISPLAY=:99
ENV BROWSER_USE_HEADLESS=false

# Create startup script
RUN echo '#!/bin/bash\n\
    # Start Xvfb\n\
    Xvfb :99 -screen 0 1024x768x24 &\n\
    sleep 2\n\
    # Start window manager\n\
    fluxbox &\n\
    # Start VNC server\n\
    x11vnc -display :99 -forever -passwd browseruse &\n\
    # Give VNC time to start\n\
    sleep 2\n\
    # Switch to browseruse user and start MCP server\n\
    su -c "cd /app && python -m browser_use.cli --mcp" browseruse\n\
    ' > /start.sh && chmod +x /start.sh

# Expose VNC port
EXPOSE 5900

# Run the startup script
CMD ["/start.sh"]
