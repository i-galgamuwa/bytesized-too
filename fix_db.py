import re
path = r"D:\gpssalestraker3\app\lib\database_helper.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace(r"final path = '\${documentsDirectory.path}/\$_databaseName';", r"final path = '${documentsDirectory.path}/$_databaseName';")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")