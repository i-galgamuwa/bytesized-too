import os
import re

path = r"D:\gpssalestraker3\app\lib\screens\shift_detail_screen.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Replace AppColors
text = re.sub(r'AppColors\.', 'context.colors.', text)
text = text.replace('const CircularProgressIndicator(', 'CircularProgressIndicator(')
text = text.replace('const TextStyle(', 'TextStyle(')
text = text.replace('const Text(', 'Text(')

# Update _row arguments to pass context
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