# macOS Web Distribution (Non-App-Store)

Use the DMG packager to create a drag-to-Applications installer:

```bash
./scripts/package-macos-dmg.sh
```

Output:

- `dist/TimeTracker-macOS.dmg`

The generated DMG contains:

- `TimeTracker.app`
- `Applications` shortcut

Users open the DMG and drag `TimeTracker.app` into `Applications`.
