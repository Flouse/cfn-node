FROM rust:1.76-slim-bookworm as builder

WORKDIR /fiber

RUN apt-get update && \
    apt-get install -y clang

# Build the application
COPY . .
RUN cargo build --release


# Build the final image
FROM debian:bookworm-slim
LABEL maintainer="Flouse" \
      description="Fiber Network Node"

# Upgrade all packages and install dependencies
RUN apt-get update && apt-get upgrade -y \
 && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    ca-certificates \
    tini \
    curl \
    gnupg \
    clang \
 && apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# add ckb-cli into the docker image
# https://github.com/nervosnetwork/ckb-cli/releases/tag/v1.12.0
ARG CKB_CLI_VERSION=v1.12.0
ARG Nervos_CI_SIGNATURE=8D09AC56856F84AFDB2CEB12E21C4F2E34FF2E93

RUN cd /tmp \
 && curl -LO https://github.com/nervosnetwork/ckb-cli/releases/download/${CKB_CLI_VERSION}/ckb-cli_${CKB_CLI_VERSION}_x86_64-unknown-linux-gnu.tar.gz \
 && curl -LO https://github.com/nervosnetwork/ckb-cli/releases/download/${CKB_CLI_VERSION}/ckb-cli_${CKB_CLI_VERSION}_x86_64-unknown-linux-gnu.tar.gz.asc \
 && gpg --verify --status-fd 1 \
        --verify ckb-cli_${CKB_CLI_VERSION}_x86_64-unknown-linux-gnu.tar.gz.asc \
                 ckb-cli_${CKB_CLI_VERSION}_x86_64-unknown-linux-gnu.tar.gz 2>&1 \
    | grep -C1 "using RSA key ${Nervos_CI_SIGNATURE}" \
 && echo "Found the signature of bot@nervos.org" \
 && tar xzf ckb-cli_${CKB_CLI_VERSION}_x86_64-unknown-linux-gnu.tar.gz \
 && cp ckb-cli_${CKB_CLI_VERSION}_x86_64-unknown-linux-gnu/ckb-cli /bin/ckb-cli \
 && rm -rf /tmp \
 && chmod 755 /bin/ckb-cli
 
COPY --from=builder /fiber/target/release/fnn /bin/fnn
# TODO: copy ['libclang.so', 'libclang-*.so', 'libclang.so.*', 'libclang-*.so.*']
# COPY --from=builder \
#   /usr/lib/x86_64-linux-gnu/libssl.so.* \
#   /usr/lib/x86_64-linux-gnu/libcrypto.so.* \
#   /usr/lib/x86_64-linux-gnu/

# System accounts (-r flag) are specifically designed for running services/daemons
RUN useradd -r fiber --home /fiber
USER fiber
WORKDIR /fiber
ENV BASE_DIR /fiber/.fiber-node

# VOLUME /fiber-data
VOLUME ["/fiber/.fiber-node"]

EXPOSE 8227 8228
STOPSIGNAL SIGINT

# Set the entrypoint to https://github.com/krallin/tini
ENTRYPOINT [ "tini", "--" ]
CMD [ "/bin/fnn", "--version" ]


# TODO: Add Healthcheck Instruction
# HEALTHCHECK --interval=30s --timeout=3s \
#   CMD curl -f http://localhost:8227/ || exit 1
