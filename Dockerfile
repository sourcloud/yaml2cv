FROM alpine:latest

RUN apk add --update --no-cache \
    texlive \
    texmf-dist-most \
    py3-pip


WORKDIR /app
COPY app .

RUN pip install --no-cache -r requirements.txt

CMD ["python3", "yaml2moderncv.py"]

