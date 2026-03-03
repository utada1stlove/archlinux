# 中文书籍/报告 LaTeX 模板

这是一个为中文书籍、学术报告或长篇笔记设计的 LaTeX 模板。它基于 `ctexbook` 文档类，使用 `xelatex` 编译器，并预设了多种常用格式，旨在提供一个美观、专业且易于上手的排版解决方案。

## 主要特性

* **中文支持**：基于 `ctexbook`，完美支持中文排版。
* **专业编译**：指定使用 `xelatex` 编译，以获得更好的字体和 Unicode 支持。
* **优雅页面布局**：
    * A4 纸张，12pt 基础字号，双面打印 (`twoside`) 优化。
    * 通过 `geometry` 宏包自定义页边距和页眉高度。
* **信息丰富的页眉**：
    * 使用 `fancyhdr` 定制，外侧显示页码。
    * 内侧显示当前章标题，并在节标题与章标题不同时，换行显示节标题，提供清晰导航。
    * 章节起始页（`plain` 样式）也同步定制页眉（无分割线）。
* **自定义章节标题**：
    * 使用 `titlesec` 宏包调整了 `\section` 和 `\subsubsection` 的字体、大小和间距。
* **深度编号与目录**：章节编号和目录层级默认支持到 `\paragraph` 级别。
* **定制脚注**：脚注标记形如 `[~1~]`，脚注分割线样式调整。
* **交互式 PDF**：
    * 通过 `hyperref` 实现 PDF 内部链接（目录、引用等）。
    * 自定义链接颜色，可设置 PDF 文档元信息（标题、作者）。
* **常用宏包预载**：包含 `setspace`, `multicol`, `cite`, `array`, `xcolor` 等，方便扩展功能。
* **清晰文档结构**：
    * 标准封面 (`\maketitle`)。
    * 目录 (`\tableofcontents`) 页码使用大写罗马数字。
    * 正文页码使用阿拉伯数字。

## 环境要求

1.  **LaTeX 发行版**：
    * 推荐使用较新的 TeX Live, MiKTeX 或 MacTeX 发行版。
2.  **编译器**：
    * 必须使用 `xelatex` 进行编译。
3.  **主要依赖宏包**：
    * `ctexbook` (通常随 `ctex` 宏集安装)
    * `geometry`
    * `fancyhdr`
    * `hyperref`
    * `titlesec`
    * `varwidth`
    * 以及其他标准 LaTeX 宏包。通常 LaTeX 发行版会自动安装缺失的宏包，或在编译时提示安装。

## 使用方法

1.  **获取模板**：将提供的 `.tex` 模板代码保存为文件，例如 `my_document.tex`。
2.  **编辑内容**：
    * 修改 `\title{}`、`\author{}` 中的文档标题和作者。
    * 在 `\hypersetup` 中修改 `pdftitle` 和 `pdfauthor` 以设置 PDF 元数据。
    * 在 `\begin{document}` 和 `\end{document}` 之间撰写您的正文内容，使用标准的 LaTeX 命令（如 `\part`, `\chapter`, `\section`, `\subsection`, 列表，插入图片等）。
3.  **编译文档**：
    * 打开终端或命令提示符，导航到 `.tex` 文件所在的目录。
    * 执行编译命令：
        ```bash
        xelatex my_document.tex
        ```
    * 为了正确生成目录、交叉引用和页眉信息，通常需要**编译至少两次或三次**：
        ```bash
        xelatex my_document.tex
        xelatex my_document.tex
        ```
4.  **查看结果**：编译完成后，会生成 `my_document.pdf` 文件，即为排版好的文档。

## 自定义与扩展

* **页面边距**：在 `\usepackage[...]{geometry}` 中修改 `top`, `bottom`, `left`, `right` 等参数。
* **页眉页脚**：查阅 `fancyhdr` 宏包文档，修改 `\fancyhead` 和 `\fancyfoot` 相关命令。
* **章节标题**：查阅 `titlesec` 宏包文档，修改 `\titleformat` 和 `\titlespacing` 命令。
* **颜色**：在 `\hypersetup` 或使用 `xcolor` 宏包定义和使用更多颜色。
* **参考文献**：可以结合 BibTeX 或 BibLaTeX 进行参考文献管理。模板中已包含 `cite` 宏包，可根据需要引入 `.bib` 文件并选择文献样式。

## 文件结构（示例）
.
├── my_document.tex     # 您的 LaTeX 主文件
├── README.md           # 本说明文件
└── (可选) my_bibliography.bib # 如果使用 BibTeX，您的参考文献数据库

---

祝您使用愉快！
