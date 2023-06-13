.PHONY: help build run

help:
	cat Makefile

run:
	docker run --rm -d -p 5000:5000 yaml2moderncv:0.1.0

build:
	docker build --tag=yaml2moderncv:0.1.0 .
