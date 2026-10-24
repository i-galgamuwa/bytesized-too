import re

path = r"D:\gpssalestraker3\app\lib\widgets\main_shell.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace("Widget _item(IconData icon, String label, int index)", "Widget _item(BuildContext context, IconData icon, String label, int index)")
text = text.replace("_item(Icons.home_outlined", "_item(context, Icons.home_outlined")
text = text.replace("_item(Icons.bar_chart_rounded", "_item(context, Icons.bar_chart_rounded")
text = text.replace("_item(Icons.schedule", "_item(context, Icons.schedule")
text = text.replace("_item(Icons.person_outline", "_item(context, Icons.person_outline")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)

path = r"D:\gpssalestraker3\app\lib\screens\shift_detail_screen.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace("Widget _row(String label, String value)", "Widget _row(BuildContext context, String label, String value)")
text = text.replace("_row('Date'", "_row(context, 'Date'")
text = text.replace("_row('Start'", "_row(context, 'Start'")
text = text.replace("_row(\n                'End'", "_row(\n                context,\n                'End'")
text = text.replace("_row('Duration'", "_row(context, 'Duration'")
text = text.replace("_row('Distance'", "_row(context, 'Distance'")
text = text.replace("_row('Driver ID'", "_row(context, 'Driver ID'")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")