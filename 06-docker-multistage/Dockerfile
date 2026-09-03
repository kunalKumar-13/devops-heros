# =========================================================
# Stage 1 — build
# A full Go toolchain (~800 MB) compiles the binary. None of
# this stage ends up in the final image.
# =========================================================
FROM golang:1.22-alpine AS builder

WORKDIR /src
COPY app/go.mod ./
COPY app/main.go ./

# CGO_ENABLED=0 produces a fully static binary, so the runtime
# stage does not need libc at all.
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /out/server main.go

# =========================================================
# Stage 2 — runtime
# Only the compiled binary is copied across. The result is a
# few megabytes instead of several hundred.
# =========================================================
FROM alpine:3.20

RUN adduser -D -u 10001 appuser
COPY --from=builder /out/server /usr/local/bin/server

USER appuser
EXPOSE 8080

CMD ["/usr/local/bin/server"]
