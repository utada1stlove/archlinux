from flask import Flask, render_template, jsonify, request
import json
import os
from datetime import datetime
from pathlib import Path
from collections import defaultdict

app = Flask(__name__)

DATA_FILE = Path('data/todos.json')
LATEX_FILE = Path('todolist.tex')

MONTHS = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
]


def load_todos():
    if DATA_FILE.exists():
        return json.loads(DATA_FILE.read_text())
    return {}


def save_todos(todos):
    DATA_FILE.parent.mkdir(exist_ok=True)
    DATA_FILE.write_text(json.dumps(todos, indent=2))


def latex_escape(text):
    replacements = [
        ('\\', r'\textbackslash{}'),
        ('{',  r'\{'),
        ('}',  r'\}'),
        ('$',  r'\$'),
        ('&',  r'\&'),
        ('%',  r'\%'),
        ('#',  r'\#'),
        ('_',  r'\_'),
        ('^',  r'\textasciicircum{}'),
        ('~',  r'\textasciitilde{}'),
    ]
    for char, escaped in replacements:
        text = text.replace(char, escaped)
    return text


def generate_latex(todos):
    lines = [
        r'\documentclass{report}',
        r'\usepackage[utf8]{inputenc}',
        r'\usepackage[T1]{fontenc}',
        r'\usepackage{amssymb}',
        r'\usepackage{geometry}',
        r'\geometry{a4paper, margin=2.5cm}',
        r'\usepackage{parskip}',
        r'\setlength{\parindent}{0pt}',
        r'',
        r'\begin{document}',
        r'',
        r'\begin{center}',
        r'  {\Huge\bfseries TODOLIST}',
        r'\end{center}',
        r'',
    ]

    by_year = defaultdict(lambda: defaultdict(list))
    for date_str, tasks in sorted(todos.items()):
        try:
            date = datetime.strptime(date_str, '%Y-%m-%d')
        except ValueError:
            continue
        by_year[date.year][date.month].append((date, tasks))

    for year in sorted(by_year.keys()):
        lines.append(f'\\chapter{{{year}}}')
        lines.append('')
        for month in sorted(by_year[year].keys()):
            lines.append(f'\\section{{{MONTHS[month - 1]}}}')
            lines.append('')
            for date, tasks in sorted(by_year[year][month], key=lambda x: x[0]):
                day_str = date.strftime('%B %d, %Y')
                lines.append(f'\\subsection{{{day_str}}}')
                lines.append('')
                if tasks:
                    lines.append(r'\begin{itemize}')
                    for task in tasks:
                        checkbox = r'$\boxtimes$' if task.get('done') else r'$\square$'
                        text = latex_escape(task.get('text', ''))
                        lines.append(f'  \\item[{checkbox}] {text}')
                    lines.append(r'\end{itemize}')
                else:
                    lines.append(r'\textit{(no tasks)}')
                lines.append('')

    lines.append(r'\end{document}')
    return '\n'.join(lines)


@app.route('/')
def index():
    return render_template('index.html')


@app.route('/api/todos/today', methods=['GET'])
def get_today_todos():
    today = datetime.now().strftime('%Y-%m-%d')
    todos = load_todos()
    return jsonify({'date': today, 'tasks': todos.get(today, [])})


@app.route('/api/todos/today', methods=['PUT'])
def save_today_todos():
    today = datetime.now().strftime('%Y-%m-%d')
    todos = load_todos()
    todos[today] = request.json.get('tasks', [])
    save_todos(todos)
    return jsonify({'status': 'ok'})


@app.route('/api/export', methods=['POST'])
def export_latex():
    todos = load_todos()
    latex = generate_latex(todos)
    LATEX_FILE.write_text(latex)
    return jsonify({'status': 'ok', 'file': str(LATEX_FILE.absolute())})


if __name__ == '__main__':
    import sys
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 5000
    app.run(debug=True, port=port)
