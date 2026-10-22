--[[
    button.lua
    A box with a label across the middle of it that does something when clicked.

    Example:
    root (base)
    |_window
     |_group
      |_page (base)
       |_button
]]

local BUTTON = occ.register("button", "base")

local MOUSE_LEFT = MOUSE_LEFT or 107

--- Initializes the button.
function BUTTON:Init()
    self.name = "button"

    self.w = 100
    self.h = 22

    --- Text drawn across the middle of it.
    self.text = ""

    --- Space above and below the text.
    self.padding = 5

    --- Font it draws with, a name occ.font knows, nil for the one the style
    --- picks.
    self.font = nil

    --- Is the cursor holding it down?
    self.pressed = false

    --- What it runs when it is clicked, set with OnClick.
    self.callback = nil

    --- Does the button take the height of its text? Off for one being sized by
    --- whatever is laying it out.
    self.autosize = true

    --- Has it been measured since the text last changed?
    self.sized = false
end

--- Takes the height of its text and the padding around it.
--- The width is left to whatever put the button where it is - a stack hands it
--- the full width of the area.
function BUTTON:PerformLayout()
    if self.sized then return end

    local _, th = self:Measure()

    self.sized = true

    if not self.autosize or self.h == th then return end

    self.h = th

    --> Whatever is laying the button out goes by its height, and
    --> InvalidateLayout stops at a widget already waiting for a layout - which
    --> this one is, being in the middle of its own - so the parent is told from
    --> here.
    if self.parent then
        self.parent:InvalidateLayout()
    end
end

--- Paints the button.
--- @param x number
--- @param y number
--- @param w number
--- @param h number
function BUTTON:Paint(x, y, w, h)
    local alpha = self:GetAbsoluteAlpha() / 255
    local style = occ.style.button
    local border = occ.style.border.window

    local fill = style.background

    if self.pressed then
        fill = style.pressed
    elseif self.hovered then
        fill = style.hovered
    end

    surface.SetDrawColor(fill[1], fill[2], fill[3], fill[4] * alpha)
    surface.DrawRect(x, y, w, h)

    --> Shading up off the foot of the button. Over the fill and under the
    --> border, so the edge round it keeps its bite.
    local fade = style.fade

    surface.SetDrawColor(fade[1], fade[2], fade[3], fade[4] * alpha)
    surface.SetMaterial(occ.material("gradient-up"))
    surface.DrawTexturedRect(x, y, w, h)

    surface.SetDrawColor(border[1], border[2], border[3], border[4] * alpha)
    surface.DrawOutlinedRect(x, y, w, h)

    surface.SetFont(occ.font(self:GetFont()))

    local text = self.hovered and style.texthovered or style.text
    local tw, th = surface.GetTextSize(self.text)

    --> Middle of the button both ways, so it sits right whatever width the
    --> layout hands it.
    surface.SetTextColor(text[1], text[2], text[3], text[4] * alpha)
    surface.SetTextPos(x + (w - tw) * 0.5, y + (h - th) * 0.5)
    surface.DrawText(self.text)
end

--- Measures the text and the padding around it, telling the button how big it
--- wants to be.
--- @return number w
--- @return number h
function BUTTON:Measure()
    surface.SetFont(occ.font(self:GetFont()))

    local tw, th = surface.GetTextSize(self.text)

    return tw + self.padding * 2, th + self.padding * 2
end

--- Sizes the button to its text, width and all.
function BUTTON:SizeToContents()
    local w, h = self:Measure()

    self.sized = true

    self:SetSize(w, h)
end

--- Sets what the button does when it is clicked, or does it.
--- Handed a function it takes that function on. Handed nothing it runs the one
--- it was given, which is how a click gets there.
---     button:OnClick(function(self) ... end)
--- Replacing the method outright still works and takes the place of both.
--- @param callback function|nil Run with the button as its argument.
function BUTTON:OnClick(callback)
    if callback then
        self.callback = callback
        return
    end

    if self.callback then
        self.callback(self)
    end
end

--- Sets the text across the button.
--- @param text string
function BUTTON:SetText(text)
    if self.text == text then return end

    self.text = text
    self.sized = false

    self:InvalidateLayout()
end

--- Gets the text across the button.
--- @return string text
function BUTTON:GetText()
    return self.text
end

--- Sets the font the text draws with.
--- @param font string|nil Name occ.font knows, nil for the style's own.
function BUTTON:SetFont(font)
    if self.font == font then return end

    self.font = font
    self.sized = false

    self:InvalidateLayout()
end

--- Gets the font the text draws with.
--- @return string font
function BUTTON:GetFont()
    return self.font or occ.style.button.font
end

--- Sets whether the button takes the height of its text.
--- @param autosize boolean
function BUTTON:SetAutoSize(autosize)
    self.autosize = autosize
    self.sized = false

    self:InvalidateLayout()
end

--- Checks whether the button takes the height of its text.
--- @return boolean autosize
function BUTTON:GetAutoSize()
    return self.autosize
end

--- Is the cursor holding the button down?
--- @return boolean pressed
function BUTTON:IsPressed()
    return self.pressed
end

--- Takes the button down.
--- @param mx number
--- @param my number
--- @param key number
function BUTTON:OnMousePressed(mx, my, key)
    if key ~= MOUSE_LEFT then return end

    self.pressed = true
end

--- Lets the button back up, and calls it a click if the cursor was still on it.
--- @param mx number
--- @param my number
--- @param key number
function BUTTON:OnMouseReleased(mx, my, key)
    if key ~= MOUSE_LEFT then return end
    if not self.pressed then return end

    self.pressed = false

    --> A widget keeps hold of the cursor until it lets go, so a release that
    --> landed somewhere else still comes here - that is a press taken back
    --> rather than a click.
    if not self:IsInBounds(mx, my) then return end

    self:OnClick()
end

--- Creates a button.
--- @param text string|nil Text across it, also used as its name.
--- @param parent table|nil Widget to parent it to, occ.root by default.
--- @return table button
function occ.button(text, parent)
    local button = occ.create("button", parent or occ.root)

    if text then
        button:SetName(text)
        button:SetText(text)
    end

    return button
end
