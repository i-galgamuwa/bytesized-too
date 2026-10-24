import os
import re

lib_dir = r"D:\gpssalestraker3\app"

path = os.path.join(lib_dir, "lib", "screens", "map_screen.dart")
with open(path, "r", encoding="utf-8") as f:
    text = f.read()
text = text.replace("strokeWidth: LiveMapConfig.routeGlowWidth,", "strokeWidth: LiveMapConfig.routeGlowWidth.toDouble(),")
with open(path, "w", encoding="utf-8") as f:
    f.write(text)

path = os.path.join(lib_dir, "lib", "screens", "shift_detail_screen.dart")
with open(path, "r", encoding="utf-8") as f:
    text = f.read()
text = text.replace("strokeWidth: LiveMapConfig.routeGlowWidth,", "strokeWidth: LiveMapConfig.routeGlowWidth.toDouble(),")
with open(path, "w", encoding="utf-8") as f:
    f.write(text)

# tests
test_dir = os.path.join(lib_dir, "test")
for root, dirs, files in os.walk(test_dir):
    for f in files:
        if f.endswith('.dart'):
            filepath = os.path.join(root, f)
            with open(filepath, 'r', encoding='utf-8') as file:
                content = file.read()
            # remove const
            content = content.replace("const AppColors(", "AppColors(")
            content = content.replace("const GpsTrackerApp(", "GpsTrackerApp(")
            with open(filepath, 'w', encoding='utf-8') as file:
                file.write(content)

print("Done")