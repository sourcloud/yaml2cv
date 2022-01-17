.PHONY: help fresh build clean

help:
	cat Makefile

fresh: clean build

build: cv.pdf

cv.pdf: cv.tex
	docker run --rm -it --mount type=bind,source="$(shell pwd)",target=/app texlive/texlive:latest /bin/bash -c "cd /app && latexmk -pdf -output-directory=/app cv.tex && latexmk -c"

cv.tex:
	docker run --rm -it --mount type=bind,source="$(shell pwd)",target=/app python:latest /bin/bash -c "python3 -m pip install jinja2 pyyaml && cd /app && python3 yaml2moderncv.py"

clean:
	rm -f cv.*
