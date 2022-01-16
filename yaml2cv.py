import yaml
from jinja2 import Environment, FileSystemLoader

if __name__ == '__main__':

    with open('cv_data.yaml') as yaml_file:

        cv_data = yaml.load(yaml_file, Loader=yaml.FullLoader)

        env = Environment(loader = FileSystemLoader('.'), trim_blocks=True, lstrip_blocks=True)
        template = env.get_template('cv_template.j2')
        
        with open('output/cv.tex', 'w') as cv_file:
            cv_file.write(template.render(cv_data))
