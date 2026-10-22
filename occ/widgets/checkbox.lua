--[[
    checkbox.lua
    A box that is ticked or not, with a label beside it. The whole row answers
    to the cursor, not just the box.

    Example:
    root (base)
    |_window
     |_group
      |_page (base)
       |_checkbox
]]

local CHECKBOX = occ.register("checkbox", "base")

local MOUSE_LEFT = MOUSE_LEFT or 107

--- Initializes the checkbox.
function CHECKBOX:Init()
    self.name = "checkbox"

    self.w = 100
    self.h = 16

    --- Text drawn beside the box.
    self.text = ""

    --- Is it ticked?
    self.checked = false

    --- Size of the box itself.
    self.boxSize = 10

    --- Space between the box and its text.
    self.spacing = 4

    --- How much of what the font reports as its height is leading rather than
    --- glyphs. Taken off when the row is measured - the box rides in the middle
    --- of the row, so leading left on would sit half above it and half below,
    --- pushing one checkbox that much further off the next than the stack was
    --- asked to put them.
    self.textpad = 5

    --- Font it draws with, a name occ.font knows, nil for the one the style
    --- picks.
    self.font = nil

    --- Colour of the text, nil for the one the style picks. Set, it is worn
    --- hovered as well - a checkbox told to be one colour is that colour.
    self.color = nil

    --- Has it been measured since the text last changed?
    self.sized = false
end

--- Takes the height of whichever is taller, the box or its text.
--- The width is left to whatever put the checkbox where it is - a stack hands
--- it the full width of the area, so the whole row can be clicked.
function CHECKBOX:PerformLayout()
    if self.sized then return end

    local _, th = self:Measure()

    self.sized = true

    if self.h == th then return end

    self.h = th

    --> Whatever is laying the checkbox out goes by its height, and
    --> InvalidateLayout stops at a widget already waiting for a layout - which
    --> this one is, being in the middle of its own - so the parent is told from
    --> here.
    if self.parent then
        self.parent:InvalidateLayout()
    end
end

--- Paints the checkbox.
--- @param x number
--- @param y number
--- @param w number
--- @param h number
function CHECKBOX:Paint(x, y, w, h)
    local alpha = self:GetAbsoluteAlpha() / 255
    local style = occ.style.checkbox
    local border = occ.style.border.window
    local size = self.boxSize

    --> The box rides in the middle of the row, whichever of it and the text is
    --> setting the height.
    local by = y + (h - size) * 0.5

    local fill = style.box

    if self.checked then
        fill = occ.style.accent
    elseif self.hovered then
        fill = style.boxhovered
    end

    surface.SetDrawColor(fill[1], fill[2], fill[3], fill[4] * alpha)
    surface.DrawRect(x, by, size, size)

    --> Over the fill and under the borders, so the box is shaded without the
    --> edges around it losing their bite.
    surface.SetDrawColor(30, 30, 30, 150 * alpha)
    surface.SetMaterial(occ.material("gradient-up"))
    surface.DrawTexturedRect(x, by, size, size)

    surface.SetDrawColor(border[1], border[2], border[3], border[4] * alpha)
    surface.DrawOutlinedRect(x, by, size, size)

    surface.SetFont(occ.font(self:GetFont()))

    local text = self.color or (self.hovered and style.texthovered or style.text)
    local _, th = surface.GetTextSize(self.text)

    surface.SetTextColor(text[1], text[2], text[3], text[4] * alpha)
    surface.SetTextPos(x + size + self.spacing, y + (h - th) * 0.5)
    surface.DrawText(self.text)
end

--- Measures the box and its text together, telling the checkbox how big it
--- wants to be.
--- @return number w
--- @return number h
function CHECKBOX:Measure()
    surface.SetFont(occ.font(self:GetFont()))

    local tw, th = surface.GetTextSize(self.text)

    return self.boxSize + self.spacing + tw, math.max(self.boxSize, th - self.textpad)
end

--- Sizes the checkbox to its box and text, width and all.
function CHECKBOX:SizeToContents()
    local w, h = self:Measure()

    self.sized = true

    self:SetSize(w, h)
end

--- Ticks or unticks the box.
--- @param checked boolean
function CHECKBOX:SetChecked(checked)
    checked = checked and true or false

    if self.checked == checked then return end

    self.checked = checked

    self:OnChange(checked)
end

--- Is the box ticked?
--- @return boolean checked
function CHECKBOX:GetChecked()
    return self.checked
end

--- Ticks it if it was not, unticks it if it was.
function CHECKBOX:Toggle()
    self:SetChecked(not self.checked)
end

--- Called when the box is ticked or unticked, however it happened.
--- *Override this!*
--- @param checked boolean
function CHECKBOX:OnChange(checked) end

--- Sets the text beside the box.
--- @param text string
function CHECKBOX:SetText(text)
    if self.text == text then return end

    self.text = text
    self.sized = false

    self:InvalidateLayout()
end

--- Gets the text beside the box.
--- @return string text
function CHECKBOX:GetText()
    return self.text
end

--- Sets the colour of the text.
--- @param color table|nil One of occ.color's, nil for the style's own.
function CHECKBOX:SetTextColor(color)
    self.color = color
end

--- Gets the colour of the text.
--- @return table color
function CHECKBOX:GetTextColor()
    return self.color or occ.style.checkbox.text
end

--- Sets the font the text draws with.
--- @param font string|nil Name occ.font knows, nil for the style's own.
function CHECKBOX:SetFont(font)
    if self.font == font then return end

    self.font = font
    self.sized = false

    self:InvalidateLayout()
end

--- Gets the font the text draws with.
--- @return string font
function CHECKBOX:GetFont()
    return self.font or occ.style.checkbox.font
end

--- Toggles the box when the row is clicked.
--- @param mx number
--- @param my number
--- @param key number
function CHECKBOX:OnMousePressed(mx, my, key)
    if key ~= MOUSE_LEFT then return end

    self:Toggle()
end

--- Creates a checkbox.
--- @param text string|nil Text beside the box, also used as its name.
--- @param parent table|nil Widget to parent it to, occ.root by default.
--- @return table checkbox
function occ.checkbox(text, parent)
    local checkbox = occ.create("checkbox", parent or occ.root)

    if text then
        checkbox:SetName(text)
        checkbox:SetText(text)
    end

    return checkbox
end
