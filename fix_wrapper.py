path = r"D:\gpssalestraker3\app\android\gradle\wrapper\gradle-wrapper.properties"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace("gradle-9.3.1-all.zip", "gradle-8.4-all.zip")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")