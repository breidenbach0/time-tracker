# dmgbuild layout for TimeTracker.dmg: a light window with the app on the left, Applications on the
# right and an arrow between them (scripts/dmg/background.tiff, from make-background.swift). Used by scripts/package-macos-dmg.sh:
#   dmgbuild -s scripts/dmg/settings.py -D app=<TimeTracker.app> -D background=<background.tiff> \
#     "TimeTracker" dist/TimeTracker.dmg
import os.path

app = defines["app"]
app_name = os.path.basename(app)

format = "UDZO"
files = [app]
symlinks = {"Applications": "/Applications"}
hide_extensions = [app_name]

icon = os.path.join(app, "Contents", "Resources", "AppIcon.icns")
if not os.path.exists(icon):
    icon = None

background = defines["background"]
window_rect = ((200, 120), (660, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
icon_size = 128
text_size = 13
icon_locations = {
    app_name: (170, 190),
    "Applications": (490, 190),
}
