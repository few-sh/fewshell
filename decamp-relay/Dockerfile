# Build stage
FROM rust:1.88-alpine AS builder

RUN apk add --no-cache musl-dev openssl-dev openssl-libs-static

ENV OPENSSL_STATIC=1

WORKDIR /app

# Copy manifests first for better layer caching
COPY Cargo.toml Cargo.lock ./

# Create dummy src to build dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release && rm -rf src

# Copy actual source and rebuild
COPY src ./src
RUN touch src/main.rs && cargo build --release

# Runtime stage - using scratch for minimal size
FROM scratch

COPY --from=builder /app/target/release/decamp-relay /decamp-relay

# Keys directory should be mounted at runtime
EXPOSE 8080

ENTRYPOINT ["/decamp-relay"]
