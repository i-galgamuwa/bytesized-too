import re
path = r"D:\gpssalestraker3\app\android\gradle\wrapper\gradle-wrapper.properties"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()
text = text.replace("gradle-8.7-all.zip", "gradle-9.1-all.zip")
with open(path, "w", encoding="utf-8") as f:
    f.write(text)

path = r"D:\gpssalestraker3\app\android\settings.gradle.kts"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()
text = re.sub(r'version "8\.7\.0"', 'version "8.7.0"', text)
with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")