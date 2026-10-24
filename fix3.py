import re
import os

lib_dir = r"D:\gpssalestraker3\app\lib"

# map_screen 244, 559
# performance_screen 67
# shift_detail 41, 44, 185
# shifts_screen 81

content = ""
path = os.path.join(lib_dir, "screens", "map_screen.dart")
with open(path, "r", encoding="utf-8") as f:
    content = f.read()
content = content.replace("const InputDecoration(", "InputDecoration(")
content = content.replace("const RoundedRectangleBorder(", "RoundedRectangleBorder(")
with open(path, "w", encoding="utf-8") as f:
    f.write(content)

path = os.path.join(lib_dir, "screens", "performance_screen.dart")
with open(path, "r", encoding="utf-8") as f:
    content = f.read()
content = content.replace("const SliverGridDelegateWithFixedCrossAxisCount(", "SliverGridDelegateWithFixedCrossAxisCount(")
with open(path, "w", encoding="utf-8") as f:
    f.write(content)

path = os.path.join(lib_dir, "screens", "shifts_screen.dart")
with open(path, "r", encoding="utf-8") as f:
    content = f.read()
content = content.replace("const SliverGridDelegateWithFixedCrossAxisCount(", "SliverGridDelegateWithFixedCrossAxisCount(")
with open(path, "w", encoding="utf-8") as f:
    f.write(content)

path = os.path.join(lib_dir, "screens", "shift_detail_screen.dart")
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Fix the missing context in _row
# First revert whatever is there
content = re.sub(r"_row\([\s\S]*?'End'[\s\S]*?\),", "", content)
content = content.replace("_row(context, 'Start', timeFormat.format(shift.startTime)),", "_row(context, 'Start', timeFormat.format(shift.startTime)),\n            _row(context, 'End', shift.endTime == null ? 'In progress' : timeFormat.format(shift.endTime!)),")

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("Done")