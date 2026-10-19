"""Finder layout; consumed by dmgbuild, never by the application worker."""

import os

staging = os.environ["TANGERINE_DMG_STAGING"]
files = [os.path.join(staging, "Tangerine.app")]
symlinks = {"Applications": "/Applications"}
background = os.path.join(staging, "installer.tiff")
icon = "Resources/AppIcon.icns"
format = "ULMO"
filesystem = "HFS+"
window_rect = ((180, 180), (700, 470))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
icon_size = 88
text_size = 13
grid_spacing = 80
icon_locations = {
    "Tangerine.app": (145, 228),
    "Applications": (420, 228),
}
