path = r"D:\gpssalestraker3\app\test\map_screen_test.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()
text = text.replace("const MaterialApp(", "MaterialApp(")
text = text.replace("home: MapScreen(", "home: const MapScreen(")
with open(path, "w", encoding="utf-8") as f:
    f.write(text)
