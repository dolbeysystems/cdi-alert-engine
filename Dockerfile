FROM rust:buster AS build

WORKDIR /app
COPY . .
RUN rustup default nightly
RUN cargo build --release

FROM debian:bookworm-slim AS runtime 
COPY --from=build /app/target/release/cdi-alert-engine ./
COPY --from=build /app/config.toml ./
COPY --from=build /app/scripts/* ./scripts/
COPY --from=build /app/libs/* ./libs/
CMD ["./cdi-alert-engine"]

