FROM golang:1.24.0-alpine AS build

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o /out/gateway ./cmd/api

FROM alpine:3.20

WORKDIR /app

COPY --from=build /out/gateway /app/gateway

EXPOSE 8000

ENTRYPOINT ["/app/gateway"]
