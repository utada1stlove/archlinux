# todoist-latex

## Introduction

A lightweight, local-first to-do list web application that runs on your machine and doubles as a LaTeX journal.

Open the page in your browser to manage today's tasks — add items, check them off, or delete them. Everything auto-saves as you work. When you're done for the day, hit **Export to LaTeX** to write your progress into a structured `todolist.tex` file that accumulates entries over time, organized by year, month, and day.

The web interface always shows only today's list, keeping things focused. The LaTeX file, on the other hand, grows into a permanent record of every day you used the system — a clean, compiled document you can keep, print, or archive.

## Setup

**1. Install the dependency**

On Arch Linux, Flask is available as a system package:

```bash
sudo pacman -S python-flask
```

On other systems:

```bash
pip install flask
```

**2. Clone or download the project**

```bash
git clone https://github.com/archlinux/todoist-latex.git
cd todoist-latex
```

**3. Start the server**

```bash
./run.sh
```

Or directly:

```bash
python3 app.py
```

The server starts at `http://localhost:5000`. Open that address in your browser.

## Usage

| Action | How |
|---|---|
| Add a task | Type in the input field and press **Enter** or click **Add** |
| Complete a task | Click the checkbox or the task text |
| Delete a task | Hover the task and click **×** |
| Save | Automatic — happens 600 ms after any change |
| Export to LaTeX | Click **Export to LaTeX** in the bottom-right corner |

### LaTeX output

Exporting writes (or overwrites) `todolist.tex` in the project directory. The file structure mirrors the hierarchy below:

```
TODOLIST
└── chapter  — year    (e.g. 2026)
    └── section  — month   (e.g. March)
        └── subsection — day  (e.g. March 10, 2026)
            ├── □  pending task
            └── ⊠  completed task
```

Compile it with any standard LaTeX toolchain:

```bash
pdflatex todolist.tex
```

### Data storage

Tasks are stored locally in `data/todos.json`. Every date you have used the app is retained in this file; only today's entries are shown in the browser. The JSON file is the source of truth — `todolist.tex` is always regenerated from it on export.
