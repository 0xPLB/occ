--[[
    colorpicker.lua
    A small square of the colour picked with a label beside it. Pressing the
    square brings up a popup with the cube to pick a colour out of, a strip for
    the hue and another for the alpha down the side of it, and a mark on each
    showing where the pick is.

    Two classes live here. The field is the pickable part inside the popup, and
    is no use on its own, so it is kept with the picker that makes it rather than
    given a file of its own.

    Example:
    root (base)
    |_group
    | |_colorpicker
    |_popup
      |_colorfield
]]

local COLORPICKER = occ.register("colorpicker", "base")
local FIELD = occ.register("colorfield", "base")

local MOUSE_LEFT = MOUSE_LEFT or 107

local SysTime = SysTime or lje.secure.pull("SysTime", lje.state.menu)

--- Pickers with an animation on, ticked by occ.tickpickers every frame.
--> Not left to Think: that only runs while the picker is painted, so the
--> colour would stop reaching whoever listens once the overlay shuts or the
--> picker is hidden. Weak keys so a picker nothing else holds can still go.
local animating = setmetatable({}, {__mode = "k"})

--- Is the widget still hanging off one of the roots that get drawn?
--- @param widget table
--- @return boolean
local function attached(widget)
    while widget do
        if widget == occ.root or widget == occ.notifications then
            return true
        end

        widget = widget.parent
    end

    return false
end

--- Pushes every animating picker's colour on. Called once a frame by render,
--- open or shut.
function occ.tickpickers()
    for picker in pairs(animating) do
        --> Off the tree - cleared by occ.clear or left behind by a reload - so
        --> it stops, rather than pushing old colours at whatever it was built
        --> for while its replacement does the same.
        if picker.animation == "none" or not attached(picker) then
            animating[picker] = nil
        else
            picker:OnChange(picker:GetColor())
        end
    end
end

--- Pins a number between two others.
--- @param value number
--- @param low number
--- @param high number
--- @return number
local function clamp(value, low, high)
    return math.min(math.max(value, low), high)
end

--[[
    The field - the cube, the hue and alpha strips, and the marks on them.
]]

--- Initializes the field.
function FIELD:Init()
    self.name = "colorfield"

    --- The cube to pick a colour out of. The hue is picked on the strip beside
    --- it, so the cube itself is the one hue, at every saturation across it and
    --- every value down it.
    self.cubeW = 176
    self.cubeH = 132

    --- The strips beside it, one for the hue and one for the alpha, and the
    --- space left between each piece and the next.
    self.stripW = 14
    self.gap = 6

    --- Size the crosshair on the cube is drawn at.
    self.crosshair = 10

    self.w = self.cubeW + (self.gap + self.stripW) * 2
    self.h = self.cubeH

    --- What is being dragged, nil, "cube", "hue" or "alpha".
    self.dragging = nil

    --- The picker this belongs to, told whenever something is picked.
    self.picker = nil
end

--- Left of the hue strip, local to the field.
--- @return number
function FIELD:GetHueX()
    return self.cubeW + self.gap
end

--- Left of the alpha strip, local to the field.
--- @return number
function FIELD:GetAlphaX()
    return self:GetHueX() + self.stripW + self.gap
end

--- Paints the cube - the hue across it at every saturation, taken down to black
--- by the foot of it.
--- The cube is drawn rather than an image of one being shown, so where a colour
--- lands in it and what comes back out of it are the one mapping read both ways
--- rather than a curve measured off a picture.
--- @param x number Left of the cube.
--- @param y number Top of it.
--- @param hue number Degrees, the hue the whole cube is in.
--- @param alpha number 0 to 1, the widget's own opacity.
function FIELD:PaintCube(x, y, hue, alpha)
    local w, h = self.cubeW, self.cubeH

    --> A column for every pixel across, each one the hue at that much
    --> saturation, so the left of the cube is the hue itself and the right of it
    --> is white. Measured from the middle of a column rather than its edge,
    --> which is where a pick lands when it reads the saturation back off it.
    for i = 0, w - 1 do
        local colour = occ.hsv(hue, 1 - (i + 0.5) / w, 1)

        surface.SetDrawColor(colour[1], colour[2], colour[3], 255 * alpha)
        surface.DrawRect(x + i, y, 1, h)
    end

    --> Black over the lot of it, solid along the foot and gone by the top.
    --> gradient-up is a straight ramp, so a row t of the way down is left with
    --> 1 - t of the colour under it - the value, drawn in one pass rather than
    --> worked out a row at a time.
    surface.SetDrawColor(0, 0, 0, 255 * alpha)
    surface.SetMaterial(occ.material("gradient-up"))
    surface.DrawTexturedRect(x, y, w, h)
end

--- Paints the hue strip, red at the top and the whole way round back to red.
--- @param x number Left of the strip.
--- @param y number Top of it.
--- @param alpha number 0 to 1, the widget's own opacity.
function FIELD:PaintHue(x, y, alpha)
    local h = self.cubeH

    for i = 0, h - 1 do
        local colour = occ.hsv((i + 0.5) / h * 360, 1, 1)

        surface.SetDrawColor(colour[1], colour[2], colour[3], 255 * alpha)
        surface.DrawRect(x, y + i, self.stripW, 1)
    end
end

--- Paints the checks a transparency bar is shown over.
--- @param x number Left of the strip.
--- @param y number Top of it.
--- @param alpha number 0 to 1, the widget's own opacity.
function FIELD:PaintChecker(x, y, alpha)
    local style = occ.style.colorpicker
    local size = style.checkersize
    local w, h = self.stripW, self.cubeH

    --> The lighter of the two across the lot, and the darker laid over every
    --> other square of it. The squares along the right and the foot are cut
    --> down to what is left of the strip rather than running past it.
    local light, dark = style.checker, style.checkeralt

    surface.SetDrawColor(light[1], light[2], light[3], light[4] * alpha)
    surface.DrawRect(x, y, w, h)

    surface.SetDrawColor(dark[1], dark[2], dark[3], dark[4] * alpha)

    for row = 0, math.ceil(h / size) - 1 do
        for column = 0, math.ceil(w / size) - 1 do
            if (row + column) % 2 == 1 then
                local cx, cy = column * size, row * size

                surface.DrawRect(x + cx, y + cy, math.min(size, w - cx), math.min(size, h - cy))
            end
        end
    end
end

--- Paints the alpha strip, the colour in full at the top and none of it left by
--- the bottom, over the checks so what is gone from it is seen to be gone.
--- @param x number Left of the strip.
--- @param y number Top of it.
--- @param colour table The colour with no alpha on it - the strip is what says
--- how much of it there is, so it has to be shown in full here.
--- @param alpha number 0 to 1, the widget's own opacity.
function FIELD:PaintAlpha(x, y, colour, alpha)
    self:PaintChecker(x, y, alpha)

    surface.SetDrawColor(colour[1], colour[2], colour[3], 255 * alpha)
    surface.SetMaterial(occ.material("gradient-down"))
    surface.DrawTexturedRect(x, y, self.stripW, self.cubeH)
end

--- Draws the mark across a strip saying where on it the pick is.
--- A line rather than a crosshair - there is only the one way to move on a
--- strip.
--- @param x number Left of the strip.
--- @param y number Top of it.
--- @param t number 0 to 1, how far down it the mark goes.
--- @param alpha number 0 to 1, the widget's own opacity.
function FIELD:PaintMark(x, y, t, alpha)
    local outside = occ.style.border.window
    local my = math.floor(y + t * self.cubeH)

    surface.SetDrawColor(outside[1], outside[2], outside[3], outside[4] * alpha)
    surface.DrawRect(x - 1, my - 1, self.stripW + 2, 3)

    surface.SetDrawColor(255, 255, 255, 255 * alpha)
    surface.DrawRect(x, my, self.stripW, 1)
end

--- Paints the cube, the two strips and the marks on them.
--- @param x number
--- @param y number
--- @param w number
--- @param h number
function FIELD:Paint(x, y, w, h)
    local alpha = self:GetAbsoluteAlpha() / 255
    local outside = occ.style.border.window
    local inside = occ.style.border.base
    local picker = self.picker

    --> Where the colour is this instant rather than where it was picked, so an
    --> animated one takes the cube, the strips and the marks along with it.
    local hue, sat, val = picker:GetAnimatedHSV()

    local hx = x + self:GetHueX()
    local ax = x + self:GetAlphaX()

    self:PaintCube(x, y, hue, alpha)
    self:PaintHue(hx, y, alpha)
    self:PaintAlpha(ax, y, occ.hsv(hue, sat, val), alpha)

    -- "outside" and "inside" borders, round all three of them
    for _, at in ipairs({x, hx, ax}) do
        local width = at == x and self.cubeW or self.stripW

        surface.SetDrawColor(outside[1], outside[2], outside[3], outside[4] * alpha)
        surface.DrawOutlinedRect(at - 1, y - 1, width + 2, self.cubeH + 2)

        surface.SetDrawColor(inside[1], inside[2], inside[3], inside[4] * alpha)
        surface.DrawOutlinedRect(at, y, width, self.cubeH)
    end

    --> Where the colour sits in the cube, which is the other way round from how
    --> pressing it works out the colour. A pulse takes the crosshair down the
    --> cube and a rainbow runs the mark down the hue strip, which is what each
    --> of them is doing to the colour.
    local size = self.crosshair

    surface.SetDrawColor(255, 255, 255, 255 * alpha)
    surface.SetMaterial(occ.material("colorpicker-crosshair"))
    surface.DrawTexturedRect(
        x + (1 - sat) * self.cubeW - size * 0.5,
        y + (1 - val) * self.cubeH - size * 0.5,
        size, size)

    self:PaintMark(hx, y, (hue % 360) / 360, alpha)
    self:PaintMark(ax, y, 1 - picker.colorAlpha, alpha)
end

--- Is a point on the piece of the field that starts at a local x and runs for a
--- width? Every piece is the full height of the field, so only the width of the
--- one being asked about has to be said.
--- @param mx number
--- @param my number
--- @param at number Left of the piece, local to the field.
--- @param w number Width of it.
--- @return boolean
function FIELD:IsInPiece(mx, my, at, w)
    local x, y = self:GetAbsolutePos()

    at = x + at

    return mx >= at and mx <= at + w and my >= y and my <= y + self.cubeH
end

--- Is a point on the cube?
--- @param mx number
--- @param my number
--- @return boolean
function FIELD:IsInCube(mx, my)
    return self:IsInPiece(mx, my, 0, self.cubeW)
end

--- Is a point on the hue strip?
--- @param mx number
--- @param my number
--- @return boolean
function FIELD:IsInHue(mx, my)
    return self:IsInPiece(mx, my, self:GetHueX(), self.stripW)
end

--- Is a point on the alpha strip?
--- @param mx number
--- @param my number
--- @return boolean
function FIELD:IsInAlpha(mx, my)
    return self:IsInPiece(mx, my, self:GetAlphaX(), self.stripW)
end

--- Takes the colour, the hue or the alpha from where the cursor is, whichever
--- of the three is being dragged.
--- @param mx number
--- @param my number
function FIELD:PickAt(mx, my)
    local x, y = self:GetAbsolutePos()
    local picker = self.picker

    --> Clamped, so a drag that wanders off the field keeps picking off its edge
    --> rather than stopping dead or running past the ends.
    local t = clamp((my - y) / self.cubeH, 0, 1)

    if self.dragging == "alpha" then
        picker:SetColorAlpha(1 - t)
        return
    end

    --> What was picked by hand rather than wherever an animation has got to - a
    --> drag on one of the three leaves the other two as they were.
    local hue, sat, val = picker:GetHSV()

    if self.dragging == "hue" then
        picker:SetHSV(t * 360, sat, val)
        return
    end

    --> Saturation across and value down, the way the cube is drawn - the hue
    --> is at the left of it and the white at the right, so the saturation runs
    --> the other way from the cursor.
    local u = clamp((mx - x) / self.cubeW, 0, 1)

    picker:SetHSV(hue, 1 - u, 1 - t)
end

--- Starts a drag on whichever of the three was pressed.
--- @param mx number
--- @param my number
--- @param key number
function FIELD:OnMousePressed(mx, my, key)
    if key ~= MOUSE_LEFT then return end

    if self:IsInCube(mx, my) then
        self.dragging = "cube"
    elseif self:IsInHue(mx, my) then
        self.dragging = "hue"
    elseif self:IsInAlpha(mx, my) then
        self.dragging = "alpha"
    else
        return
    end

    self:PickAt(mx, my)
end

--- Keeps picking while the cursor is held down.
--- @param mx number
--- @param my number
--- @param dx number
--- @param dy number
function FIELD:OnMouseMoved(mx, my, dx, dy)
    if not self.dragging then return end

    self:PickAt(mx, my)
end

--- Ends the drag.
--- @param mx number
--- @param my number
--- @param key number
function FIELD:OnMouseReleased(mx, my, key)
    if key ~= MOUSE_LEFT then return end

    self.dragging = nil
end

--[[
    The picker - the square of colour and the label beside it.
]]

--- Initializes the colorpicker.
function COLORPICKER:Init()
    self.name = "colorpicker"

    self.w = 100
    self.h = 16

    --- Text beside the square.
    self.text = ""

    --- Size of the block the colour is shown in, the outline round it and the
    --- band inside that included. The outline takes a pixel and the band two,
    --- either side and top and bottom, so 24 by 11 leaves 18 by 5 of colour.
    self.swatchW = 24
    self.swatchH = 11

    --- Width of the band round the colour, drawn in half the colour's own
    --- brightness so the block is framed by a darker shade of what it holds.
    self.swatchShade = 2

    --- Space between the square and its text.
    self.spacing = 6

    --- The colour, kept as it is picked rather than as red, green and blue - the
    --- cube works in these, and going back and forth would lose the hue of a
    --- colour with nothing left of it.
    --> Not self.alpha - that one is the widget's own opacity, on base, and
    --> naming this the same would have the whole picker drawn at 1 of 255.
    self.hue = 0
    self.sat = 1
    self.val = 1
    self.colorAlpha = 1

    --- What the colour does once it has been picked - "none" for nothing,
    --- "rainbow" to run it round the hues, "pulse" to take it down the value
    --- and back up, which is the way the cube runs from the colour at its top
    --- to black at its bottom.
    self.animation = "none"

    --- How quickly it does it. One turn of the hues every six seconds at 1, a
    --- pulse a second at 1, and twice that at 2.
    self.rate = 1

    --- Font it draws with, a name occ.font knows, nil for the one the style
    --- picks.
    self.font = nil

    --- Has it been measured since the text last changed?
    self.sized = false

    self.popup = nil
    self.field = nil
end

--- Makes the popup and the two pages on it, the first time one is wanted.
--- The cube goes on one and what the colour does once it is picked on the
--- other, a group being what the menu tabs anything with.
--- @return table popup
function COLORPICKER:GetPopup()
    if self.popup then return self.popup end

    local picker = self

    self.popup = occ.popup()

    --> The group on it carries an accent bar of its own, so the popup's is left
    --> off rather than the two being stacked one over the other.
    self.popup.accent = false

    local tabs = occ.group(self.popup, "Palette", "Animations")

    local field = occ.create("colorfield", tabs:GetPage("Palette"))

    field.picker = self

    self.field = field
    self.tabs = tabs

    --> The group is sized to the field rather than the field to the group - the
    --> cube and its strips are drawn at a size of their own, so what holds them
    --> is what has to give.
    tabs:SetPos(self.popup.padding, self.popup.padding)
    tabs:SetSize(
        field.w + tabs.sidemargin * 2 + tabs.padding * 2,
        field.h + tabs.tabHeight + tabs.margin * 2 + tabs.padding * 2)

    local animations = tabs:GetPage("Animations")

    --> One animation at a time, so ticking either box unticks the other. The
    --> boxes are what say which is on rather than the picker being asked, so
    --> the two stay in step whichever of them was pressed.
    local rainbow = occ.checkbox("Rainbow", animations)
    local pulse = occ.checkbox("Pulse", animations)

    rainbow.OnChange = function(_, checked)
        if checked then
            pulse:SetChecked(false)
        end

        picker:SetAnimation(checked and "rainbow" or pulse:GetChecked() and "pulse" or "none")
    end

    pulse.OnChange = function(_, checked)
        if checked then
            rainbow:SetChecked(false)
        end

        picker:SetAnimation(checked and "pulse" or rainbow:GetChecked() and "rainbow" or "none")
    end

    --> The popup is made the first time it is opened, so whatever was set from
    --> code before then has to be shown on it here.
    rainbow:SetChecked(self.animation == "rainbow")
    pulse:SetChecked(self.animation == "pulse")

    self.rainbowbox = rainbow
    self.pulsebox = pulse

    local rate = occ.slider("Speed", animations)

    rate:SetRange(0, 5)
    rate:SetStep(0.1)
    rate:SetDecimals(1)
    rate:SetValue(self.rate)

    rate:OnChange(function(_, value)
        picker:SetRate(value)
    end)

    self.ratebox = rate

    return self.popup
end

--- Sets what the colour does once it has been picked.
--- While one is on, occ.tickpickers pushes the colour to OnChange every frame,
--- whether the overlay is open or the picker can be seen.
--- @param name string|nil "none", "rainbow" or "pulse".
function COLORPICKER:SetAnimation(name)
    name = name or "none"

    if self.animation == name then return end

    self.animation = name

    if name == "none" then
        animating[self] = nil
    else
        animating[self] = true
    end

    --> Set from code - a config load, say - the boxes on the popup have to
    --> follow, or they show the old animation. Their OnChange comes back here
    --> and stops at the check above.
    if self.rainbowbox then
        self.rainbowbox:SetChecked(name == "rainbow")
        self.pulsebox:SetChecked(name == "pulse")
    end

    self:OnChange(self:GetColor())
end

--- Gets what the colour does once it has been picked.
--- @return string name
function COLORPICKER:GetAnimation()
    return self.animation
end

--- Sets how quickly the animation runs.
--- @param rate number
function COLORPICKER:SetRate(rate)
    rate = math.max(0, rate)

    if self.rate == rate then return end

    self.rate = rate

    --> Same as the boxes: the slider follows a rate set from code. Its
    --> OnChange comes back here and stops at the check above.
    if self.ratebox then
        self.ratebox:SetValue(rate)
    end
end

--- Gets how quickly the animation runs.
--- @return number rate
function COLORPICKER:GetRate()
    return self.rate
end

--- Takes the height of whichever is taller, the square or its text.
--- The width is left to whatever put the picker where it is.
function COLORPICKER:PerformLayout()
    if self.sized then return end

    local _, th = self:Measure()

    self.sized = true

    if self.h == th then return end

    self.h = th

    --> Whatever is laying the picker out goes by its height, and
    --> InvalidateLayout stops at a widget already waiting for a layout - which
    --> this one is, being in the middle of its own - so the parent is told from
    --> here.
    if self.parent then
        self.parent:InvalidateLayout()
    end
end

--- Paints the square and the label.
--- @param x number
--- @param y number
--- @param w number
--- @param h number
function COLORPICKER:Paint(x, y, w, h)
    local alpha = self:GetAbsoluteAlpha() / 255
    local style = occ.style.colorpicker
    local border = occ.style.border.window
    local sw, sh = self.swatchW, self.swatchH

    local sy = y + (h - sh) * 0.5

    local colour = self:GetColor()
    local shade = occ.shcolor(50, colour)

    --> The colour is banded rather than flat - half of it round the outside and
    --> the whole of it in the middle, with the block's own outline round the
    --> pair of them.
    local inset = 1 + self.swatchShade

    --> Something behind each of them, so a colour with little alpha on it is
    --> seen against something rather than against whatever happens to be there,
    --> and the middle is seen against that rather than against the band.
    surface.SetDrawColor(style.swatch[1], style.swatch[2], style.swatch[3], style.swatch[4] * alpha)
    surface.DrawRect(x, sy, sw, sh)

    surface.SetDrawColor(shade[1], shade[2], shade[3], shade[4] * alpha)
    surface.DrawRect(x, sy, sw, sh)

    surface.SetDrawColor(style.swatch[1], style.swatch[2], style.swatch[3], style.swatch[4] * alpha)
    surface.DrawRect(x + inset, sy + inset, sw - inset * 2, sh - inset * 2)

    surface.SetDrawColor(colour[1], colour[2], colour[3], colour[4] * alpha)
    surface.DrawRect(x + inset, sy + inset, sw - inset * 2, sh - inset * 2)

    surface.SetDrawColor(border[1], border[2], border[3], border[4] * alpha)
    surface.DrawOutlinedRect(x, sy, sw, sh)

    surface.SetFont(occ.font(self:GetFont()))

    local text = self.hovered and style.texthovered or style.text
    local _, th = surface.GetTextSize(self.text)

    surface.SetTextColor(text[1], text[2], text[3], text[4] * alpha)
    surface.SetTextPos(x + sw + self.spacing, y + (h - th) * 0.5)
    surface.DrawText(self.text)
end

--- Measures the square and its text together.
--- @return number w
--- @return number h
function COLORPICKER:Measure()
    surface.SetFont(occ.font(self:GetFont()))

    local tw, th = surface.GetTextSize(self.text)

    return self.swatchW + self.spacing + tw, math.max(self.swatchH, th)
end

--- Sizes the picker to its square and text, width and all.
function COLORPICKER:SizeToContents()
    local w, h = self:Measure()

    self.sized = true

    self:SetSize(w, h)
end

--- Gets the colour as it stands this instant, in the hue, saturation and value
--- the cube works in - an animated one is somewhere else a moment later.
--- What was picked by hand is left alone underneath, so turning an animation
--- off hands back the colour that went into it rather than wherever it had got
--- to when it stopped.
--- @return number hue
--- @return number sat
--- @return number val
function COLORPICKER:GetAnimatedHSV()
    local hue, sat, val = self.hue, self.sat, self.val

    if self.animation == "rainbow" then
        --> A turn of 60 degrees a second for every point of the rate, so the
        --> whole way round takes six seconds at 1.
        hue = (hue + SysTime() * self.rate * 60) % 360
    elseif self.animation == "pulse" then
        --> Down the value and back up it on a cosine, so it runs from the
        --> colour to black and back without turning round on a corner. The cube
        --> reads the same way down, which is what makes this the pick sliding
        --> from the top of it to the bottom.
        val = val * (0.5 + 0.5 * math.cos(SysTime() * self.rate * math.pi * 2))
    end

    return hue, sat, val
end

--- Gets the colour picked, alpha and all, as it stands this instant.
--- @return color
function COLORPICKER:GetColor()
    local hue, sat, val = self:GetAnimatedHSV()

    return occ.hsv(hue, sat, val, math.floor(self.colorAlpha * 255 + 0.5))
end

--- Sets the colour from one made with occ.color, alpha and all.
--- @param colour table
function COLORPICKER:SetColor(colour)
    self:SetHSV(occ.tohsv(colour))
    self:SetColorAlpha((colour[4] or 255) / 255)
end

--- Sets the colour by hue, saturation and value.
--- @param hue number Degrees, 0 to 360.
--- @param sat number 0 to 1.
--- @param val number 0 to 1.
function COLORPICKER:SetHSV(hue, sat, val)
    if self.hue == hue and self.sat == sat and self.val == val then return end

    self.hue, self.sat, self.val = hue, sat, val

    self:OnChange(self:GetColor())
end

--- Gets the colour as it is held, which is what the cube works in.
--- @return number hue
--- @return number sat
--- @return number val
function COLORPICKER:GetHSV()
    return self.hue, self.sat, self.val
end

--- Sets how much of the colour there is.
--- Not SetAlpha - that one is the widget's own opacity, on base, and taking its
--- name would leave the picker itself drawn at 1 of 255.
--- @param alpha number 0 to 1.
function COLORPICKER:SetColorAlpha(alpha)
    alpha = math.min(math.max(alpha, 0), 1)

    if self.colorAlpha == alpha then return end

    self.colorAlpha = alpha

    self:OnChange(self:GetColor())
end

--- Gets how much of the colour there is.
--- @return number alpha 0 to 1.
function COLORPICKER:GetColorAlpha()
    return self.colorAlpha
end

--- Sets what the picker does when the colour changes, or does it.
--- Handed a function it takes that function on. Handed a colour it runs the one
--- it was given, which is how a pick gets there.
---     picker:OnChange(function(self, colour) ... end)
--- Replacing the method outright still works and takes the place of both.
--- @param callback function|table|nil
function COLORPICKER:OnChange(callback)
    if type(callback) == "function" then
        self.callback = callback
        return
    end

    if self.callback then
        self.callback(self, callback)
    end
end

--- Sets the text beside the square.
--- @param text string
function COLORPICKER:SetText(text)
    if self.text == text then return end

    self.text = text
    self.sized = false

    self:InvalidateLayout()
end

--- Gets the text beside the square.
--- @return string text
function COLORPICKER:GetText()
    return self.text
end

--- Sets the font the text draws with.
--- @param font string|nil Name occ.font knows, nil for the style's own.
function COLORPICKER:SetFont(font)
    if self.font == font then return end

    self.font = font
    self.sized = false

    self:InvalidateLayout()
end

--- Gets the font the text draws with.
--- @return string font
function COLORPICKER:GetFont()
    return self.font or occ.style.colorpicker.font
end

--- Is a point on the square?
--- @param mx number
--- @param my number
--- @return boolean
function COLORPICKER:IsInSwatch(mx, my)
    local x, y = self:GetAbsolutePos()
    local sw, sh = self.swatchW, self.swatchH
    local sy = y + (self.h - sh) * 0.5

    return mx >= x and mx <= x + sw and my >= sy and my <= sy + sh
end

--- Brings the popup up under the square.
function COLORPICKER:OpenPopup()
    local popup = self:GetPopup()
    local x, y = self:GetAbsolutePos()

    popup:Open(x, y + self.h + 2)
end

--- Takes the popup back down.
function COLORPICKER:ClosePopup()
    if not self.popup then return end

    self.popup:Close()
end

--- Is the popup up?
--- @return boolean
function COLORPICKER:IsOpen()
    return self.popup ~= nil and self.popup:IsOpen()
end

--- Brings the popup up when the square is pressed.
--- Only the square - the label beside it is not a button.
--- @param mx number
--- @param my number
--- @param key number
function COLORPICKER:OnMousePressed(mx, my, key)
    if key ~= MOUSE_LEFT then return end
    if not self:IsInSwatch(mx, my) then return end

    if self:IsOpen() then
        self:ClosePopup()
        return
    end

    self:OpenPopup()
end

--- Creates a colorpicker.
--- @param text string|nil Text beside the square, also used as its name.
--- @param parent table|nil Widget to parent it to, occ.root by default.
--- @return table colorpicker
function occ.colorpicker(text, parent)
    local picker = occ.create("colorpicker", parent or occ.root)

    if text then
        picker:SetName(text)
        picker:SetText(text)
    end

    return picker
end
