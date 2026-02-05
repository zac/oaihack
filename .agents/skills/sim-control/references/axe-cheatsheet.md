# AXe Command Patterns

Use AXe for accessibility-driven UI automation and capture.

## Discover UI
```
axe describe-ui --udid <udid>
```
Use this to find `AXLabel` (accessibilityLabel) or `AXUniqueId` (accessibilityIdentifier) for elements.

## Tap
```
axe tap --label "Profile" --udid <udid>
axe tap --id "settings_button" --udid <udid>
axe tap -x 120 -y 540 --udid <udid>
```
Use `--pre-delay` or `--post-delay` if the UI needs time to settle.

## Type
```
axe type "hello@example.com" --udid <udid>
echo "Hello" | axe type --stdin --udid <udid>
axe type --file input.txt --udid <udid>
```
Note: only US keyboard characters are supported.

## Swipe
```
axe swipe --start-x 300 --start-y 700 --end-x 300 --end-y 200 --udid <udid>
```

## Buttons
```
axe button home --udid <udid>
axe button lock --duration 2.0 --udid <udid>
```

## Screenshots and Video
```
axe screenshot --udid <udid> --output ./sim-output/profile.png
axe record-video --udid <udid> --output ./sim-output/demo.mp4
```

## List Simulators
```
axe list-simulators
```
This returns UDID, device name, state, and iOS version.
