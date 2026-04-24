--[[
    slidepuzzle.koplugin/main.lua
    Plugin entry point: registers the menu item, owns per-size
    persistence (current state, best results) and hands out Game
    instances to the screen.
--]]

local ConfirmBox  = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local InfoMessage = require("ui/widget/infomessage")
local LuaSettings = require("luasettings")
local UIManager   = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local i18n = require("i18n")
local Game = require("slidepuzzle_game")
local Screen = require("slidepuzzle_screen")

local SlidePuzzle = WidgetContainer:extend{
    name = "slidepuzzle",
    is_doc_only = false,
}

-- Init --------------------------------------------------------------------

function SlidePuzzle:init()
    self.settings_file = DataStorage:getSettingsDir() .. "/slidepuzzle.lua"
    self.settings = LuaSettings:open(self.settings_file)

    -- Language must be loaded before any translated string is used.
    i18n.load(self.settings)

    self.active_size = tonumber(self.settings:readSetting("active_size")) or Game.getMinSize()
    if self.active_size < Game.getMinSize() or self.active_size > Game.getMaxSize() then
        self.active_size = Game.getMinSize()
    end
    self.states = self.settings:readSetting("states") or {}
    self.stats  = self.settings:readSetting("stats")  or {}

    self.ui.menu:registerToMainMenu(self)
end

function SlidePuzzle:onSuspend()
    if self.screen then
        self.screen:onClose()
    end
end

-- Menu --------------------------------------------------------------------

function SlidePuzzle:addToMainMenu(menu_items)
    menu_items.slidepuzzle = {
        text = i18n.t("menu_title"),
        sorting_hint = "tools",
        sub_item_table = {
            {
                text = i18n.t("play"),
                keep_menu_open = false,
                callback = function() self:showGame() end,
            },
            {
                -- Toggle: always-new vs. resume
                text_func = function()
                    if self.settings:isTrue("always_new_on_open") then
                        return i18n.t("always_new")
                    end
                    return i18n.t("resume")
                end,
                checked_func = function()
                    return self.settings:isTrue("always_new_on_open")
                end,
                callback = function()
                    self.settings:toggle("always_new_on_open")
                    self.settings:flush()
                end,
                keep_menu_open = true,
            },
            {
                -- Reset with confirmation dialog
                text = i18n.t("reset"),
                keep_menu_open = true,
                callback = function()
                    UIManager:show(ConfirmBox:new{
                        text        = i18n.t("reset_confirm"),
                        ok_text     = i18n.t("confirm"),
                        cancel_text = i18n.t("cancel"),
                        ok_callback = function()
                            self.stats = {}
                            self:_saveAll()
                            UIManager:show(InfoMessage:new{
                                text    = i18n.t("reset_done"),
                                timeout = 2,
                            })
                        end,
                    })
                end,
            },
            {
                -- Language selector
                text_func = function()
                    return i18n.t("language") .. ": " .. i18n.current:upper()
                end,
                keep_menu_open = true,
                callback = function()
                    self:showLanguageDialog()
                end,
            },
        },
    }
end

-- Language dialog ---------------------------------------------------------

function SlidePuzzle:showLanguageDialog()
    local ButtonDialog = require("ui/widget/buttondialog")
    local Blitbuffer   = require("ffi/blitbuffer")

    local dialog
    local buttons = {}

    for _, entry in ipairs(i18n.AVAILABLE) do
        local code  = entry.code
        local label = entry.label
        buttons[#buttons + 1] = {
            {
                text = label,
                -- Highlight the currently active language.
                background = (code == i18n.current)
                    and Blitbuffer.COLOR_GRAY_E
                    or  Blitbuffer.COLOR_WHITE,
                callback = function()
                    UIManager:close(dialog)
                    if code ~= i18n.current then
                        i18n.set(code, self.settings)
                        -- Language is persisted immediately. Menu text_func
                        -- entries will reflect the new language the next time
                        -- the menu is opened; just ask the user to reopen it.
                        UIManager:show(InfoMessage:new{
                            text    = i18n.t("language_changed"),
                            timeout = 3,
                        })
                    end
                end,
            },
        }
    end

    buttons[#buttons + 1] = {
        {
            text = i18n.t("cancel"),
            background = Blitbuffer.COLOR_WHITE,
            callback = function() UIManager:close(dialog) end,
        },
    }

    dialog = ButtonDialog:new{
        title   = i18n.t("select_language"),
        buttons = buttons,
    }
    UIManager:show(dialog)
end

-- Persistence helpers -----------------------------------------------------

function SlidePuzzle:_saveAll()
    self.settings:saveSetting("active_size", self.active_size)
    self.settings:saveSetting("states",      self.states)
    self.settings:saveSetting("stats",       self.stats)
    self.settings:flush()
end

function SlidePuzzle:_key(size)
    return tostring(size)
end

function SlidePuzzle:_loadOrCreateGame(size)
    local data = self.states[self:_key(size)]
    local game
    if data then
        game = Game.deserialize(data, size)
    else
        game = Game:new(size)
        game:shuffle()
    end
    -- Never hand out a game that is already solved or still in the raw
    -- solved initial state; start a fresh puzzle instead.
    if game:isWon() or (not game:hasStarted() and game:checkSolved()) then
        game:shuffle()
    end
    self.states[self:_key(size)] = game:serialize()
    return game
end

-- API used by the Screen --------------------------------------------------

function SlidePuzzle:getCurrentGame()
    if not self._cached_game or self._cached_game:getSize() ~= self.active_size then
        self._cached_game = self:_loadOrCreateGame(self.active_size)
    end
    return self._cached_game
end

function SlidePuzzle:setActiveSize(size)
    size = tonumber(size) or Game.getMinSize()
    if size < Game.getMinSize() then size = Game.getMinSize() end
    if size > Game.getMaxSize() then size = Game.getMaxSize() end
    self.active_size  = size
    self._cached_game = nil
    self:_saveAll()
end

function SlidePuzzle:startNewGame(size)
    size = tonumber(size) or self.active_size
    local game = Game:new(size)
    game:shuffle()
    self._cached_game = game
    self.active_size  = size
    self.states[self:_key(size)] = game:serialize()
    self:_saveAll()
end

function SlidePuzzle:saveCurrentState(game)
    if not game then return end
    self.states[self:_key(game:getSize())] = game:serialize()
    self:_saveAll()
end

function SlidePuzzle:recordResult(game)
    if not game then return end
    local key     = self:_key(game:getSize())
    local s       = self.stats[key] or {}
    local elapsed = game:getElapsed()
    local moves   = game:getMoves()
    if elapsed > 0 and (not s.best_time  or elapsed < s.best_time)  then s.best_time  = elapsed end
    if moves   > 0 and (not s.best_moves or moves   < s.best_moves) then s.best_moves = moves   end
    s.last_time  = elapsed
    s.last_moves = moves
    s.plays      = (s.plays or 0) + 1
    self.stats[key] = s
    self:_saveAll()
end

function SlidePuzzle:getStats(size)
    return self.stats[self:_key(size)]
end

-- Screen lifecycle --------------------------------------------------------

function SlidePuzzle:showGame()
    if self.screen then return end
    if self.settings:isTrue("always_new_on_open") then
        self:startNewGame(self.active_size)
    end
    local game = self:getCurrentGame()
    self.screen = Screen:new{
        plugin = self,
        game   = game,
    }
    UIManager:show(self.screen)
end

function SlidePuzzle:onScreenClosed()
    self.screen = nil
end

return SlidePuzzle
