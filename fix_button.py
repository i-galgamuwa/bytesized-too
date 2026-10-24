import re
path = r"D:\gpssalestraker3\app\lib\widgets\cream_button.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace("backgroundColor: context.colors.cream,", "backgroundColor: context.colors.gold,")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")