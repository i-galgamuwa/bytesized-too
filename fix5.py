import os
import re

# Fix app_colors.dart
path = r"D:\gpssalestraker3\app\lib\theme\app_colors.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()
text = text.replace("  AppColors({\n", "  const AppColors({\n")
with open(path, "w", encoding="utf-8") as f:
    f.write(text)

# Fix map_screen.dart:437 double to int? Actually, let's just make sure it's 12.0
path = r"D:\gpssalestraker3\app\lib\screens\map_screen.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()
# Let's search for integer parameters in flutter analyze
# lib/screens/map_screen.dart:437:34
# "radius:" or "strokeWidth:" something like that
text = re.sub(r'radius:\s*12([^.0-9])', r'radius: 12.0\1', text)
text = re.sub(r'radius:\s*8([^.0-9])', r'radius: 8.0\1', text)
with open(path, "w", encoding="utf-8") as f:
    f.write(text)

path = r"D:\gpssalestraker3\app\lib\screens\shift_detail_screen.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()
text = re.sub(r'radius:\s*12([^.0-9])', r'radius: 12.0\1', text)
text = re.sub(r'radius:\s*8([^.0-9])', r'radius: 8.0\1', text)
with open(path, "w", encoding="utf-8") as f:
    f.write(text)

# Fix tests
path = r"D:\gpssalestraker3\app\test\map_screen_test.dart"
if os.path.exists(path):
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    text = text.replace("const AppColors", "AppColors")
    text = text.replace("const GpsTrackerApp", "GpsTrackerApp")
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)

path = r"D:\gpssalestraker3\app\test\widget_test.dart"
if os.path.exists(path):
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    text = text.replace("const GpsTrackerApp", "GpsTrackerApp")
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)

print("Done")