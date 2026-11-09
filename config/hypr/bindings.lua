-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Home-row window navigation (h/j/k/l: left/down/up/right).
-- Reserve Shift for swapping windows and Shift+Alt for moving workspaces.
hl.unbind("SUPER + J") -- Was: toggle window split.
hl.unbind("SUPER + K") -- Was: keybindings menu.
hl.unbind("SUPER + L") -- Was: toggle workspace layout.

o.bind("SUPER + H", "Focus window left", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + J", "Focus window below", hl.dsp.focus({ direction = "d" }))
o.bind("SUPER + K", "Focus window above", hl.dsp.focus({ direction = "u" }))
o.bind("SUPER + L", "Focus window right", hl.dsp.focus({ direction = "r" }))

hl.unbind("SUPER + SHIFT + J") -- Was: toggle window split in the personal config.
hl.unbind("SUPER + SHIFT + K") -- Was: keybindings menu in the personal config.
hl.unbind("SUPER + SHIFT + L") -- Was: toggle workspace layout in the personal config.

o.bind("SUPER + SHIFT + H", "Swap window to the left", hl.dsp.window.swap({ direction = "l" }))
o.bind("SUPER + SHIFT + J", "Swap window down", hl.dsp.window.swap({ direction = "d" }))
o.bind("SUPER + SHIFT + K", "Swap window up", hl.dsp.window.swap({ direction = "u" }))
o.bind("SUPER + SHIFT + L", "Swap window to the right", hl.dsp.window.swap({ direction = "r" }))

o.bind("SUPER + SHIFT + ALT + H", "Move workspace to left monitor", hl.dsp.workspace.move({ monitor = "l" }))
o.bind("SUPER + SHIFT + ALT + J", "Move workspace to down monitor", hl.dsp.workspace.move({ monitor = "d" }))
o.bind("SUPER + SHIFT + ALT + K", "Move workspace to up monitor", hl.dsp.workspace.move({ monitor = "u" }))
o.bind("SUPER + SHIFT + ALT + L", "Move workspace to right monitor", hl.dsp.workspace.move({ monitor = "r" }))

-- Keep the displaced utility actions on their original letters with Alt.
hl.unbind("SUPER + ALT + K") -- Was: tmux keybindings menu.
o.bind("SUPER + ALT + J", "Toggle window split", hl.dsp.layout("togglesplit"))
o.bind("SUPER + ALT + K", "Keybindings", "omarchy-menu-keybindings")
o.bind("SUPER + ALT + L", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")

-- Global playback control and power menu.
hl.unbind("SUPER + CTRL + P") -- Was: power menu.
hl.unbind("SUPER + ALT + P") -- Was: play/pause in the personal config.
o.bind("SUPER + CTRL + P", "Play/Pause media", "omarchy-shell media playPause")
o.bind("SUPER + ALT + P", "Power", "omarchy-shell shell toggle omarchy.power")
