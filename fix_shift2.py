import re
path = r"D:\gpssalestraker3\app\lib\screens\shift_detail_screen.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

text = re.sub(r"_row\(\s*'End'", r"_row(context, 'End'", text)
text = text.replace("const SliverGridDelegateWithFixedCrossAxisCount(", "SliverGridDelegateWithFixedCrossAxisCount(")
text = text.replace("const Icon(Icons.location_on", "Icon(Icons.location_on")
text = text.replace("const Icon(icon", "Icon(icon")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)

path = r"D:\gpssalestraker3\app\lib\screens\map_screen.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()
text = text.replace("const Icon(Icons.my_location", "Icon(Icons.my_location")
text = text.replace("const Icon(icon", "Icon(icon")
with open(path, "w", encoding="utf-8") as f:
    f.write(text)

path = r"D:\gpssalestraker3\app\lib\screens\performance_screen.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()
text = text.replace("const SliverGridDelegateWithFixedCrossAxisCount(", "SliverGridDelegateWithFixedCrossAxisCount(")
with open(path, "w", encoding="utf-8") as f:
    f.write(text)

path = r"D:\gpssalestraker3\app\lib\screens\shifts_screen.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()
text = text.replace("const SliverGridDelegateWithFixedCrossAxisCount(", "SliverGridDelegateWithFixedCrossAxisCount(")
with open(path, "w", encoding="utf-8") as f:
    f.write(text)
