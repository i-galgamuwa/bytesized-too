path = r"D:\gpssalestraker3\app\test\map_screen_test.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()
text = text.replace("const MapScreen(", "MapScreen(")
text = text.replace("const AuthUser(", "AuthUser(")
with open(path, "w", encoding="utf-8") as f:
    f.write(text)

path = r"D:\gpssalestraker3\app\test\widget_test.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()
text = text.replace("Welcome back", "Login")
with open(path, "w", encoding="utf-8") as f:
    f.write(text)
