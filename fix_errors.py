import os
import re

lib_dir = r"D:\gpssalestraker3\app\lib"
for root, dirs, files in os.walk(lib_dir):
    for f in files:
        if f.endswith('.dart'):
            filepath = os.path.join(root, f)
            with open(filepath, 'r', encoding='utf-8') as file:
                content = file.read()

            new_content = content
            lines = new_content.split('\n')
            for i, line in enumerate(lines):
                if 'context.colors.' in line:
                    if 'const ' in line:
                        lines[i] = line.replace('const ', '')

            new_content = '\n'.join(lines)

            if new_content != content:
                with open(filepath, 'w', encoding='utf-8') as file:
                    file.write(new_content)
print("Done")