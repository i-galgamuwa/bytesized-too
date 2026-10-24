path = r"D:\gpssalestraker3\app\lib\services\api_client.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace(
    "return 'https://localhost:8080/api/v1'; // Replace with real production url if needed.",
    "return Platform.isAndroid ? 'http://10.0.2.2:8080/api/v1' : 'http://localhost:8080/api/v1';"
)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")