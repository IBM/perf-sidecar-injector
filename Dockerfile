FROM alpine:latest

ADD perf-sidecar-injector /perf-sidecar-injector
ENTRYPOINT ["./perf-sidecar-injector"]
