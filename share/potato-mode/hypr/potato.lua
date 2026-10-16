-- potato-mode: loaded from ~/.config/hypr/hyprland.lua after Omarchy's defaults.
-- Same switches as Omarchy's own default/hypr/toggles/no-animations.lua, plus more.
hl.config({
  animations = { enabled = false },
  decoration = {
    blur = { enabled = false },
    shadow = { enabled = false },
    rounding = 0,
    active_opacity = 1.0,
    inactive_opacity = 1.0,
  },
  general = { gaps_in = 0, gaps_out = 0, border_size = 1 },
  misc = { vfr = true, disable_hyprland_logo = true, disable_splash_rendering = true },
})

-- Web apps: Omarchy's launcher only supports Chromium-family browsers, so rebind
-- the stock web app keys to Firefox tabs. UNTESTED: assumes o.bind replaces an
-- existing binding for the same keys.
if o and o.bind then
  local w = "omarchy-potato-webapp "
  o.bind("SUPER + SHIFT + A", "ChatGPT", w .. "https://chatgpt.com")
  o.bind("SUPER + SHIFT + C", "Calendar", w .. "https://app.hey.com/calendar/weeks/")
  o.bind("SUPER + SHIFT + E", "Email", w .. "https://app.hey.com")
  o.bind("SUPER + SHIFT + Y", "YouTube", w .. "https://youtube.com/")
  o.bind("SUPER + SHIFT + ALT + G", "WhatsApp", w .. "https://web.whatsapp.com/")
  o.bind("SUPER + SHIFT + X", "X", w .. "https://x.com/")
  o.bind("SUPER + SHIFT + O", "Notes", "foot -e nvim " .. os.getenv("HOME") .. "/notes")
end
