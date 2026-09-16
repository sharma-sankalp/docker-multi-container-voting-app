# base defines a base stage that uses the official python runtime base image
FROM python:3.11.16-slim@sha256:9534e5a8e315485d4061ed659af0fd78a284c015f9b73661b41d6bab25604534 AS base

RUN apt-get update && \
    apt-get upgrade -y && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd --system vote && \
    useradd --system --gid vote --home-dir /nonexistent --shell /usr/sbin/nologin vote && \
    mkdir -p /usr/local/app && \
    chown vote:vote /usr/local/app

WORKDIR /usr/local/app

COPY requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

FROM base AS dev
RUN pip install watchdog
ENV FLASK_ENV=development \
    PORT=8080
USER vote
CMD ["python", "app.py"]

FROM base AS final

COPY --chown=vote:vote . .

EXPOSE 8080

USER vote
CMD ["gunicorn", "app:app", "-b", "0.0.0.0:8080", "--log-file", "-", "--access-logfile", "-", "--workers", "4", "--keep-alive", "0"]
