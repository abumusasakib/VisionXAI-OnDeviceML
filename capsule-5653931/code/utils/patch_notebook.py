import json
import os
import sys

def patch_notebook_cell(notebook_path, target_string, insert_string, position='below'):
    """
    Finds a cell containing `target_string` and inserts `insert_string` (either 'above' or 'below' the matching line).
    """
    if not os.path.exists(notebook_path):
        raise FileNotFoundError(f"Notebook not found: {notebook_path}")

    with open(notebook_path, 'r', encoding='utf-8') as f:
        nb = json.load(f)

    patched = False

    for cell in nb['cells']:
        if cell['cell_type'] == 'code':
            source = cell['source']
            source_text = "".join(source)
            
            if target_string in source_text:
                # Check if insert_string already exists to avoid duplicate patching
                if insert_string.strip() in source_text:
                    print(f"Skipping patch: '{insert_string.strip()}' already exists in matching cell.")
                    return True

                new_source = []
                for line in source:
                    if position == 'above' and target_string in line:
                        new_source.append(insert_string + "\n")
                        new_source.append(line)
                        patched = True
                    elif position == 'below' and target_string in line:
                        new_source.append(line)
                        new_source.append(insert_string + "\n")
                        patched = True
                    else:
                        new_source.append(line)
                
                cell['source'] = new_source
                if patched:
                    break

    if patched:
        with open(notebook_path, 'w', encoding='utf-8') as f:
            json.dump(nb, f, ensure_ascii=False, indent=2)
        print(f"Successfully patched '{notebook_path}'")
        return True
    else:
        print(f"Target string '{target_string}' not found in any cell of '{notebook_path}'")
        return False

if __name__ == "__main__":
    notebook = r"d:\courses\graduate project\xai new project\codeocean project\capsule-5653931\code\bangla_image_caption.ipynb"
    
    # Run patch to insert fm import under setup_bengali_fonts
    patch_notebook_cell(
        notebook_path=notebook,
        target_string="def setup_bengali_fonts():",
        insert_string="    import matplotlib.font_manager as fm",
        position='below'
    )
