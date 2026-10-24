import re
path = r"D:\gpssalestraker3\app\lib\screens\profile_screen.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

import_main = "import '../main.dart';\nimport 'package:shared_preferences/shared_preferences.dart';\n"
text = re.sub(r"(import '../services/auth_service.dart';)", import_main + r"\1", text)

toggle_code = """
                const SizedBox(height: 12),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeNotifier,
                  builder: (context, currentMode, _) {
                    return SwitchListTile(
                      title: Text('Dark Mode', style: TextStyle(color: context.colors.cream)),
                      value: currentMode == ThemeMode.dark,
                      activeColor: context.colors.gold,
                      onChanged: (val) async {
                        themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('darkMode', val);
                      },
                    );
                  }
                ),
"""

text = text.replace("const SizedBox(height: 24),", toggle_code)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")