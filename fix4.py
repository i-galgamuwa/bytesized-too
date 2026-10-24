import re
import os

lib_dir = r"D:\gpssalestraker3\app\lib"

# Fix invalid constants by globally dropping 'const' before capitalized words in all files
for root, dirs, files in os.walk(lib_dir):
    for f in files:
        if f.endswith('.dart'):
            filepath = os.path.join(root, f)
            with open(filepath, 'r', encoding='utf-8') as file:
                content = file.read()

            # This regex looks for `const ` followed by a Word(
            # Since some things like `const SizedBox` are fine if they don't contain context.colors,
            # it might degrade performance slightly by dropping some valid consts, but it will fix the build.
            new_content = re.sub(r'const\s+([A-Z]\w*)\(', r'\1(', content)

            # Fix double vs int issue
            # The argument type 'int' can't be assigned to the parameter type 'double'
            # Usually happens with `radius: 12` where it expects `12.0`
            if f == "map_screen.dart":
                new_content = new_content.replace("radius: 12,", "radius: 12.0,")
                new_content = new_content.replace("radius: 8,", "radius: 8.0,")
                new_content = new_content.replace("strokeWidth: 3,", "strokeWidth: 3.0,")
            if f == "shift_detail_screen.dart":
                new_content = new_content.replace("radius: 12,", "radius: 12.0,")
                new_content = new_content.replace("radius: 8,", "radius: 8.0,")
                new_content = new_content.replace("strokeWidth: 3,", "strokeWidth: 3.0,")

            if new_content != content:
                with open(filepath, 'w', encoding='utf-8') as file:
                    file.write(new_content)
print("Done")