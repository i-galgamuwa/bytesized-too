import re
path = r"D:\gpssalestraker3\app\android\settings.gradle.kts"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

text = re.sub(r'version "9\.1\.0"', 'version "8.3.2"', text)
text = re.sub(r'version "2\.4\.0"', 'version "1.9.22"', text)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")