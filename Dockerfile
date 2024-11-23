FROM rust:1.76-bullseye as builder

WORKDIR /fiber
COPY . .

RUN apt-get update && \
    apt-get install -y clang && \
    cargo build --release

FROM debian:bullseye-slim

RUN apt-get update && \
    apt-get install -y ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /fiber/target/release/fnn /usr/local/bin/

EXPOSE 8227 8228

ENTRYPOINT ["fnn"]
