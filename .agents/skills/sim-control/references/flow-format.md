# Flow File Format

A flow is a JSON array of step objects. Each step has an `action` and action-specific fields.

## Supported Actions
- `tap`: `{ "action": "tap", "label": "Profile" }` or `{ "action": "tap", "id": "settings_button" }` or `{ "action": "tap", "x": 120, "y": 540 }`
- `type`: `{ "action": "type", "text": "hello@example.com" }`
- `swipe`: `{ "action": "swipe", "start_x": 300, "start_y": 700, "end_x": 300, "end_y": 200 }`
- `button`: `{ "action": "button", "button": "home" }`
- `openurl`: `{ "action": "openurl", "url": "https://example.com" }`
- `describe-ui`: `{ "action": "describe-ui" }`
- `screenshot`: `{ "action": "screenshot", "name": "profile" }`
- `wait`: `{ "action": "wait", "seconds": 1.0 }`

## Example
```
[
  { "action": "tap", "label": "Profile" },
  { "action": "tap", "label": "Settings", "post_delay": 1.0 },
  { "action": "screenshot", "name": "settings" }
]
```

Screenshots default to `--output-dir` with a timestamped filename.
