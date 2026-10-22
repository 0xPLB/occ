--[[
    expandable.lua
    A row with an arrow and a label on it that opens to show what is on it.
    Anything parented to it is stacked underneath while it is open, and put away
    again when it is shut.

    Example:
    root (base)
    |_window
     |_group
      |_page (base)
       |_expandable
        |_checkbox
        |_checkbox
]]

local EXPANDABLE = occ.register("expandable", "base")

local tween = lje.include("backend/tween.lua")

local MOUSE_LEFT = MOUSE_LEFT or 107
local MOUSE_RIGHT = MOUSE_RIGHT or 108

local SysTime = SysTime or lje.secure.pull("SysTime", lje.state.menu)

--- Initializes the expandable.
function EXPANDABLE:Init()
    self.name = "expandable"

    self.w = 100
    self.h = 16

    --- Text beside the arrow.
    self.text = ""

    --- Is it open?
    self.open = false

    --- Size of the arrow.
    self.arrowSize = 14

    --- Space between the arrow and the text.
    self.spacing = 3

    --- How far in from the left what is on it is stacked.
    self.indent = 14

    --- Space between the row and what is under it, and between one of those and
    --- the next.
    self.childSpacing = 2

    --- Degrees the arrow turns to when it opens, which is a quarter turn
    --- clockwise - the rotation goes counter clockwise, so clockwise is under
    --- zero.
    self.openRotation = -90

    --- Seconds the arrow takes to turn, nil for the one the style picks, 0 to
    --- have it snap round.
    self.rotatetime = nil

    --- Where the arrow is in its turn, and the turn it is part way through.
    self.state = {rotation = 0}
    self.animation = nil

    --- Font it draws with, a name occ.font knows, nil for the one the style
    --- picks.
    self.font = nil

    --- Is the cursor on the row, as against somewhere under it?
    self.headerHovered = false

    self.lastthink = SysTime()
end

--- Turns the arrow along.
function EXPANDABLE:Think()
    local now = SysTime()

    --> Capped the way the other widgets cap theirs, so a long gap between frames
    --> does not throw the turn straight to the end.
    local dt = math.min(now - self.lastthink, 0.25)

    self.lastthink = now

    if self.animation and self.animation:update(dt) then
        self.animation = nil
    end
end

--- Height of the row itself, without anything that is on it.
--- The taller of the arrow and the text, so neither is cut off.
--- @return number
function EXPANDABLE:GetHeaderHeight()
    surface.SetFont(occ.font(self:GetFont()))

    local _, th = surface.GetTextSize(self.text)

    return math.max(self.arrowSize, th)
end

--- Stacks what is on it under the row, and takes the height that comes to.
function EXPANDABLE:PerformLayout()
    local head = self:GetHeaderHeight()
    local h = head

    --> Shut, what is on it is off the screen and out of the hit test as well as
    --> out of the way.
    for _, child in ipairs(self.children) do
        child:SetVisible(self.open)
    end

    if self.open then
        local used = occ.stack(self, self.indent, head + self.childSpacing,
            math.max(0, self.w - self.indent), self.childSpacing)

        if used > 0 then
            h = head + self.childSpacing + used
        end
    end

    if self.h == h then return end

    self.h = h

    --> Whatever is laying this out goes by its height, and InvalidateLayout
    --> stops at a widget already waiting for a layout - which this one is, being
    --> in the middle of its own - so the parent is told from here.
    if self.parent then
        self.parent:InvalidateLayout()
    end
end

--- Draws the lines from the row down to each thing on it, so the list reads as
--- a tree - a trunk down the gutter the indent leaves, and a branch out of it to
--- every child.
--- @param x number
--- @param y number
--- @param alpha number 0 to 1.
function EXPANDABLE:PaintTree(x, y, alpha)
    local style = occ.style.expandable
    local outline = occ.style.border.window

    --> Down the middle of the gutter the indent leaves, so it moves with it.
    local trunk = math.floor(x + self.indent * 0.5)
    local top = y + self:GetHeaderHeight()

    --> Twice over the same pieces, the outline first and the lines on top. Done
    --> a piece at a time instead, the outline of a later one would land on the
    --> line of an earlier one where the two meet.
    for pass = 1, 2 do
        local colour = pass == 1 and outline or style.tree

        --> How far the outline stands off the line, which is nothing at all on
        --> the pass that draws the line itself.
        local out = pass == 1 and 1 or 0
        local last = nil

        surface.SetDrawColor(colour[1], colour[2], colour[3], colour[4] * alpha)

        for _, child in ipairs(self.children) do
            if child:IsVisible() then
                --> A list that is itself open is taller than its row, and the
                --> branch belongs against that row rather than halfway down
                --> everything the list has on it.
                local tall = child.h

                if occ.isa(child, "expandable") then
                    tall = child:GetHeaderHeight()
                end

                local mid = math.floor(y + child.y + tall * 0.5)
                local len = math.max(0, x + child.x - trunk)

                surface.DrawRect(trunk - out, mid - out, len + out * 2, 1 + out * 2)

                last = mid
            end
        end

        --> The trunk stops at the last branch rather than carrying on past it,
        --> which is what makes the end of the list look like the end.
        if last then
            surface.DrawRect(trunk - out, top - out, 1 + out * 2, last - top + 1 + out * 2)
        end
    end
end

--- Paints the row. What is on it paints itself.
--- @param x number
--- @param y number
--- @param w number
--- @param h number
function EXPANDABLE:Paint(x, y, w, h)
    local alpha = self:GetAbsoluteAlpha() / 255
    local style = occ.style.expandable
    local size = self.arrowSize
    local head = self:GetHeaderHeight()

    if self.headerHovered then
        surface.SetDrawColor(style.hovered[1], style.hovered[2], style.hovered[3], style.hovered[4] * alpha)
        surface.DrawRect(x, y, w, head)
    end

    --> A rotated draw is placed by its middle rather than its corner, so this is
    --> the centre of the arrow and not the top left of it.
    local cx = x + size * 0.5
    local cy = y + head * 0.5

    surface.SetDrawColor(style.arrow[1], style.arrow[2], style.arrow[3], style.arrow[4] * alpha)
    surface.SetMaterial(occ.material("arrow-down"))
    surface.DrawTexturedRectRotated(cx, cy, size, size, self.state.rotation)

    surface.SetFont(occ.font(self:GetFont()))

    local text = self.headerHovered and style.texthovered or style.text
    local _, th = surface.GetTextSize(self.text)

    surface.SetTextColor(text[1], text[2], text[3], text[4] * alpha)
    surface.SetTextPos(x + size + self.spacing, y + (head - th) * 0.5)
    surface.DrawText(self.text)

    --> Under what is on the list, since that is painted after this - the lines
    --> stop at the left edge of each child, so nothing lands on top of them.
    if self.open then
        self:PaintTree(x, y, alpha)
    end
end

--- Opens it or shuts it, turning the arrow as it goes.
--- @param open boolean
function EXPANDABLE:SetOpen(open)
    open = open and true or false

    if self.open == open then return end

    self.open = open

    local to = open and self.openRotation or 0

    local time = self:GetRotateTime()

    if time > 0 then
        --> Carries on from wherever the arrow is, so opening and shutting in
        --> quick succession picks up rather than starting over.
        self.animation = tween.new(time, self.state, {rotation = to}, "outQuad")
    else
        self.animation = nil
        self.state.rotation = to
    end

    self:InvalidateLayout()
    self:OnToggle(open)
end

--- Seconds the arrow takes to turn.
--- @return number
function EXPANDABLE:GetRotateTime()
    return self.rotatetime or occ.style.expandable.rotatetime
end

--- Is it open?
--- @return boolean open
function EXPANDABLE:IsOpen()
    return self.open
end

--- Opens it if it is shut, shuts it if it is open.
function EXPANDABLE:Toggle()
    self:SetOpen(not self.open)
end

--- Sets what it does when it is opened or shut, or does it.
--- Handed a function it takes that function on. Handed a boolean it runs the one
--- it was given, which is how opening and shutting gets there.
---     list:OnToggle(function(self, open) ... end)
--- Replacing the method outright still works and takes the place of both.
--- @param callback function|boolean|nil
function EXPANDABLE:OnToggle(callback)
    if type(callback) == "function" then
        self.callback = callback
        return
    end

    if self.callback then
        self.callback(self, callback)
    end
end

--- Sets what the row does when it is right clicked, or does it.
--- Handed a function it takes that function on. Handed anything else it runs the
--- one it was given, which is how a right click gets there.
---     list:OnRightClick(function(self, mx, my) ... end)
--- Replacing the method outright still works and takes the place of both.
--- Nothing is hung off it to start with, so a right click does nothing until
--- something is.
--- @param callback function|number|nil
--- @param my number|nil
function EXPANDABLE:OnRightClick(callback, my)
    if type(callback) == "function" then
        self.rightcallback = callback
        return
    end

    if self.rightcallback then
        self.rightcallback(self, callback, my)
    end
end

--- Sets the text beside the arrow.
--- @param text string
function EXPANDABLE:SetText(text)
    if self.text == text then return end

    self.text = text

    self:InvalidateLayout()
end

--- Gets the text beside the arrow.
--- @return string text
function EXPANDABLE:GetText()
    return self.text
end

--- Sets the font the text draws with.
--- @param font string|nil Name occ.font knows, nil for the style's own.
function EXPANDABLE:SetFont(font)
    if self.font == font then return end

    self.font = font

    self:InvalidateLayout()
end

--- Gets the font the text draws with.
--- @return string font
function EXPANDABLE:GetFont()
    return self.font or occ.style.expandable.font
end

--- Is a point on the row, as against somewhere under it?
--- @param mx number
--- @param my number
--- @return boolean
function EXPANDABLE:IsInHeader(mx, my)
    local x, y = self:GetAbsolutePos()
    local head = self:GetHeaderHeight()

    return mx >= x and mx <= x + self.w and my >= y and my <= y + head
end

--- Opens and shuts it when the row is clicked.
--- Only the row - a click in the space beside what is on it is not a press on
--- the list.
--- @param mx number
--- @param my number
--- @param key number
function EXPANDABLE:OnMousePressed(mx, my, key)
    if not self:IsInHeader(mx, my) then return end

    --> The right button does not open or shut it - whatever is hung off
    --> OnRightClick is its own thing.
    if key == MOUSE_RIGHT then
        self:OnRightClick(mx, my)
        return
    end

    if key ~= MOUSE_LEFT then return end

    self:Toggle()
end

--- Tracks whether the cursor is on the row.
--- @param mx number
--- @param my number
--- @param dx number
--- @param dy number
function EXPANDABLE:OnMouseMoved(mx, my, dx, dy)
    self.headerHovered = self:IsInHeader(mx, my)
end

--- Drops the hover once the cursor leaves.
function EXPANDABLE:OnCursorExited()
    EXPANDABLE.BaseClass.OnCursorExited(self)

    self.headerHovered = false
end

--- Creates an expandable list.
--- @param text string|nil Text beside the arrow, also used as its name.
--- @param parent table|nil Widget to parent it to, occ.root by default.
--- @return table expandable
function occ.expandable(text, parent)
    local list = occ.create("expandable", parent or occ.root)

    if text then
        list:SetName(text)
        list:SetText(text)
    end

    return list
end
