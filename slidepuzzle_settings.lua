--[[
    slidepuzzle_settings.lua
    Builds the "Settings" sub-menu and exposes simple getters for the
    runtime values (font face, font size, language). The plugin owns
    the LuaSettings instance and is the source of truth; this module is
    only a thin layer that makes the menu and helpers reusable.
--]]

local ConfirmBox = require("ui/widget/confirmbox")
local Device = require("device")
local InfoMessage = require("ui/widget/infomessage")
local SpinWidget = require("ui/widget/spinwidget")
local UIManager = require("ui/uimanager")
local ffiUtil = require("ffi/util")
local T = ffiUtil.template

local I18n = require("slidepuzzle_i18n")

local Settings = {}

-- Font choices the user can pick from.
--
-- The first "default" entry intentionally carries no explicit face so
-- the board falls back to KOReader's default UI font ("cfont"), which
-- in turn respects any custom system font the user has configured.
--
-- The remaining entries use bundled KOReader font files so the plugin
-- works on every device without depending on user-installed fonts.
-- `face_name` is what we hand to Font:getFace() (KOReader resolves it
-- both as a fontmap key and as a literal file path).
--
-- A `label` is a raw display name (not translated). An `i18n_key`
-- optionally replaces `label` with a translated string.
Settings.FONTS = {
    { id = "default",     i18n_key = "Default",        face_name = nil },
    { id = "sans",        label = "Sans (Noto)",       face_name = "NotoSans-Regular.ttf" },
    { id = "sans_bold",   label = "Sans Bold (Noto)",  face_name = "NotoSans-Bold.ttf" },
    { id = "serif",       label = "Serif (FreeSerif)", face_name = "freefont/FreeSerif.ttf" },
    { id = "free_sans",   label = "FreeSans",          face_name = "freefont/FreeSans.ttf" },
    { id = "mono",        label = "Monospace (Droid)", face_name = "DroidSansMono.ttf" },
}

-- Resolve the display label for a FONTS entry, honouring the i18n key
-- when present (so "Default" follows the active language).
local function fontLabel(font_def)
    if font_def.i18n_key then
        return I18n.t(font_def.i18n_key)
    end
    return font_def.label
end

-- The font size value used to mean "auto-pick from cell size".
Settings.AUTO_FONT_SIZE = 0

Settings.FONT_SIZE_MIN = 12
-- Generous upper bound so the spinner can always reach (and exceed) the
-- auto-computed size on every supported board / screen combo. The board
-- itself enforces its own per-cell clamp (cell * 0.78) at render time,
-- so picking a very large value here will never make digits overflow
-- the tile — they will simply be capped at the cell's own ceiling.
Settings.FONT_SIZE_MAX = 200

-- Mirrors the math used in slidepuzzle_screen.computeBoardMaxSize() and
-- slidepuzzle_board._computeMetrics() so the spin widget can pre-fill
-- the same pixel value the board would pick on its own. Kept here so
-- the user can tweak "around" the auto value instead of having to
-- guess what it currently is.
local MIN_CELL = 32
local AUTO_AVAILABLE_RATIO = 0.78
local AUTO_FONT_RATIO = 0.45

function Settings.computeAutoFontSize(plugin)
    local n = (plugin and plugin.active_size) or 3
    local screen = Device.screen
    local short = math.min(screen:getWidth(), screen:getHeight())
    local available = math.floor(short * AUTO_AVAILABLE_RATIO)
    local cell = math.floor(available / n)
    if cell < MIN_CELL then cell = MIN_CELL end
    local px = math.max(18, math.floor(cell * AUTO_FONT_RATIO))
    if px < Settings.FONT_SIZE_MIN then px = Settings.FONT_SIZE_MIN end
    if px > Settings.FONT_SIZE_MAX then px = Settings.FONT_SIZE_MAX end
    return px
end

local function findFontById(id)
    for _, f in ipairs(Settings.FONTS) do
        if f.id == id then return f end
    end
    return Settings.FONTS[1]
end

-- Return the configured font descriptor (entry from Settings.FONTS).
function Settings.getFont(plugin)
    local id = plugin.settings:readSetting("font_id") or Settings.FONTS[1].id
    return findFontById(id)
end

-- Return either the explicit font size or AUTO_FONT_SIZE (0) when the
-- caller should compute one from the cell size automatically.
function Settings.getFontSize(plugin)
    local size = tonumber(plugin.settings:readSetting("font_size")) or Settings.AUTO_FONT_SIZE
    if size < 0 then size = Settings.AUTO_FONT_SIZE end
    return size
end

-- Build the sub-menu. The plugin instance is captured so callbacks can
-- read/write settings and refresh whatever UI is currently visible.
function Settings.buildSubMenu(plugin)
    local function refreshTouchMenu(touchmenu_instance)
        if touchmenu_instance and touchmenu_instance.updateItems then
            touchmenu_instance:updateItems()
        end
    end

    local items = {}

    -- Always start a new puzzle on open ------------------------------------
    items[#items + 1] = {
        text_func = function()
            return I18n.t("Always start a new puzzle on open")
        end,
        checked_func = function()
            return plugin.settings:isTrue("always_new_on_open")
        end,
        callback = function()
            plugin.settings:toggle("always_new_on_open")
            plugin.settings:flush()
        end,
        keep_menu_open = true,
    }

    -- Font ------------------------------------------------------------------
    local function fontRadioItem(font_def)
        return {
            text_func = function() return fontLabel(font_def) end,
            radio = true,
            checked_func = function()
                return Settings.getFont(plugin).id == font_def.id
            end,
            callback = function()
                plugin.settings:saveSetting("font_id", font_def.id)
                plugin.settings:flush()
                if plugin.onSettingsChanged then plugin:onSettingsChanged() end
            end,
        }
    end

    local font_sub_items = {}
    for _, f in ipairs(Settings.FONTS) do
        font_sub_items[#font_sub_items + 1] = fontRadioItem(f)
    end
    items[#items + 1] = {
        text_func = function()
            return T("%1: %2", I18n.t("Font"), fontLabel(Settings.getFont(plugin)))
        end,
        sub_item_table = font_sub_items,
        keep_menu_open = true,
    }

    -- Font size -------------------------------------------------------------
    items[#items + 1] = {
        text_func = function()
            local v = Settings.getFontSize(plugin)
            local value_text
            if v == Settings.AUTO_FONT_SIZE then
                value_text = I18n.t("Auto")
            else
                value_text = tostring(v)
            end
            return T(I18n.t("Font size: %1"), value_text)
        end,
        keep_menu_open = true,
        callback = function(touchmenu_instance)
            local current = Settings.getFontSize(plugin)
            local auto_px = Settings.computeAutoFontSize(plugin)
            local spin_value = current
            if spin_value == Settings.AUTO_FONT_SIZE then
                -- Seed the spinner with the actual auto-computed size
                -- so the user can adjust around it (instead of guessing
                -- what "default" currently means for this board).
                spin_value = auto_px
            end
            local spin = SpinWidget:new{
                title_text = I18n.t("Font size"),
                value = spin_value,
                value_min = Settings.FONT_SIZE_MIN,
                value_max = Settings.FONT_SIZE_MAX,
                value_step = 1,
                value_hold_step = 4,
                -- Pressing the "Default value" button puts the picker
                -- at the actual auto pixel size (instead of the bare
                -- "0" sentinel which used to render as "00"). The OK
                -- callback below maps an unchanged auto value back to
                -- the persistent AUTO sentinel.
                default_value = auto_px,
                default_text = I18n.t("Auto"),
                ok_text = I18n.t("OK"),
                callback = function(spin_widget)
                    local new_value = spin_widget.value or auto_px
                    if new_value < Settings.FONT_SIZE_MIN then
                        new_value = Settings.FONT_SIZE_MIN
                    end
                    -- If the user kept the auto pixel value, persist
                    -- it as the AUTO sentinel so future board-size /
                    -- screen-size changes keep auto-adapting.
                    if new_value == auto_px then
                        new_value = Settings.AUTO_FONT_SIZE
                    end
                    plugin.settings:saveSetting("font_size", new_value)
                    plugin.settings:flush()
                    if plugin.onSettingsChanged then plugin:onSettingsChanged() end
                    refreshTouchMenu(touchmenu_instance)
                end,
            }
            UIManager:show(spin)
        end,
    }

    -- Language --------------------------------------------------------------
    local lang_sub_items = {}
    for _, lang in ipairs(I18n.LANGS) do
        local code = lang.code
        local name = lang.name
        lang_sub_items[#lang_sub_items + 1] = {
            text_func = function()
                if code == "default" then
                    return I18n.t("Default")
                end
                return name
            end,
            radio = true,
            checked_func = function()
                return I18n.getChoice() == code
            end,
            callback = function()
                plugin.settings:saveSetting("language", code)
                plugin.settings:flush()
                I18n.setActive(code)
                if plugin.onSettingsChanged then plugin:onSettingsChanged() end
            end,
        }
    end
    items[#items + 1] = {
        text_func = function()
            local choice = I18n.getChoice()
            local label
            if choice == "default" then
                label = I18n.t("Default")
            else
                for _, lang in ipairs(I18n.LANGS) do
                    if lang.code == choice then
                        label = lang.name
                        break
                    end
                end
                label = label or choice
            end
            return T("%1: %2", I18n.t("Language"), label)
        end,
        sub_item_table = lang_sub_items,
        keep_menu_open = true,
        separator = true,
    }

    -- Reset best results ---------------------------------------------------
    -- Lives at the bottom of the Settings menu so the destructive action
    -- is visually grouped with the other preferences but kept out of the
    -- main menu's first level. Always asks for confirmation first.
    items[#items + 1] = {
        text_func = function() return I18n.t("Reset best results") end,
        keep_menu_open = true,
        callback = function()
            UIManager:show(ConfirmBox:new{
                text = I18n.t("Reset all best results?"),
                ok_text = I18n.t("Reset"),
                cancel_text = I18n.t("Cancel"),
                ok_callback = function()
                    plugin.stats = {}
                    plugin:_saveAll()
                    UIManager:show(InfoMessage:new{
                        text = I18n.t("Best results cleared."),
                        timeout = 2,
                    })
                end,
            })
        end,
    }

    return items
end

return Settings
