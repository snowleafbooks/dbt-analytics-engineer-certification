FROM mcr.microsoft.com/devcontainers/python:3.11-bookworm

ARG USERNAME=vscode

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        postgresql-client \
        make \
        jq \
        git \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME
WORKDIR /home/$USERNAME

COPY --chown=$USERNAME:$USERNAME requirements.txt /tmp/requirements.txt

RUN python -m pip install --user --no-cache-dir --upgrade pip \
 && python -m pip install --user --no-cache-dir -r /tmp/requirements.txt \
 && mkdir -p /home/$USERNAME/.dbt

ENV PATH="/home/${USERNAME}/.local/bin:${PATH}"
ENV DBT_PROFILES_DIR="/home/${USERNAME}/.dbt"
