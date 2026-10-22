--[[
    slider.lua
    A bar filled up to its value, with its label over the top left of it and the
    value itself across the middle.

    Example:
    root (base)
    |_window
     |_group
      |_page (base)
       |_slider
]]

local SLIDER = occ.register("slider", "base")

local MOUSE_LEFT = MOUSE_LEFT or 107

--- Initializes the slider.
function SLIDER:Init()
    self.name = "slider"

    self.w = 100
    self.h = 22

    --- Text drawn over the top left of the bar.
    self.text = ""

    --- What goes after the value - "px", "%", whatever it is counting in.
    self.unit = ""

    --- The ends of the range, and where in it the slider is.
    self.min = 0
    self.max = 100
    self.value = 0

    --- What the value is rounded to, 0 to let it land anywhere.
    self.step = 1

    --- Places after the point the value is written to.
    self.decimals = 0

    --- Height of the bar itself, without the label sitting over it. The outline
    --- is drawn on its bounds rather than around them, so 11 of it leaves 9
    --- inside the two lines.
    self.barHeight = 11

    --- Space between the label and the bar under it. Measured off the whole of
    --- what the font reports, descenders and all - trimming that is what has a
    --- p or a g hanging onto the top of the bar.
    self.labelGap = 1

    --- Space either side of the text when the slider is measured.
    self.padding = 4

    --- Font it draws with, a name occ.font knows, nil for the one the style
    --- picks.
    self.font = nil

    --- Is the cursor dragging it?
    self.dragging = false

    --- Has it been measured since the text last changed?
    self.sized = false
end

--- The bar, local to the slider. The label sits above it rather than on it, so
--- the bar starts below the height of the text.
--- @return number x
--- @return number y
--- @return number w
--- @return number h
function SLIDER:GetBarBounds()
    surface.SetFont(occ.font(self:GetFont()))

    local _, th = surface.GetTextSize(self.text)
    local top = th + self.labelGap

    return 0, top, self.w, math.max(0, self.h - top)
end

--- Takes the height of the label and the bar under it.
--- The width is left to whatever put the slider where it is - a stack hands it
--- the full width of the area.
function SLIDER:PerformLayout()
    if self.sized then return end

    local _, th = self:Measure()

    self.sized = true

    if self.h == th then return end

    self.h = th

    --> Whatever is laying the slider out goes by its height, and
    --> InvalidateLayout stops at a widget already waiting for a layout - which
    --> this one is, being in the middle of its own - so the parent is told from
    --> here.
    if self.parent then
        self.parent:InvalidateLayout()
    end
end

--- Paints the bar, what it is filled to, and the two bits of text on it.
--- @param x number
--- @param y number
--- @param w number
--- @param h number
function SLIDER:Paint(x, y, w, h)
    local alpha = self:GetAbsoluteAlpha() / 255
    local style = occ.style.slider
    local accent = occ.style.accent
    local border = occ.style.border.window

    surface.SetFont(occ.font(self:GetFont()))

    --> The label goes above the bar, so it is drawn first and the bar is put
    --> under it.
    local text = self.hovered and style.texthovered or style.text

    surface.SetTextColor(text[1], text[2], text[3], text[4] * alpha)
    surface.SetTextPos(x + 1, y - 1)
    surface.DrawText(self.text)

    local bx, by, bw, bh = self:GetBarBounds()

    bx, by = x + bx, y + by

    surface.SetDrawColor(style.background[1], style.background[2], style.background[3], style.background[4] * alpha)
    surface.DrawRect(bx, by, bw, bh)

    --> How far along the bar the value has got. Rounded, so the end of the fill
    --> lands on a pixel rather than between two of them.
    local filled = math.floor(bw * self:GetFraction() + 0.5)

    surface.SetDrawColor(accent[1], accent[2], accent[3], accent[4] * alpha)
    surface.DrawRect(bx, by, filled, bh)

    --> Over the fill as well as the bar, so the two are shaded as one rather
    --> than the fill sitting on top looking flat.
    surface.SetDrawColor(30, 30, 30, 255 * alpha)
    surface.SetMaterial(occ.material("gradient-up"))
    surface.DrawTexturedRect(bx, by, bw, bh)

    surface.SetDrawColor(border[1], border[2], border[3], border[4] * alpha)
    surface.DrawOutlinedRect(bx, by, bw, bh)

    --> The value across the middle of the bar, both ways.
    local shown = self:GetDisplay()
    local tw, th = surface.GetTextSize(shown)

    surface.SetTextColor(style.value[1], style.value[2], style.value[3], style.value[4] * alpha)
    surface.SetTextPos(bx + (bw - tw) * 0.5, by + (bh - th) * 0.5)
    surface.DrawText(shown)
end

--- Measures what the slider needs to be, which is its bar or its text.
--- @return number w
--- @return number h
function SLIDER:Measure()
    surface.SetFont(occ.font(self:GetFont()))

    local tw, th = surface.GetTextSize(self.text)
    local vw = surface.GetTextSize(self:GetDisplay())

    --> The label sits above the bar, so it is the two heights added rather than
    --> whichever is the taller of them.
    return math.max(tw, vw) + self.padding * 2, th + self.labelGap + self.barHeight
end

--- Sizes the slider to its text, width and all.
function SLIDER:SizeToContents()
    local w, h = self:Measure()

    self.sized = true

    self:SetSize(w, h)
end

--- The value as it is written on the bar, the unit after it.
--- @return string
function SLIDER:GetDisplay()
    local shown = string.format("%." .. math.max(0, self.decimals) .. "f", self.value)

    if self.unit ~= "" then
        return shown .. " " .. self.unit
    end

    return shown
end

--- How far along its range the slider is.
--- @return number 0 to 1.
function SLIDER:GetFraction()
    local range = self.max - self.min

    --> A range of nothing has no fraction to speak of, and working one out would
    --> be dividing by nothing.
    if range == 0 then return 0 end

    return math.min(math.max((self.value - self.min) / range, 0), 1)
end

--- Sets the value, held inside the range and rounded to the step.
--- @param value number
function SLIDER:SetValue(value)
    value = math.min(math.max(value, self.min), self.max)

    if self.step > 0 then
        --> Rounded off the bottom of the range rather than off zero, so a range
        --> that does not start there still lands on its own steps.
        value = self.min + math.floor((value - self.min) / self.step + 0.5) * self.step
        value = math.min(math.max(value, self.min), self.max)
    end

    if self.value == value then return end

    self.value = value
    self.sized = false

    self:OnChange(value)
end

--- Gets the value.
--- @return number
function SLIDER:GetValue()
    return self.value
end

--- Sets the ends of the range, keeping the value inside them.
--- @param min number
--- @param max number
function SLIDER:SetRange(min, max)
    self.min = min
    self.max = max

    --> The value may be outside the new range, and SetValue is what holds it in.
    self:SetValue(self.value)
end

--- Gets the ends of the range.
--- @return number min
--- @return number max
function SLIDER:GetRange()
    return self.min, self.max
end

--- Sets what the value is rounded to.
--- @param step number 0 to let it land anywhere.
function SLIDER:SetStep(step)
    self.step = step

    self:SetValue(self.value)
end

--- Sets how many places after the point the value is written to.
--- @param decimals number
function SLIDER:SetDecimals(decimals)
    self.decimals = decimals
    self.sized = false

    self:InvalidateLayout()
end

--- Sets what goes after the value.
--- @param unit string
function SLIDER:SetUnit(unit)
    if self.unit == unit then return end

    self.unit = unit
    self.sized = false

    self:InvalidateLayout()
end

--- Gets what goes after the value.
--- @return string
function SLIDER:GetUnit()
    return self.unit
end

--- Sets what the slider does when the value changes, or does it.
--- Handed a function it takes that function on. Handed a number it runs the one
--- it was given, which is how a drag gets there.
---     slider:OnChange(function(self, value) ... end)
--- Replacing the method outright still works and takes the place of both.
--- @param callback function|number|nil
function SLIDER:OnChange(callback)
    if type(callback) == "function" then
        self.callback = callback
        return
    end

    if self.callback then
        self.callback(self, callback)
    end
end

--- Sets the text over the top left of the bar.
--- @param text string
function SLIDER:SetText(text)
    if self.text == text then return end

    self.text = text
    self.sized = false

    self:InvalidateLayout()
end

--- Gets the text over the top left of the bar.
--- @return string text
function SLIDER:GetText()
    return self.text
end

--- Sets the font the text draws with.
--- @param font string|nil Name occ.font knows, nil for the style's own.
function SLIDER:SetFont(font)
    if self.font == font then return end

    self.font = font
    self.sized = false

    self:InvalidateLayout()
end

--- Gets the font the text draws with.
--- @return string font
function SLIDER:GetFont()
    return self.font or occ.style.slider.font
end

--- Takes the value from where the cursor is along the bar.
--- @param mx number
function SLIDER:SlideTo(mx)
    local x = self:GetAbsolutePos()
    local bx, _, bw = self:GetBarBounds()

    --> Clamped, so a drag that wanders off either end keeps the slider at that
    --> end rather than running past it.
    local t = math.min(math.max((mx - x - bx) / math.max(1, bw), 0), 1)

    self:SetValue(self.min + t * (self.max - self.min))
end

--- Is a point on the bar, as against on the label above it?
--- @param mx number
--- @param my number
--- @return boolean
function SLIDER:IsInBar(mx, my)
    local x, y = self:GetAbsolutePos()
    local bx, by, bw, bh = self:GetBarBounds()

    bx, by = x + bx, y + by

    return mx >= bx and mx <= bx + bw and my >= by and my <= by + bh
end

--- Starts a drag and takes the value from where it was pressed.
--- Only the bar - the label above it is not something to drag.
--- @param mx number
--- @param my number
--- @param key number
function SLIDER:OnMousePressed(mx, my, key)
    if key ~= MOUSE_LEFT then return end
    if not self:IsInBar(mx, my) then return end

    self.dragging = true

    self:SlideTo(mx)
end

--- Keeps taking the value while the cursor is held down.
--- @param mx number
--- @param my number
--- @param dx number
--- @param dy number
function SLIDER:OnMouseMoved(mx, my, dx, dy)
    if not self.dragging then return end

    self:SlideTo(mx)
end

--- Ends the drag.
--- @param mx number
--- @param my number
--- @param key number
function SLIDER:OnMouseReleased(mx, my, key)
    if key ~= MOUSE_LEFT then return end

    self.dragging = false
end

--- Creates a slider.
--- @param text string|nil Text over the bar, also used as its name.
--- @param parent table|nil Widget to parent it to, occ.root by default.
--- @return table slider
function occ.slider(text, parent)
    local slider = occ.create("slider", parent or occ.root)

    if text then
        slider:SetName(text)
        slider:SetText(text)
    end

    return slider
end
