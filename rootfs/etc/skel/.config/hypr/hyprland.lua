-- Darkroot Shell - Hyprland configuration (Lua, Hyprland >= 0.57)
-- Colours come from ~/.config/hypr/theme.lua, written by `darkroot-theme`.

local home = os.getenv("HOME") or ""
local theme = {
    active   = { colors = { "rgba(a78bfaee)", "rgba(06b6d4ee)" }, angle = 45 },
    inactive = "rgba(ffffff14)",
    shadow   = "rgba(0000005a)",
}
do
    local ok, t = pcall(dofile, home .. "/.config/hypr/theme.lua")
    if ok and type(t) == "table" then
        for k, v in pairs(t) do theme[k] = v end
    end
end

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "WhiteSur-cursors")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("MOZ_ENABLE_WAYLAND", "1")

hl.on("hyprland.start", function()
    hl.exec_cmd("darkroot-session")
end)

hl.config({
    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = {
            natural_scroll = true,
            tap_to_click   = true,
        },
    },
    general = {
        gaps_in          = 6,
        gaps_out         = 12,
        border_size      = 2,
        layout           = "dwindle",
        resize_on_border = true,
        col = {
            active_border   = theme.active,
            inactive_border = theme.inactive,
        },
    },
    decoration = {
        rounding         = 14,
        active_opacity   = 1.0,
        inactive_opacity = 0.96,
        blur = {
            enabled  = true,
            size     = 8,
            passes   = 3,
            vibrancy = 0.2,
        },
        shadow = {
            enabled      = true,
            range        = 30,
            render_power = 3,
            color        = theme.shadow,
        },
    },
    animations = { enabled = true },
    dwindle = {
        preserve_split = true,
    },
    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
    },
})

hl.curve("mac",    { type = "bezier", points = { {0.25, 1},    {0.5, 1}     } })
hl.curve("spring", { type = "bezier", points = { {0.34, 1.56}, {0.64, 1}    } })
hl.animation({ leaf = "windows",    enabled = true, speed = 5, bezier = "spring", style = "popin 85%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "mac",    style = "popin 80%" })
hl.animation({ leaf = "border",     enabled = true, speed = 8, bezier = "mac" })
hl.animation({ leaf = "fade",       enabled = true, speed = 4, bezier = "mac" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "mac",    style = "slide" })
hl.animation({ leaf = "layers",     enabled = true, speed = 4, bezier = "mac",    style = "fade" })

-- keybindings ------------------------------------------------------------
local mod = "SUPER"
local function key(k) return mod .. " + " .. k end

hl.bind(key("Return"), hl.dsp.exec_cmd("foot"))
hl.bind(key("Space"),  hl.dsp.exec_cmd("pkill wofi || wofi --show drun"))
hl.bind(key("Q"),      hl.dsp.window.close())
hl.bind(key("E"),      hl.dsp.exec_cmd("thunar"))
hl.bind(key("B"),      hl.dsp.exec_cmd("firefox-bin"))
hl.bind(key("C"),      hl.dsp.exec_cmd("code"))
hl.bind(key("F"),      hl.dsp.window.fullscreen())
hl.bind(key("V"),      hl.dsp.window.float({ action = "toggle" }))
hl.bind(key("P"),      hl.dsp.window.pseudo())
hl.bind(key("J"),      hl.dsp.layout("togglesplit"))
hl.bind(key("L"),      hl.dsp.exec_cmd("hyprlock"))
hl.bind(key("T"),      hl.dsp.exec_cmd("darkroot-theme toggle"))
hl.bind(key("SHIFT + M"), hl.dsp.exit())
hl.bind(key("SHIFT + S"), hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))
hl.bind("Print", hl.dsp.exec_cmd("grim ~/Pictures/screenshot-$(date +%F-%H%M%S).png"))

for _, d in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(key(d),              hl.dsp.focus({ direction = d }))
    hl.bind(key("SHIFT + " .. d), hl.dsp.window.move({ direction = d }))
end

for i = 1, 9 do
    hl.bind(key(tostring(i)),              hl.dsp.focus({ workspace = i }))
    hl.bind(key("SHIFT + " .. tostring(i)), hl.dsp.window.move({ workspace = i }))
end

hl.bind(key("mouse_down"), hl.dsp.focus({ workspace = "e+1" }))
hl.bind(key("mouse_up"),   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(key("mouse:272"),  hl.dsp.window.drag(),   { mouse = true })
hl.bind(key("mouse:273"),  hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
