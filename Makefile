.PHONY: help fresh build image clean

help:
	cat Makefile

fresh: clean build

build: cv.pdf

cv.pdf: cv.tex
	docker run --rm -it --mount type=bind,source="$(shell pwd)",target=/app yaml2moderncv:latest /bin/sh -c "cd /app && latexmk -pdf -output-directory=/app cv.tex && latexmk -c"

cv.tex:
	docker run --rm -it --mount type=bind,source="$(shell pwd)",target=/app yaml2moderncv:latest /bin/sh -c "cd /app && python3 yaml2moderncv.py"

image:
	docker build --tag=yaml2moderncv:latest .

clean:
	rm -f cv.*
