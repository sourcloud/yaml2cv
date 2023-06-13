import yaml
import subprocess
import os
import sys

from uuid import uuid4
from flask import Flask, request, send_file
from jinja2 import Environment, FileSystemLoader, exceptions
from pathlib import Path



app = Flask(__name__)
template = None

APP_DIR = Path(__file__).parent.resolve()

@app.route('/render-cv', methods=['POST'])
def render_cv():

    cv_file = request.files['file']

    try:
        cv_data = yaml.safe_load(cv_file)
        rendered_cv = template.render(cv_data)
    except (yaml.YAMLError, exceptions.UndefinedError, TypeError):
        return 'Invalid YAML file', 400

    uuid = uuid4()
    proc, _, err = process_tex(rendered_cv, uuid)

    if proc.returncode != 0:
        return err.decode('utf-8'), 500

    return create_response_and_cleanup(uuid)


def process_tex(template, uuid):

    latex_command = ['pdflatex', f'-jobname=cv-{uuid}', f'-output-directory={APP_DIR}'] 

    latex_process = subprocess.Popen(
        latex_command, 
        stdin=subprocess.PIPE, 
        stdout=subprocess.PIPE, 
        stderr=subprocess.PIPE
    )

    return latex_process, *latex_process.communicate(template.encode())


def create_response_and_cleanup(uuid):

    response = send_file(f'cv-{uuid}.pdf', as_attachment=True, mimetype='application/pdf')

    for file in APP_DIR.glob(f'cv-{uuid}*'):
        os.remove(file)

    return response



if __name__ == '__main__':

    try:
        env = Environment(loader=FileSystemLoader(APP_DIR), trim_blocks=True, lstrip_blocks=True)
        template = env.get_template('cv_template.j2')
    except exceptions.TemplateError:
        print('Could not load template.', file=sys.stderr)
        exit(1)
        
    app.run(host="0.0.0.0")
