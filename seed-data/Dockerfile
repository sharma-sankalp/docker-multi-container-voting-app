FROM python:3.9-slim

# add apache bench (ab) tool
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    apache2-utils \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system seed \
    && useradd --system --gid seed --home-dir /nonexistent --shell /usr/sbin/nologin seed \
    && mkdir -p /seed \
    && chown seed:seed /seed

WORKDIR /seed

COPY --chown=seed:seed . .

# create POST data files with ab friendly formats
RUN python make-data.py

ENV VOTE_URL=http://vote:8080
USER seed
CMD ["/seed/generate-votes.sh"]
