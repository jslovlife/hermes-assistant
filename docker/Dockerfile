FROM hermes-agent:base

# Install pi-agent for delegated coding (Node.js is already in the base image)
RUN npm install -g @earendil-works/pi-coding-agent

# On first boot, seed agent config + secrets from the mounted repo (/opt/repo) into /opt/data.
# Runs after the Hermes bootstrap (01-hermes-setup), overwriting the baked defaults.
COPY --chmod=0755 docker/05-agent-config /etc/cont-init.d/05-agent-config
