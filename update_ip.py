import re
path = r"D:\gpssalestraker3\app\lib\services\api_client.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

new_base_url = "return 'http://192.168.1.122:8080/api/v1';"
text = re.sub(r"return Platform\.isAndroid \? '[^']+' : '[^']+';", new_base_url, text)
text = re.sub(r"return 'http://10\.0\.2\.2[^']*';", new_base_url, text)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Updated IP")