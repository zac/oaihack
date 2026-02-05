# Swift Package Manager (SPM) Patterns

Add/remove Swift Package dependencies at the Xcode project level.

## Add a package product
```
python3 scripts/xcodeproj_edit_runner.py --project App.xcodeproj \
  add-spm --url https://github.com/kean/Nuke \
  --product Nuke --version 12.7.3 --target App
```

## Requirements
Exactly one requirement flag is required:
- `--version` (upToNextMajorVersion)
- `--exact`
- `--branch`
- `--revision`

## Remove a package product
```
python3 scripts/xcodeproj_edit_runner.py --project App.xcodeproj \
  remove-spm --product Nuke
```

If you pass `--url`, the package reference is removed when no remaining products use it.

## After changes
You may need to resolve packages:
```
xcodebuild -resolvePackageDependencies -project App.xcodeproj -scheme <Scheme>
```
