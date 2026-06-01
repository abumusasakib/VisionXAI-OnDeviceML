import json
import os
import sys

def append_to_notebook(notebook_path, source_path, cell_type="code", markdown_title=None):
    """
    Appends the contents of a file (e.g. Python script or Markdown document) as a cell to the Jupyter notebook.
    """
    if not os.path.exists(notebook_path):
        raise FileNotFoundError(f"Notebook not found: {notebook_path}")
    if not os.path.exists(source_path):
        raise FileNotFoundError(f"Source file not found: {source_path}")

    # Read source file content
    with open(source_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Load Jupyter notebook
    with open(notebook_path, 'r', encoding='utf-8') as f:
        nb = json.load(f)

    new_cells = []

    # Optionally add a markdown title/explanation cell
    if markdown_title:
        new_cells.append({
            "cell_type": "markdown",
            "metadata": {},
            "source": [line + "\n" for line in markdown_title.strip().split("\n")]
        })

    # Prepare cell source lines
    source_lines = [line + "\n" for line in content.splitlines()]
    if source_lines and source_lines[-1] == "\n":
        source_lines = source_lines[:-1]

    # Create new cell
    cell = {
        "cell_type": cell_type,
        "metadata": {},
        "source": source_lines
    }
    if cell_type == "code":
        cell["outputs"] = []
        cell["execution_count"] = None

    new_cells.append(cell)

    # Append to notebook cells
    nb['cells'].extend(new_cells)

    # Write back to notebook
    with open(notebook_path, 'w', encoding='utf-8') as f:
        json.dump(nb, f, ensure_ascii=False, indent=2)

    print(f"Successfully integrated '{source_path}' into '{notebook_path}'")

if __name__ == "__main__":
    # If run directly as a script, support running basic integrations
    notebook = r"d:\courses\graduate project\xai new project\codeocean project\capsule-5653931\code\bangla_image_caption.ipynb"
    
    # 1. Integrate download_fonts.py
    download_fonts_script = r"d:\courses\graduate project\xai new project\codeocean project\capsule-5653931\code\download_fonts.py"
    if os.path.exists(download_fonts_script):
        append_to_notebook(
            notebook_path=notebook,
            source_path=download_fonts_script,
            cell_type="code",
            markdown_title="# --- Bengali Font Downloader ---\nDownload Bengali fonts into environment directory."
        )

    # 2. Integrate verify_models.py
    verify_models_script = r"d:\courses\graduate project\xai new project\codeocean project\capsule-5653931\code\verify_models.py"
    if os.path.exists(verify_models_script):
        append_to_notebook(
            notebook_path=notebook,
            source_path=verify_models_script,
            cell_type="code",
            markdown_title="# --- TFLite Model Verification ---\nVerify converted TFLite models using Interpreter."
        )
