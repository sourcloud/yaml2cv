build: cv.tex
	docker run --rm -it --mount type=bind,source="$(shell pwd)",target=/app texlive/texlive:latest latexmk -pdf -output-directory="/app" /app/cv.tex && latexmk -c

cv.tex:
	python3 yaml2cv.py

clean:
	rm -f cv.pdf cv.tex
