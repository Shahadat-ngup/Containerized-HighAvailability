FROM python:3.11-slim-bookworm

# Ensure the latest security patches are applied
RUN apt-get clean

# Upgrade system packages to address vulnerabilities
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y curl && \
    apt-get install -y wget gnupg2 lsb-release locales && \
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    apt-get update && \
    apt-get install -y postgresql-16 postgresql-client-16 && \
    apt-get upgrade -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* \
    && apt-get install -y wget \
    && wget https://github.com/etcd-io/etcd/releases/download/v3.5.13/etcd-v3.5.13-linux-amd64.tar.gz \
    && tar xzf etcd-v3.5.13-linux-amd64.tar.gz \
    && mv etcd-v3.5.13-linux-amd64/etcdctl /usr/local/bin/ \
    && rm -rf etcd-v3.5.13-linux-amd64*
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8


RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir patroni[etcd]==3.2.1 psycopg[binary]


# Ensure postgres group and user exist, set permissions
RUN getent group postgres || groupadd -r postgres && \
    id -u postgres || useradd -r -g postgres postgres && \
    mkdir -p /var/lib/postgresql/data && \
    chown -R postgres:postgres /var/lib/postgresql

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER postgres
ENTRYPOINT ["/entrypoint.sh"]