--[[
    slidepuzzle_board.lua
    Board widget: renders the current grid and turns user input into
    callbacks the screen can consume. Keeps rendering minimal and e-ink
    friendly (flat tiles, thin borders, centred numbers).
--]]

local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local RenderText = require("ui/rendertext")
local UIManager = require("ui/uimanager")

local BoardWidget = InputContainer:extend{
    game = nil,      -- slidepuzzle_game.Game instance
    max_size = nil,  -- maximum board side length in pixels
    onTileTap = nil, -- function(row, col)
    onSwipeDir = nil,-- function(direction) where direction is left/right/up/down
}

local MIN_CELL = 32

function BoardWidget:init()
    self.paint_rect = Geom:new{ x = 0, y = 0, w = 0, h = 0 }
    self:_computeMetrics()
    if Device:isTouchDevice() then
        self.ges_events = {
            Tap = {
                GestureRange:new{
                    ges = "tap",
                    range = function() return self.paint_rect end,
                },
            },
            Swipe = {
                GestureRange:new{
                    ges = "swipe",
                    range = function() return self.paint_rect end,
                },
            },
        }
    end
end

function BoardWidget:_computeMetrics()
    local n = self.game:getSize()
    local available = self.max_size or math.min(Device.screen:getWidth(), Device.screen:getHeight())
    -- Leave room so thicker borders on larger grids still fit.
    local cell = math.floor(available / n)
    if cell < MIN_CELL then cell = MIN_CELL end
    self.cell = cell
    self.board_size = cell * n
    self.dimen = Geom:new{ w = self.board_size, h = self.board_size }
    -- Font face for numbers. Sizes scale down for larger grids so the
    -- three-digit tiles on 7x7 still fit comfortably inside the cell.
    local font_px = math.max(18, math.floor(cell * 0.45))
    self.number_face = Font:getFace("cfont", font_px)
end

function BoardWidget:setGame(game)
    self.game = game
    self:_computeMetrics()
end

function BoardWidget:setMaxSize(px)
    self.max_size = px
    self:_computeMetrics()
end

function BoardWidget:refresh()
    local rect = self.paint_rect
    if not rect then return end
    UIManager:setDirty(nil, function()
        return "ui", Geom:new{ x = rect.x, y = rect.y, w = rect.w, h = rect.h }
    end)
end

-- Gesture handlers --------------------------------------------------------

function BoardWidget:_cellFromPoint(x, y)
    if not self.paint_rect or self.cell <= 0 then return nil end
    local lx = x - self.paint_rect.x
    local ly = y - self.paint_rect.y
    if lx < 0 or ly < 0 or lx >= self.board_size or ly >= self.board_size then
        return nil
    end
    local col = math.floor(lx / self.cell) + 1
    local row = math.floor(ly / self.cell) + 1
    return row, col
end

function BoardWidget:onTap(_, ges)
    if not (ges and ges.pos and self.onTileTap) then return false end
    local row, col = self:_cellFromPoint(ges.pos.x, ges.pos.y)
    if not row then return false end
    self.onTileTap(row, col)
    return true
end

function BoardWidget:onSwipe(_, ges)
    if not (ges and ges.direction and self.onSwipeDir) then return false end
    local direction = BD.flipDirectionIfMirroredUILayout(ges.direction)
    local mapped
    if direction == "west" then
        mapped = "left"
    elseif direction == "east" then
        mapped = "right"
    elseif direction == "north" then
        mapped = "up"
    elseif direction == "south" then
        mapped = "down"
    end
    if mapped then
        self.onSwipeDir(mapped)
        return true
    end
    return false
end

-- Painting ---------------------------------------------------------------

function BoardWidget:paintTo(bb, x, y)
    self.paint_rect = Geom:new{ x = x, y = y, w = self.board_size, h = self.board_size }
    local n = self.game:getSize()
    local cell = self.cell
    local border = 2
    local grid = self.game:getGrid()
    -- Outer white wash so previous frames are erased cleanly.
    bb:paintRect(x, y, self.board_size, self.board_size, Blitbuffer.COLOR_WHITE)
    for r = 1, n do
        for c = 1, n do
            local tile_x = x + (c - 1) * cell
            local tile_y = y + (r - 1) * cell
            local value = grid[r][c]
            if value == 0 then
                -- Empty cell stays plain white with a thin frame.
                bb:paintBorder(tile_x, tile_y, cell, cell, border, Blitbuffer.COLOR_GRAY_5)
            else
                -- Correctly placed tiles are drawn inverted (solid black
                -- fill with white digits) so the player can tell at a
                -- glance which pieces are already in their final position.
                -- Other tiles use a light-grey fill with a black digit.
                local expected = (r - 1) * n + c
                local in_place = (value == expected)
                local fill, text_color
                if in_place then
                    fill = Blitbuffer.COLOR_BLACK
                    text_color = Blitbuffer.COLOR_WHITE
                else
                    fill = Blitbuffer.COLOR_GRAY_E
                    text_color = Blitbuffer.COLOR_BLACK
                end
                bb:paintRect(tile_x + 1, tile_y + 1, cell - 2, cell - 2, fill)
                bb:paintBorder(tile_x, tile_y, cell, cell, border, Blitbuffer.COLOR_BLACK)
                local text = tostring(value)
                local metrics = RenderText:sizeUtf8Text(0, cell, self.number_face, text, true, false)
                local text_w = metrics.x
                local baseline = tile_y + math.floor((cell + metrics.y_top - metrics.y_bottom) / 2)
                local text_x = tile_x + math.floor((cell - text_w) / 2)
                RenderText:renderUtf8Text(bb, text_x, baseline, self.number_face, text, true, false,
                    text_color)
            end
        end
    end
    -- Thick outer border for visual grounding on e-ink.
    bb:paintBorder(x, y, self.board_size, self.board_size, border + 1, Blitbuffer.COLOR_BLACK)
end

return BoardWidget
