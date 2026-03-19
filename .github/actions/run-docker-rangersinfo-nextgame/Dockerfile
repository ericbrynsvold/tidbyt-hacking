FROM alpine:edge
RUN apk add git go libwebp libwebp-dev alpine-sdk tzdata

RUN apk add --no-cache git go libwebp libwebp-dev alpine-sdk tzdata && \
    git clone --depth 1 --branch v0.34.0 https://github.com/tidbyt/pixlet && \
    cd pixlet && \
    make build && \
    cp pixlet /bin/pixlet && \
    cd / && rm -rf /pixlet /root/go /root/.cache/go-build && \
    apk del alpine-sdk go

ENV TZ=America/Chicago

COPY . .

ENTRYPOINT ["sh", "-c", "sh build-rangersinfo.sh && sh build-nextgame.sh"]

