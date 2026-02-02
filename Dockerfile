# Planning Stage
FROM lukemathwalker/cargo-chef:latest-rust-1.80.1 AS chef
WORKDIR /app
RUN apt update && apt install lld clang -y

FROM chef AS planner
COPY . .
# Computer a lock-like file for project
RUN cargo chef prepare --recipe-path recipe.json

# Builder Stage
FROM chef AS builder
COPY --from=planner /app/recipe.json recipe.json
# Build project dependencies, not application
RUN cargo chef cook --release --recipe-path recipe.json
# Up to here, dependency tree stays the same => all layers cached

COPY . .
ENV SQLX_OFFLINE=true
RUN cargo build --release --bin zero2prod

# Runtime Stage
FROM debian:bookworm-slim AS runtime

WORKDIR /app

# Install OpenSSL & ca-certificates
run apt-get update -y \
    && apt-get install -y --no-install-recommends openssl ca-certificates \

    # Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/zero2prod zero2prod
COPY configuration configuration
ENV APP_ENVIRONMENT=production
ENTRYPOINT ["./zero2prod"]
