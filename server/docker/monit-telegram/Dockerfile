# Bullseye userspace for compatibility with older Docker installations.
FROM python:3.11-slim-bullseye
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt && \
    mkdir -p /var/lib/monit-telegram && \
    chown 10001:10001 /var/lib/monit-telegram && \
    chmod 700 /var/lib/monit-telegram
COPY bridge.py telegram_api.py monit_api.py commands.py ./
USER 10001:10001
CMD ["python", "bridge.py"]
