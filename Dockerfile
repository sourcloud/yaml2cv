FROM alpine:latest

RUN apk add --update --no-cache \
    texlive \
    texmf-dist-most \
    py3-pip

RUN pip install --no-cache \
    pyyaml \
    jinja2
