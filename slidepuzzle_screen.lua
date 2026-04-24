--[[
    slidepuzzle_screen.lua
    Fullscreen game screen. Owns the timer ticker, builds the header and
    bottom button row, and forwards user input to the Game instance.
--]]

local Blitbuffer      = require("ffi/blitbuffer")
local ButtonDialog    = require("ui/widget/buttondialog")
local ButtonTable     = require("ui/widget/buttontable")
local Device          = require("device")
local Font            = require("ui/font")
local FrameContainer  = require("ui/widget/container/framecontainer")
local Geom            = require("ui/geometry")
local InfoMessage     = require("ui/widget/infomessage")
local InputContainer  = require("ui/widget/container/inputcontainer")
local Size            = require("ui/size")
local TextWidget      = require("ui/widget/textwidget")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")

local i18n       = require("i18n")
local BoardWidget = require("slidepuzzle_board")
local Game        = require("slidepuzzle_game")

local TICK_INTERVAL = 1

local Screen = InputContainer:extend{
    plugin = nil, -- owning plugin, provides persistence hooks
    game   = nil, -- current Game instance
}

-- Helpers -----------------------------------------------------------------

local function formatTime(total_seconds)
    local s = math.floor(total_seconds or 0)
    if s < 0 then s = 0 end
    local h   = math.floor(s / 3600)
    local m   = math.floor((s % 3600) / 60)
    local sec = s % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, sec)
    end
    return string.format("%02d:%02d", m, sec)
end

local function getDeviceShort()
    return math.min(Device.screen:getWidth(), Device.screen:getHeight())
end

-- Init --------------------------------------------------------------------

function Screen:init()
    local screen_dev = Device.screen
    self.dimen = Geom:new{ x = 0, y = 0, w = screen_dev:getWidth(), h = screen_dev:getHeight() }
    self.covers_fullscreen = true
    self.live_tick_accum   = 0     -- seconds ticked but not yet folded into game.elapsed
    self.tick_scheduled    = false

    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
    end

    self.header_text = TextWidget:new{
        face      = Font:getFace("smallinfofont"),
        text      = "",
        max_width = math.floor(self.dimen.w * 0.95),
    }
    self.best_text = TextWidget:new{
        face      = Font:getFace("smallinfofont"),
        text      = "",
        max_width = math.floor(self.dimen.w * 0.95),
    }
    self.message_text = TextWidget:new{
        face      = Font:getFace("smallinfofont"),
        text      = "",
        max_width = math.floor(self.dimen.w * 0.95),
    }
    self.board_widget = BoardWidget:new{
        game       = self.game,
        max_size   = self:computeBoardMaxSize(),
        font_offset = self.plugin.settings:readSetting("font_offset") or 0,
        onTileTap  = function(row, col)   self:performTap(row, col) end,
        onSwipeDir = function(direction)  self:performSwipe(direction) end,
    }

    self:buildLayout()
    self:updateHeader()
    self:updateBestLabel()
    self:updateMessage()
    self:startTicker()

    UIManager:setDirty(self, function()
        return "ui", self.dimen
    end)
end

function Screen:computeBoardMaxSize()
    -- Reserve roughly 25 % of the short edge for the header + button row.
    local short = getDeviceShort()
    return math.floor(short * 0.78)
end

function Screen:buildLayout()
    local board_frame = FrameContainer:new{
        padding    = Size.padding.default,
        margin     = 0,
        bordersize = 0,
        self.board_widget,
    }

    local button_table = ButtonTable:new{
        shrink_unneeded_width = true,
        width = math.floor(self.dimen.w * 0.95),
        buttons = {
            {
                {
                    text       = i18n.t("new"),
                    background = Blitbuffer.COLOR_WHITE,
                    callback   = function() self:onNewGame() end,
                },
                {
                    text       = i18n.t("size"),
                    background = Blitbuffer.COLOR_WHITE,
                    callback   = function() self:showSizeDialog() end,
                },
                {
                    text       = i18n.t("stats"),
                    background = Blitbuffer.COLOR_WHITE,
                    callback   = function() self:showStats() end,
                },
                {
                    text       = i18n.t("close"),
                    background = Blitbuffer.COLOR_WHITE,
                    callback   = function() self:onClose() end,
                },
            },
            {
                {
                    text       = i18n.t("decrease_font"),
                    background = Blitbuffer.COLOR_WHITE,
                    callback   = function() self:adjustFont(-2) end,
                },
                {
                    text       = i18n.t("increase_font"),
                    background = Blitbuffer.COLOR_WHITE,
                    callback   = function() self:adjustFont(2) end,
                },
            },
        },
    }

    self.layout = VerticalGroup:new{
        align = "center",
        VerticalSpan:new{ width = Size.span.vertical_default },
        self.header_text,
        VerticalSpan:new{ width = Size.span.vertical_small },
        self.best_text,
        VerticalSpan:new{ width = Size.span.vertical_default },
        board_frame,
        VerticalSpan:new{ width = Size.span.vertical_small },
        self.message_text,
        VerticalSpan:new{ width = Size.span.vertical_small },
        button_table,
        VerticalSpan:new{ width = Size.span.vertical_small },
    }

    self[1] = self.layout
end

-- Header / status ---------------------------------------------------------

function Screen:updateHeader()
    local n    = self.game:getSize()
    local live = self.game:getElapsed() + self.live_tick_accum
    self.header_text:setText(i18n.t("header", n, self.game:getMoves(), formatTime(live)))
end

function Screen:updateBestLabel()
    local stats = self.plugin:getStats(self.game:getSize())
    if stats and (stats.best_time or stats.best_moves) then
        local time_s  = stats.best_time  and formatTime(stats.best_time)    or "--:--"
        local moves_s = stats.best_moves and tostring(stats.best_moves)     or "--"
        self.best_text:setText(i18n.t("best_label", time_s, moves_s))
    else
        self.best_text:setText(i18n.t("best_not_set"))
    end
end

function Screen:getDefaultMessage()
    if self.game:isWon() then
        return i18n.t("solved_play_again")
    end
    if self.game:getMoves() == 0 then
        return i18n.t("instruction")
    end
    return ""
end

function Screen:updateMessage(text)
    self.message_text:setText(text or self:getDefaultMessage())
end

-- Timer -------------------------------------------------------------------

function Screen:startTicker()
    if self.tick_scheduled then return end
    self.tick_scheduled = true
    self.last_tick_time = os.time()
    self:_scheduleTick()
end

function Screen:_scheduleTick()
    UIManager:scheduleIn(TICK_INTERVAL, self.tick_handler or self:_makeTickHandler())
end

function Screen:_makeTickHandler()
    if not self.tick_handler then
        self.tick_handler = function()
            self:_onTick()
        end
    end
    return self.tick_handler
end

function Screen:_onTick()
    if not self.tick_scheduled then return end
    local now   = os.time()
    local delta = now - (self.last_tick_time or now)
    self.last_tick_time = now
    if delta < 0 then delta = 0 end

    if self.game:hasStarted() and not self.game:isWon() then
        self.live_tick_accum = self.live_tick_accum + delta
        self:updateHeader()
        local rect = (self.header_text and self.header_text.dimen) or self.dimen
        UIManager:setDirty(self, function()
            return "ui", rect
        end)
    end

    -- Always reschedule while the screen is open.
    self:_scheduleTick()
end

function Screen:stopTicker()
    if not self.tick_scheduled then return end
    self.tick_scheduled = false
    if self.tick_handler then
        UIManager:unschedule(self.tick_handler)
    end
    -- Fold accumulated live ticks into the saved elapsed counter.
    if self.live_tick_accum > 0 then
        self.game:addElapsed(self.live_tick_accum)
    end
    self.live_tick_accum = 0
    self.last_tick_time  = nil
end

-- Input handling ----------------------------------------------------------

function Screen:performTap(row, col)
    if self.game:isWon() then
        -- Tapping anywhere on a solved puzzle starts a fresh game of the
        -- same size, matching the feel of quick puzzle apps.
        self:onNewGame()
        return
    end
    local ok = self.game:moveTileAt(row, col)
    if ok then
        self:afterMove()
    else
        self:updateMessage(i18n.t("invalid_move"))
    end
end

function Screen:performSwipe(direction)
    if self.game:isWon() then return end
    local ok = self.game:slide(direction)
    if ok then self:afterMove() end
end

function Screen:afterMove()
    self:updateHeader()

    if self.game:isWon() then
        self:updateMessage(i18n.t("solved_message",
            self.game:getMoves(),
            formatTime(self.game:getElapsed() + self.live_tick_accum)))
    else
        self:updateMessage()
    end

    UIManager:setDirty(self, function()
        return "ui", self.dimen
    end)

    if self.game:isWon() then
        UIManager:forceRePaint()
        self:stopTicker()
        self.plugin:recordResult(self.game)
        self:updateBestLabel()
        UIManager:show(InfoMessage:new{
            text = i18n.t("solved_overlay",
                self.game:getSize(),
                self.game:getMoves(),
                formatTime(self.game:getElapsed())),
            timeout = 4,
        })
    end

    self.plugin:saveCurrentState(self.game)
end

-- Buttons -----------------------------------------------------------------

function Screen:onNewGame()
    self.plugin:startNewGame(self.game:getSize())
    self.game = self.plugin:getCurrentGame()
    self.board_widget:setGame(self.game)
    self.live_tick_accum = 0
    self:updateHeader()
    self:updateBestLabel()
    self:updateMessage(i18n.t("new_puzzle"))
    UIManager:setDirty(self, function()
        return "ui", self.dimen
    end)
    self:startTicker()
end

function Screen:showSizeDialog()
    local dialog
    local buttons = {}

    for size = Game.getMinSize(), Game.getMaxSize() do
        buttons[#buttons + 1] = {
            {
                text       = i18n.t("size_label", size),
                background = Blitbuffer.COLOR_WHITE,
                callback   = function()
                    UIManager:close(dialog)
                    self:switchSize(size)
                end,
            },
        }
    end

    buttons[#buttons + 1] = {
        {
            text       = i18n.t("cancel"),
            background = Blitbuffer.COLOR_WHITE,
            callback   = function() UIManager:close(dialog) end,
        },
    }

    dialog = ButtonDialog:new{
        title   = i18n.t("select_size"),
        buttons = buttons,
    }
    UIManager:show(dialog)
end

function Screen:switchSize(size)
    if size == self.game:getSize() then return end
    self:stopTicker()
    self.plugin:saveCurrentState(self.game)
    self.plugin:setActiveSize(size)
    self.game = self.plugin:getCurrentGame()
    self.board_widget:setGame(self.game)
    self.live_tick_accum = 0
    self:updateHeader()
    self:updateBestLabel()
    self:updateMessage()
    UIManager:setDirty(self, function()
        return "ui", self.dimen
    end)
    self:startTicker()
end

function Screen:adjustFont(delta)
    local current = self.plugin.settings:readSetting("font_offset") or 0
    local new_offset = current + delta
    -- Limit offset to reasonable values
    if new_offset < -20 then new_offset = -20 end
    if new_offset > 50 then new_offset = 50 end
    
    self.plugin.settings:saveSetting("font_offset", new_offset)
    self.plugin.settings:flush()
    self.board_widget:setFontOffset(new_offset)
    
    UIManager:setDirty(self, function()
        return "ui", self.dimen
    end)
end

function Screen:showStats()
    local lines = { "", i18n.t("stats_title") .. ":", "" }
    
    local col_widths = { size = 8, time = 8, moves = 7, games = 6 }

    local header = string.format("%-" .. col_widths.size .. "s  %-" .. col_widths.time .. "s  %" .. col_widths.moves .. "s  %" .. col_widths.games .. "s",
        i18n.t("stat_col_size") or "Size",
        i18n.t("stat_col_time") or "Time",
        i18n.t("stat_col_moves") or "Moves",
        i18n.t("stat_col_games") or "Games")
    table.insert(lines, header)
    table.insert(lines, string.rep("-", #header))
    
    for size = Game.getMinSize(), Game.getMaxSize() do
        local stats = self.plugin:getStats(size)
        local time_s = (stats and stats.best_time) and formatTime(stats.best_time) or "--:--"
        local moves_s = (stats and stats.best_moves) and tostring(stats.best_moves) or "----"
        local plays_s = (stats and stats.plays) and tostring(stats.plays) or "0"
        
        table.insert(lines, string.format("%-" .. col_widths.size .. "s  %-" .. col_widths.time .. "s  %" .. col_widths.moves .. "s  %" .. col_widths.games .. "s",
            string.format("%dx%d", size, size),
            time_s,
            moves_s,
            plays_s))
    end
    
    table.insert(lines, "")
    
    UIManager:show(InfoMessage:new{
        text = table.concat(lines, "\n"),
        width = math.floor(self.dimen.w * 0.8),
        face = Font:getFace("smallinfofont"),
    })
end

function Screen:onClose()
    self:stopTicker()
    self.plugin:saveCurrentState(self.game)
    self.plugin:onScreenClosed()
    UIManager:close(self)
    UIManager:setDirty(nil, "full")
end

-- Painting ----------------------------------------------------------------

function Screen:paintTo(bb, x, y)
    self.dimen.x = x
    self.dimen.y = y
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)
    local content_size = self.layout:getSize()
    local offset_x = x + math.floor((self.dimen.w - content_size.w) / 2)
    local offset_y = y + math.floor((self.dimen.h - content_size.h) / 2)
    if offset_y < y then offset_y = y end
    self.layout:paintTo(bb, offset_x, offset_y)
end

return Screen
