import os
import re

lib_dir = r"D:\gpssalestraker3\app\lib"
for root, dirs, files in os.walk(lib_dir):
    for f in files:
        if f.endswith('.dart') and f != 'app_colors.dart':
            filepath = os.path.join(root, f)
            with open(filepath, 'r', encoding='utf-8') as file:
                content = file.read()

            new_content = re.sub(r'AppColors\.', 'context.colors.', content)

            if new_content != content:
                new_content = re.sub(r'const\s+TextStyle\(\s*color:\s*context\.colors\.', r'TextStyle(color: context.colors.', new_content)
                new_content = re.sub(r'const\s+Icon\(([^,]+),\s*color:\s*context\.colors\.', r'Icon(\1, color: context.colors.', new_content)
                new_content = re.sub(r'const\s+Text\(([^,]+),\s*style:\s*const\s+TextStyle\(\s*color:\s*context\.colors\.', r'Text(\1, style: TextStyle(color: context.colors.', new_content)
                new_content = re.sub(r'const\s+Text\(([^,]+),\s*style:\s*TextStyle\(\s*color:\s*context\.colors\.', r'Text(\1, style: TextStyle(color: context.colors.', new_content)
                new_content = re.sub(r'const\s+BoxDecoration\(\s*gradient:\s*context\.colors\.', r'BoxDecoration(gradient: context.colors.', new_content)
                new_content = re.sub(r'const\s+BorderSide\(\s*color:\s*context\.colors\.', r'BorderSide(color: context.colors.', new_content)
                new_content = re.sub(r'const\s+CircularProgressIndicator\(\s*color:\s*context\.colors\.', r'CircularProgressIndicator(color: context.colors.', new_content)

                with open(filepath, 'w', encoding='utf-8') as file:
                    file.write(new_content)
print("Done")
