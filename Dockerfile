FROM rust:buster AS build

WORKDIR /app
COPY . .
RUN rustup default nightly
RUN cargo build --release -p cdi-alert-server

FROM debian:bookworm-slim AS runtime 
COPY --from=build /app/target/release/cdi-alert-server ./
COPY --from=build /app/config.toml ./
COPY --from=build /app/scripts/* ./scripts/
COPY --from=build /app/libs/* ./libs/
CMD ["./cdi-alert-server"]

