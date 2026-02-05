# xcodeproj Edit Patterns

This skill edits .xcodeproj files using the `xcodeproj` Ruby gem via `scripts/xcodeproj_edit_runner.py`.

## Add files to groups and targets
```
python3 scripts/xcodeproj_edit_runner.py --project App.xcodeproj \
  add-files --group "App/Models" --target App \
  App/Models/NewModel.swift
```

## Remove files
```
python3 scripts/xcodeproj_edit_runner.py --project App.xcodeproj \
  remove-files App/Models/OldModel.swift
```

## Add/remove groups
```
python3 scripts/xcodeproj_edit_runner.py --project App.xcodeproj \
  add-group --group "App/New Feature"

python3 scripts/xcodeproj_edit_runner.py --project App.xcodeproj \
  remove-group --group "App/Deprecated" --recursive
```

## Target membership
- Use `--target` (repeatable) to control which targets receive new files or SPM products.
- If no target is provided, the script defaults to application targets.
