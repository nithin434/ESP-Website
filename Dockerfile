FROM python:3.8-slim-bullseye as builder

# Build-time environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive

WORKDIR /tmp

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    git \
    curl \
    ca-certificates \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js for LESS (secure method with GPG verification)
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_16.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install LESS globally
RUN npm install -g less@1.7.5 && npm cache clean --force

# Install Python dependencies with pip cache for faster rebuilds
COPY esp/requirements.txt /tmp/requirements.txt
RUN pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r /tmp/requirements.txt


# Runtime stage - smaller final image
FROM python:3.8-slim-bullseye as runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    VIRTUAL_ENV=/usr \
    DEBIAN_FRONTEND=noninteractive

WORKDIR /app

# Install only runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    postgresql-client \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy Node.js and LESS from builder
COPY --from=builder /usr/bin/node /usr/bin/node
COPY --from=builder /usr/lib/node_modules /usr/lib/node_modules
RUN ln -s /usr/lib/node_modules/less/bin/lessc /usr/local/bin/lessc

# Copy Python packages from builder
COPY --from=builder /usr/local/lib/python3.8/site-packages /usr/local/lib/python3.8/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy entrypoint script
COPY docker-entrypoint.sh /app/docker-entrypoint.sh
RUN sed -i 's/\r$//' /app/docker-entrypoint.sh && \
    chmod +x /app/docker-entrypoint.sh

# Copy application code (will be overridden by volume mount in dev)
COPY esp /app/esp

EXPOSE 8000

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["python", "esp/manage.py", "runserver_plus", "0.0.0.0:8000"]
