# simctl Command Patterns

Use simctl to boot, install, and launch apps on the simulator.

## Boot and Shutdown
```
xcrun simctl boot <udid>
xcrun simctl bootstatus <udid> -b
xcrun simctl shutdown <udid>
```

## Install, Launch, Terminate
```
xcrun simctl install <udid> /path/to/App.app
xcrun simctl launch <udid> <bundle-id>
xcrun simctl terminate <udid> <bundle-id>
```

## Open URL
```
xcrun simctl openurl <udid> https://example.com
```

## Find an .app in DerivedData
Look for `DerivedData/Build/Products/Debug-iphonesimulator/<App>.app` or similar.
