FROM rust:buster AS build

WORKDIR /app
COPY . .
RUN rustup default nightly
RUN apt-get update
RUN apt-get install musl-tools -y
RUN rustup target add x86_64-unknown-linux-musl
RUN cargo build --release --target x86_64-unknown-linux-musl

#RUN apt-get install upx-ucl -y
#RUN upx /app/target/x86_64-unknown-linux-musl/release/fusion-hl7-rust

FROM scratch
COPY --from=build /app/target/x86_64-unknown-linux-musl/release/cdi-alert-engine ./
COPY --from=build /app/config.toml ./
COPY --from=build /app/scripts/* ./scripts/
COPY --from=build /app/libs/* ./libs/
CMD ["./cdi-alert-engine"]

