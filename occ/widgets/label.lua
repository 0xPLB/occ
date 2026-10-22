--[[
    label.lua
    A line of text, and nothing else.

    Example:
    root (base)
    |_window
     |_label
]]

local LABEL = occ.register("label", "base")

--- Initializes the label.
function LABEL:Init()
    self.name = "label"

    self.w = 100
    self.h = 16

    --- Text the label draws.
    self.text = ""

    --- Font it draws with, a name occ.font knows, nil for the one the style
    --- picks.
    self.font = nil

    --- Colour it draws in, nil for the one the style picks.
    self.color = nil

    --- How the text sits across the label - "left", "center" or "right". The
    --- width is whatever the label was given, so anything but left needs one
    --- wider than the text to have somewhere to sit.
    self.align = "left"

    --- Does the label take the height of its text?
    self.autosize = true

    --- Has it been measured since the text last changed?
    self.sized = false
end

--- Takes the height of the text.
--- The width is left to whatever put the label where it is - a stack hands it
--- the full width of the area it is in.
function LABEL:PerformLayout()
    if self.sized then return end

    local _, th = self:Measure()

    self.sized = true

    if not self.autosize or self.h == th then return end

    self.h = th

    --> Whatever is laying the label out goes by its height, and InvalidateLayout
    --> stops at a widget already waiting for a layout - which this one is, being
    --> in the middle of its own - so the parent is told from here.
    if self.parent then
        self.parent:InvalidateLayout()
    end
end

--- Paints the label.
--- @param x number
--- @param y number
--- @param w number
--- @param h number
function LABEL:Paint(x, y, w, h)
    local alpha = self:GetAbsoluteAlpha() / 255
    local color = self:GetTextColor()

    surface.SetFont(occ.font(self:GetFont()))

    local tx = x

    --> Measured only when the text is not being laid against the left edge,
    --> which is the one place the width does not come into it.
    if self.align ~= "left" then
        local tw = surface.GetTextSize(self.text)

        if self.align == "center" then
            tx = x + math.floor((w - tw) * 0.5 + 0.5)
        else
            tx = x + w - tw
        end
    end

    surface.SetTextColor(color[1], color[2], color[3], color[4] * alpha)
    surface.SetTextPos(tx, y)
    surface.DrawText(self.text)
end

--- Measures the text, telling the label how big it wants to be.
--- @return number w
--- @return number h
function LABEL:Measure()
    surface.SetFont(occ.font(self:GetFont()))

    return surface.GetTextSize(self.text)
end

--- Sizes the label to its text, width and all.
function LABEL:SizeToContents()
    local w, h = self:Measure()

    self.sized = true

    self:SetSize(w, h)
end

--- Sets the text of the label.
--- @param text string
function LABEL:SetText(text)
    if self.text == text then return end

    self.text = text
    self.sized = false

    self:InvalidateLayout()
end

--- Gets the text of the label.
--- @return string text
function LABEL:GetText()
    return self.text
end

--- Sets the font the label draws with.
--- @param font string|nil Name occ.font knows, nil for the style's own.
function LABEL:SetFont(font)
    if self.font == font then return end

    self.font = font
    self.sized = false

    self:InvalidateLayout()
end

--- Gets the font the label draws with.
--- @return string font
function LABEL:GetFont()
    return self.font or occ.style.label.font
end

--- Sets the colour the label draws in.
--- @param color table|nil Colour from occ.color, nil for the style's own.
function LABEL:SetTextColor(color)
    self.color = color
end

--- Gets the colour the label draws in.
--- @return table color
function LABEL:GetTextColor()
    return self.color or occ.style.label.text
end

--- Sets how the text sits across the label.
--- @param align string "left", "center" or "right".
function LABEL:SetAlign(align)
    self.align = align or "left"
end

--- Gets how the text sits across the label.
--- @return string align
function LABEL:GetAlign()
    return self.align
end

--- Sets whether the label takes the height of its text.
--- @param autosize boolean
function LABEL:SetAutoSize(autosize)
    self.autosize = autosize
    self.sized = false

    self:InvalidateLayout()
end

--- Checks whether the label takes the height of its text.
--- @return boolean autosize
function LABEL:GetAutoSize()
    return self.autosize
end

--- Creates a label.
--- @param text string|nil Text it draws, also used as its name.
--- @param parent table|nil Widget to parent it to, occ.root by default.
--- @return table label
function occ.label(text, parent)
    local label = occ.create("label", parent or occ.root)

    if text then
        label:SetName(text)
        label:SetText(text)
    end

    return label
end
