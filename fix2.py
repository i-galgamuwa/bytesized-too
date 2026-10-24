import re
import os

lib_dir = r"D:\gpssalestraker3\app\lib"

# Fix shift_detail_screen
path = os.path.join(lib_dir, "screens", "shift_detail_screen.dart")
with open(path, "r", encoding="utf-8") as f:
    text = f.read()
text = text.replace("_row(\n                'End',", "_row(\n                context,\n                'End',")
with open(path, "w", encoding="utf-8") as f:
    f.write(text)

# Remove problematic consts globally
for root, dirs, files in os.walk(lib_dir):
    for f in files:
        if f.endswith('.dart'):
            filepath = os.path.join(root, f)
            with open(filepath, 'r', encoding='utf-8') as file:
                content = file.read()

            # Simple broad regex: if line has 'const ' and 'context.colors', remove 'const '
            lines = content.split('\n')
            for i, line in enumerate(lines):
                if 'const ' in line and 'context.colors' in line:
                    lines[i] = line.replace('const ', '')

            content = '\n'.join(lines)

            # Also brute force remove const for the specific errors:
            # We can just remove const in front of common widgets.
            content = re.sub(r'const\s+(Center|Row|Column|Padding|Container|SizedBox|CircleAvatar|Widget|Icon|Text|TextStyle|CircularProgressIndicator|BoxDecoration|ListTile|Divider|AppBar|FloatingActionButton|Drawer|ListTile)\(', r'\1(', content)

            with open(filepath, 'w', encoding='utf-8') as file:
                file.write(content)
print("Done")