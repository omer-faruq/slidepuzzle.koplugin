--[[
    slidepuzzle_screen.lua
    Fullscreen game screen. Owns the timer ticker, builds the header and
    bottom button row, and forwards user input to the Game instance.
--]]

local Blitbuffer = require("ffi/blitbuffer")
local ButtonDialog = require("ui/widget/buttondialog")
local ButtonTable = require("ui/widget/buttontable")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")
local T = require("ffi/util").template

local BoardWidget = require("slidepuzzle_board")
local Game = require("slidepuzzle_game")

local TICK_INTERVAL = 1

local Screen = InputContainer:extend{
    plugin = nil, -- owning plugin, provides persistence hooks
    game = nil,   -- current Game instance
}

-- Helpers -----------------------------------------------------------------

local function formatTime(total_seconds)
    local s = math.floor(total_seconds or 0)
    if s < 0 then s = 0 end
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
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
    self.live_tick_accum = 0 -- seconds ticked during current run (not yet folded into game.elapsed)
    self.tick_scheduled = false
    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
    end
    self.header_text = TextWidget:new{
        face = Font:getFace("smallinfofont"),
        text = "",
        max_width = math.floor(self.dimen.w * 0.95),
    }
    self.best_text = TextWidget:new{
        face = Font:getFace("smallinfofont"),
        text = "",
        max_width = math.floor(self.dimen.w * 0.95),
    }
    self.message_text = TextWidget:new{
        face = Font:getFace("smallinfofont"),
        text = "",
        max_width = math.floor(self.dimen.w * 0.95),
    }
    self.board_widget = BoardWidget:new{
        game = self.game,
        max_size = self:computeBoardMaxSize(),
        onTileTap = function(row, col) self:performTap(row, col) end,
        onSwipeDir = function(direction) self:performSwipe(direction) end,
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
    -- Reserve roughly 25% of the short edge for the header + button row.
    local short = getDeviceShort()
    return math.floor(short * 0.78)
end

function Screen:buildLayout()
    local board_frame = FrameContainer:new{
        padding = Size.padding.default,
        margin = 0,
        bordersize = 0,
        self.board_widget,
    }
    local button_table = ButtonTable:new{
        shrink_unneeded_width = true,
        width = math.floor(self.dimen.w * 0.95),
        buttons = {
            {
                {
                    text = _("New"),
                    background = Blitbuffer.COLOR_WHITE,
                    callback = function() self:onNewGame() end,
                },
                {
                    text = _("Size"),
                    background = Blitbuffer.COLOR_WHITE,
                    callback = function() self:showSizeDialog() end,
                },
                {
                    text = _("Stats"),
                    background = Blitbuffer.COLOR_WHITE,
                    callback = function() self:showStats() end,
                },
                {
                    text = _("Close"),
                    background = Blitbuffer.COLOR_WHITE,
                    callback = function() self:onClose() end,
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
    local n = self.game:getSize()
    local live = self.game:getElapsed() + self.live_tick_accum
    self.header_text:setText(T(_("%1x%1 Puzzle    Moves: %2    Time: %3"),
        n, self.game:getMoves(), formatTime(live)))
end

function Screen:updateBestLabel()
    local stats = self.plugin:getStats(self.game:getSize())
    if stats and (stats.best_time or stats.best_moves) then
        local time_s = stats.best_time and formatTime(stats.best_time) or _("--:--")
        local moves_s = stats.best_moves and tostring(stats.best_moves) or "--"
        self.best_text:setText(T(_("Best: %1    Fewest moves: %2"), time_s, moves_s))
    else
        self.best_text:setText(_("Best: not set yet"))
    end
end

function Screen:getDefaultMessage()
    if self.game:isWon() then
        return _("Solved! Tap \"New\" to play again.")
    end
    if self.game:getMoves() == 0 then
        return _("Tap a tile next to the gap, or swipe to slide.")
    end
    return _("")
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
    local now = os.time()
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
    self.last_tick_time = nil
end

-- Input handling ----------------------------------------------------------

function Screen:performTap(row, col)
    if self.game:isWon() then
        -- Tapping anywhere on a solved puzzle starts a fresh game of the
        -- same size, which matches the "feel" of quick puzzle apps.
        self:onNewGame()
        return
    end
    local ok = self.game:moveTileAt(row, col)
    if ok then
        self:afterMove()
    else
        self:updateMessage(_("Only tiles next to the gap can move."))
    end
end

function Screen:performSwipe(direction)
    if self.game:isWon() then return end
    local ok = self.game:slide(direction)
    if ok then
        self:afterMove()
    end
end

function Screen:afterMove()
    self:updateHeader()
    if self.game:isWon() then
        self:updateMessage(T(_("Solved in %1 moves and %2."),
            self.game:getMoves(), formatTime(self.game:getElapsed() + self.live_tick_accum)))
    else
        self:updateMessage()
    end
    -- Dirty the whole screen so that both the board (showing the last
    -- tile in its final position) and the updated header/message are
    -- guaranteed to repaint together. Force that paint to complete
    -- BEFORE anything else (especially the "solved" overlay) is shown
    -- on top, so the winning move is actually visible on screen.
    UIManager:setDirty(self, function()
        return "ui", self.dimen
    end)
    if self.game:isWon() then
        UIManager:forceRePaint()
        -- Fold in the currently ticking second and stop the timer so the
        -- reported best time matches what the header now displays.
        self:stopTicker()
        self.plugin:recordResult(self.game)
        self:updateBestLabel()
        UIManager:show(InfoMessage:new{
            text = T(_("You solved the %1x%1 puzzle!\nMoves: %2\nTime: %3"),
                self.game:getSize(), self.game:getMoves(), formatTime(self.game:getElapsed())),
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
    self:updateMessage(_("New puzzle — good luck!"))
    self.board_widget:refresh()
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
                text = T(_("%1 × %1"), size),
                background = Blitbuffer.COLOR_WHITE,
                callback = function()
                    UIManager:close(dialog)
                    self:switchSize(size)
                end,
            },
        }
    end
    buttons[#buttons + 1] = {
        {
            text = _("Cancel"),
            background = Blitbuffer.COLOR_WHITE,
            callback = function() UIManager:close(dialog) end,
        },
    }
    dialog = ButtonDialog:new{
        title = _("Select board size"),
        buttons = buttons,
    }
    UIManager:show(dialog)
end

function Screen:switchSize(size)
    if size == self.game:getSize() then return end
    -- Save current size state before switching.
    self:stopTicker()
    self.plugin:saveCurrentState(self.game)
    self.plugin:setActiveSize(size)
    self.game = self.plugin:getCurrentGame()
    self.board_widget:setGame(self.game)
    self.live_tick_accum = 0
    self:updateHeader()
    self:updateBestLabel()
    self:updateMessage()
    self.board_widget:refresh()
    UIManager:setDirty(self, function()
        return "ui", self.dimen
    end)
    self:startTicker()
end

function Screen:showStats()
    local lines = { _("Best results by board size:") }
    for size = Game.getMinSize(), Game.getMaxSize() do
        local stats = self.plugin:getStats(size)
        local time_s = (stats and stats.best_time) and formatTime(stats.best_time) or "--"
        local moves_s = (stats and stats.best_moves) and tostring(stats.best_moves) or "--"
        lines[#lines + 1] = T(_("%1×%1: time %2, moves %3"), size, time_s, moves_s)
    end
    UIManager:show(InfoMessage:new{ text = table.concat(lines, "\n") })
end

function Screen:onClose()
    self:stopTicker()
    self.plugin:saveCurrentState(self.game)
    self.plugin:onScreenClosed()
    UIManager:close(self)
    UIManager:setDirty(nil, "full")
end

-- Painting ---------------------------------------------------------------

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
