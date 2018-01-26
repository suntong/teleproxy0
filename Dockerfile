
ARG golang_version

#FROM golang:$golang_version

FROM golang:1.9.0-alpine3.6

RUN echo "Build number: $golang_version"

MAINTAINER Alexey Kovrizhkin <lekovr+docker@gmail.com>

RUN apk add --no-cache make bash git g++ curl

WORKDIR /go/src/github.com/LeKovr/teleproxy
# Will fetch git commit ID
COPY .git .git
# Sources
COPY cmd cmd
COPY messages.tmpl messages.tmpl
COPY Makefile .
COPY glide.* ./

#sqlite3 is a cgo package
#ENV CGO_ENABLED=0

ENV GOOS=linux
ENV BUILD_FLAG=-a
#"-tags netgo -a -v"

RUN go get -u github.com/golang/lint/golint
RUN go get -u github.com/jteeuwen/go-bindata/...
RUN make vendor
RUN make build-standalone

# ------------------------------------------------------------------------------

# Cant use it because sqlite3
#FROM scratch
FROM alpine:3.6

RUN apk add --no-cache make bash curl

WORKDIR /
COPY --from=0 /go/src/github.com/LeKovr/teleproxy/teleproxy .
# Need for SSL
COPY --from=0 /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Templates sample
COPY messages.tmpl /
COPY commands.sh /

ENTRYPOINT ["/teleproxy"]

