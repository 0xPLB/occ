--[[
    tooltip.lua
    A note that comes up beside the cursor while the widget it is on is hovered.
    It is given a widget to speak for rather than put somewhere by hand, and
    that widget is the one that shows it.

    The widget it speaks for is not the one that holds it. A tooltip sits at the
    top of the tree, the way a popup does, so it is drawn over everything rather
    than under whatever its widget happens to be stacked in front of, and no
    page it is on can clip it.

    A tooltip goes on a widget that answers to the cursor - a checkbox, a
    button, a slider, a dropdown, a colorpicker. It is turned away from the ones
    that do not, and says so in the console rather than going on quietly and
    never coming up.

    Example:
    root (base)
    |_group
    | |_checkbox (the one it speaks for)
    |_tooltip
]]

local TOOLTIP = occ.register("tooltip", "base")

local tween = lje.include("backend/tween.lua")

local SysTime = SysTime or lje.secure.pull("SysTime", lje.state.menu)

--- Classes a tooltip will not go on. Base is in there because everything
--- derives from it and a bare one has nothing to hover, and the rest either
--- hold other widgets or are not hovered themselves.
local TURNED_AWAY = {
    base = true,
    window = true,
    popup = true,
    notification = true,
    expandable = true,
    label = true
}

--- Initializes the tooltip.
function TOOLTIP:Init()
    self.name = "tooltip"

    self.w = 0
    self.h = 0

    --- Text it shows, broken into lines when it does not fit the width.
    self.text = ""

    --- How wide it is allowed to get. The height is whatever the lines come to.
    self.maxWidth = 175

    --- Space between the text and the borders round it.
    self.padding = 5

    --- Space between one line and the next, on top of the height of the text.
    self.lineGap = 1

    --- How many rows of the accent along the top are on show, the shaded one
    --- included. It is drawn a row taller than this - the border round the
    --- tooltip is laid down after it and takes the top row back.
    self.accentHeight = 2

    --- How far off the cursor it sits once it has risen into place.
    self.offsetX = 12
    self.offsetY = 22

    --- How far under that it starts, and drops back to on the way out.
    self.rise = 30

    --- Seconds the cursor has to rest on the widget before the note comes up,
    --- nil for the one the style picks. Leaving before that is up and nothing
    --- is shown at all.
    self.delay = nil

    --- Seconds it takes to rise into place or drop back out, nil for the one
    --- the style picks, 0 for neither.
    self.tweentime = nil

    --- How far in it is - the alpha it is drawn at and how far under its place
    --- it still is.
    self.state = {alpha = 0, lift = self.rise}

    --- Is it meant to be up? Not the same as it being on screen - one on its
    --- way out is still there until it has dropped away.
    self.up = false

    --- When the cursor came to rest on the widget, nil when it is off it.
    self.hovertime = nil

    self.lastthink = SysTime()

    --- Font it draws with, a name occ.font knows, nil for the one the style
    --- picks.
    self.font = nil

    --- The text as it came out of the wrap, a line to an entry.
    self.lines = {}

    --- The widget it speaks for, which is not the one holding it.
    self.owner = nil

    --- Has the text been broken up since it last changed?
    self.sized = false

    --> Nothing to show until the widget it is on is hovered.
    self.visible = false
end

--- Can a tooltip go on a widget?
--- @param widget table|nil
--- @return boolean
function TOOLTIP.Allowed(widget)
    if not widget then return false end

    return not TURNED_AWAY[occ.classof(widget) or "base"]
end

--- Puts the tooltip on a widget, turning away the ones it will not go on.
--- The tooltip itself goes to the root rather than to that widget - it has to
--- be drawn after everything the widget is stacked with, and a child is drawn
--- with the widget holding it rather than over the ones beside it.
--- @param widget table|nil
--- @return boolean taken
function TOOLTIP:SetOwner(widget)
    if widget and not TOOLTIP.Allowed(widget) then
        lje.con_printf(string.format(
            "$#ff0000{occ}->a tooltip will not go on a %s ", tostring(occ.classof(widget))))

        return false
    end

    self.owner = widget

    if widget then
        self:SetParent(occ.root)
    end

    return true
end

--- Gets the widget it speaks for.
--- @return table|nil owner
function TOOLTIP:GetOwner()
    return self.owner
end

--- Never takes the cursor.
--- It sits under the pointer by design, and taking the cursor would drop the
--- hover off the widget it belongs to - which is the thing keeping it up.
--- @param mx number
--- @param my number
--- @return nil
function TOOLTIP:HitTest(mx, my)
    return nil
end

--- Breaks the text up and sizes the tooltip to what came out.
function TOOLTIP:PerformLayout()
    if self.sized then return end

    surface.SetFont(occ.font(self:GetFont()))

    local pad = self.padding
    local room = math.max(0, self.maxWidth - pad * 2)

    self.lines = occ.wrap(self.text, room)
    self.sized = true

    --- Every line is the same height, whatever is on it.
    local _, th = surface.GetTextSize("W")

    local widest = 0

    for _, line in ipairs(self.lines) do
        widest = math.max(widest, (surface.GetTextSize(line)))
    end

    self.lineHeight = th

    local w = math.min(self.maxWidth, widest + pad * 2)
    local h = self.accentHeight + 2 + pad * 2 + #self.lines * th + math.max(0, #self.lines - 1) * self.lineGap

    if self.w == w and self.h == h then return end

    self.w = w
    self.h = h
end

--- Seconds the cursor has to rest on the widget before the note comes up.
--- @return number
function TOOLTIP:GetDelay()
    return self.delay or occ.style.tooltip.delay
end

--- Seconds it takes to rise into place or drop back out.
--- @return number
function TOOLTIP:GetTweenTime()
    return self.tweentime or occ.style.tooltip.tweentime
end

--- Rises into place once the cursor has rested on the widget, drops back out
--- when it leaves, and follows the cursor while it is up.
function TOOLTIP:Think()
    local owner = self.owner

    if not owner then return end

    local now = SysTime()

    --> Capped the way the other widgets cap theirs, so a long gap between
    --> frames does not throw a rise straight to its end.
    local dt = math.min(now - self.lastthink, 0.25)

    self.lastthink = now

    local hovered = owner:IsHovered() and self.text ~= ""

    --> The clock starts when the cursor arrives and is thrown away the moment
    --> it leaves, so a cursor passing over the widget on its way somewhere else
    --> never brings the note up at all.
    if hovered then
        self.hovertime = self.hovertime or now
    else
        self.hovertime = nil
    end

    local up = hovered and now - self.hovertime >= self:GetDelay()

    if up ~= self.up then
        self.up = up

        local time = self:GetTweenTime()
        local to = up and {alpha = 255, lift = 0} or {alpha = 0, lift = self.rise}

        --> One caught part way through going either way carries on from where
        --> it is rather than starting over.
        if time > 0 then
            self.animation = tween.new(time, self.state, to, "outExpo")
        else
            self.animation = nil

            self.state.alpha = to.alpha
            self.state.lift = to.lift
        end

        --> On screen for the whole of the rise, and taken back off it at the
        --> end of the drop rather than at the start of it.
        if up then
            self:SetVisible(true)

            --> Last of the root's children is last of the tree to be drawn, so the
            --> note goes over the windows rather than under them. Only done as it
            --> comes up - the root is sorted mid-paint, and two notes on screen
            --> moving in front of each other every frame never let the paint end.
            self:MoveToFront()
        end
    end

    local animation = self.animation

    if animation and animation:update(dt) then
        self.animation = nil
    end

    self:SetAlpha(self.state.alpha)

    if not self.up and self.state.alpha <= 0 then
        if self.visible then
            self:SetVisible(false)
        end

        return
    end

    --> Position is local to whatever is holding it, so the corner of that comes
    --> back off the cursor.
    local px, py = 0, 0

    if self.parent then
        px, py = self.parent:GetAbsolutePos()
    end

    local mx, my = occ.mousepos()

    --> Under where it rests while it is on its way in or out, so it rises into
    --> place behind the cursor and drops back down as it goes.
    self:SetPos(mx - px + self.offsetX, my - py + self.offsetY + self.state.lift)
end

--- Paints the note.
--- @param x number
--- @param y number
--- @param w number
--- @param h number
function TOOLTIP:Paint(x, y, w, h)
    local alpha = self:GetAbsoluteAlpha() / 255
    local style = occ.style.tooltip
    local line = occ.style.border.window
    local line2 = occ.style.border.base
    local accent = occ.style.accent

    surface.SetDrawColor(style.background[1], style.background[2], style.background[3], style.background[4] * alpha)
    surface.DrawRect(x, y, w, h)

    --> The accent along the top, drawn a row taller than what is meant to be
    --> seen of it because the border below goes over the top row. The lower of
    --> the rows left is taken down to half the colour, so the bar has a lit
    --> edge and a shaded one rather than one flat band.
    local band = self.accentHeight
    local shade = occ.shcolor(50, accent)

    surface.SetDrawColor(accent[1], accent[2], accent[3], accent[4] * alpha)
    surface.DrawRect(x, y, w, band + 1)

    surface.SetDrawColor(shade[1], shade[2], shade[3], shade[4] * alpha)
    surface.DrawRect(x, y + band, w, 1)

    --> The line under the bar, the way a group and a window both carry one, so
    --> the shaded row of the accent has something to sit against rather than
    --> running straight into the frame below it.
    surface.SetDrawColor(line[1], line[2], line[3], line[4] * alpha)
    surface.DrawRect(x, y + band + 1, w, 1)

    --> A frame a pixel inside the border, starting under that line, so the note
    --> is edged the way the panels are.
    surface.SetDrawColor(line2[1], line2[2], line2[3], line2[4] * alpha)
    surface.DrawOutlinedRect(x + 1, y + band + 2, math.max(0, w - 2), math.max(0, h - band - 3))

    surface.SetDrawColor(line[1], line[2], line[3], line[4] * alpha)
    surface.DrawOutlinedRect(x, y, w, h)

    surface.SetFont(occ.font(self:GetFont()))

    local text = style.text
    local at = y + band + 2 + self.padding

    surface.SetTextColor(text[1], text[2], text[3], text[4] * alpha)

    for _, row in ipairs(self.lines) do
        surface.SetTextPos(x + self.padding, at)
        surface.DrawText(row)

        at = at + self.lineHeight + self.lineGap
    end
end

--- Sets the text it shows.
--- @param text string
function TOOLTIP:SetText(text)
    if self.text == text then return end

    self.text = text
    self.sized = false

    self:InvalidateLayout()
end

--- Gets the text it shows.
--- @return string text
function TOOLTIP:GetText()
    return self.text
end

--- Sets how wide it is allowed to get.
--- @param width number
function TOOLTIP:SetMaxWidth(width)
    if self.maxWidth == width then return end

    self.maxWidth = width
    self.sized = false

    self:InvalidateLayout()
end

--- Gets how wide it is allowed to get.
--- @return number width
function TOOLTIP:GetMaxWidth()
    return self.maxWidth
end

--- Sets the font the text draws with.
--- @param font string|nil Name occ.font knows, nil for the style's own.
function TOOLTIP:SetFont(font)
    if self.font == font then return end

    self.font = font
    self.sized = false

    self:InvalidateLayout()
end

--- Gets the font the text draws with.
--- @return string font
function TOOLTIP:GetFont()
    return self.font or occ.style.tooltip.font
end

--- Puts a tooltip on a widget.
--- Nothing goes on the ones a tooltip is turned away from - the tooltip comes
--- back all the same, with nothing holding it, and the console says why.
--- @param text string Text it shows.
--- @param parent table Widget it speaks for.
--- @return table tooltip
function occ.tooltip(text, parent)
    local tooltip = occ.create("tooltip")

    tooltip:SetName("tooltip")
    tooltip:SetText(text)
    tooltip:SetOwner(parent)

    return tooltip
end
