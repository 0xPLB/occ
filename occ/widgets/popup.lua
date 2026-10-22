--[[
    popup.lua
    A panel that comes up over everything else and goes away again when it is
    clicked off. It is top level rather than a child of whatever opened it, so
    nothing it is put over can clip it or draw on top of it.

    Example:
    root (base)
    |_popup
     |_whatever is being shown
]]

local POPUP = occ.register("popup", "base")

local tween = lje.include("backend/tween.lua")

local SysTime = SysTime or lje.secure.pull("SysTime", lje.state.menu)

--- Initializes the popup.
function POPUP:Init()
    self.name = "popup"

    self.w = 200
    self.h = 150

    --- Space between the borders and what is on it.
    self.padding = 4

    --- Does it carry the accent bar along its top, the way a window and a group
    --- do? A popup holding something with a bar of its own - the group on a
    --- colour picker's - is better off without a second one stacked over it.
    self.accent = true

    --> Nothing is up until something opens it.
    self.visible = false

    --- Was the mouse held last frame? A popup goes away on a press off it, and
    --- telling a press from a hold is what stops it going away on the very press
    --- that opened it.
    self.wasdown = false

    --- Is it meant to be up? Not the same as it being on screen - one on its
    --- way out is still there until it has faded.
    self.opened = false

    --- Seconds it takes to fade in or out, nil for the one the style picks, 0
    --- for no fade at all.
    self.fadetime = nil

    --- The fade it is part way through, nil once it has settled.
    self.animation = nil

    --- Asked before the popup goes down, nil for none. Handed back false the
    --- popup stays up, and whatever said no is the one that takes it down - by
    --- closing it with force - once it is ready. A list that rolls back up into
    --- the box it came out of rather than blinking out is what this is for.
    self.holdclose = nil

    self.lastthink = SysTime()
end

--- Seconds it takes to fade in or out.
--- @return number
function POPUP:GetFadeTime()
    return self.fadetime or occ.style.popup.fadetime
end

--- Fades the popup towards an alpha, or puts it straight there when it is set
--- to not fade at all.
--- @param alpha number Alpha to end on, 0 to 255.
function POPUP:Fade(alpha)
    local time = self:GetFadeTime()

    if time > 0 then
        --> Carries on from the alpha it is at, so opening one part way through
        --> its own fade out picks up rather than starting over.
        self.animation = tween.new(time, self, {alpha = alpha}, "outQuad")
        return
    end

    self.animation = nil

    self:SetAlpha(alpha)
    self:SetVisible(alpha > 0)
end

--- Where what is on the popup starts from the top of it, below the accent bar
--- and the line under it when it carries one.
--- @return number
function POPUP:GetContentTop()
    return (self.accent and 4 or 0) + self.padding
end

--- Sizes the popup to what is on it.
function POPUP:PerformLayout()
    local pad = self.padding
    local w, h = 0, 0

    for _, child in ipairs(self.children) do
        w = math.max(w, child.x + child.w)
        h = math.max(h, child.y + child.h)
    end

    --> What is on it is placed at the padding by whatever put it there, so the
    --> far side only needs the one padding added back on.
    w = w + pad
    h = h + pad

    if self.w == w and self.h == h then return end

    self:SetSize(w, h)
end

--- Drives the fade, and closes the popup when something is clicked off it.
function POPUP:Think()
    local now = SysTime()

    --> Capped the way the other widgets cap theirs, so a long gap between
    --> frames does not throw the fade straight to the end.
    local dt = math.min(now - self.lastthink, 0.25)

    self.lastthink = now

    local animation = self.animation

    if animation and animation:update(dt) then
        self.animation = nil

        --> Faded out for good - off the screen and out of the hit test.
        if self:GetAlpha() <= 0 then
            self:SetVisible(false)
        end
    end

    --> One on its way out has stopped listening, so the click that is taking it
    --> down is not read a second time by what is left of it.
    if not self.opened then return end

    local down = occ.mousedown()
    local pressed = down and not self.wasdown

    self.wasdown = down

    if pressed and not self:IsInBounds(occ.mousepos()) then
        self:Close()
    end
end

--- Holds what is on the popup inside it.
--- The frame is drawn before this bites, so what is clipped is the content and
--- nothing else - a list rolling down is cut off by the popup's own edge rather
--- than spilling out under it.
--- @return number x
--- @return number y
--- @return number w
--- @return number h
function POPUP:GetClipBounds()
    local x, y = self:GetAbsolutePos()

    return x, y, self.w, self.h
end

--- Paints the popup.
--- @param x number
--- @param y number
--- @param w number
--- @param h number
function POPUP:Paint(x, y, w, h)
    local alpha = self:GetAbsoluteAlpha() / 255
    local style = occ.style.popup
    local outside = occ.style.border.window
    local inside = occ.style.border.base

    surface.SetDrawColor(style.background[1], style.background[2], style.background[3], style.background[4] * alpha)
    surface.DrawRect(x, y, w, h)

    --> The inside border starts under the accent bar when there is one, the
    --> way a window's does, rather than being drawn across it.
    local top = self.accent and 4 or 1

    if self.accent then
        local accent = occ.style.accent

        -- top accent bar
        surface.SetDrawColor(accent[1], accent[2], accent[3], accent[4] * alpha)
        surface.DrawRect(x, y, w, 3)

        --> The border goes over the top row of it, so two are left on show. The
        --> lower of them is taken down to half the accent, which gives the bar a
        --> lit edge and a shaded one rather than one flat band of colour.
        local shade = occ.shcolor(50, accent)

        surface.SetDrawColor(shade[1], shade[2], shade[3], shade[4] * alpha)
        surface.DrawRect(x, y + 2, w, 1)

        -- top accent bar bottom line
        surface.SetDrawColor(outside[1], outside[2], outside[3], outside[4] * alpha)
        surface.DrawRect(x, y + 3, w, 1)
    end

    -- "inside" border
    surface.SetDrawColor(inside[1], inside[2], inside[3], inside[4] * alpha)
    surface.DrawOutlinedRect(x + 1, y + top, w - 2, h - top - 1)

    -- "outside" border
    surface.SetDrawColor(outside[1], outside[2], outside[3], outside[4] * alpha)
    surface.DrawOutlinedRect(x, y, w, h)
end

--- Brings the popup up, over everything else.
--- @param x number|nil Where to put it, left where it is by default.
--- @param y number|nil
function POPUP:Open(x, y)
    if x and y then
        self:SetPos(x, y)
    end

    self.opened = true

    --> One that is already on screen carries on from the alpha it is at, so
    --> opening it again part way through a fade picks up rather than restarts.
    if not self:IsVisible() then
        self:SetAlpha(0)
        self:SetVisible(true)
    end

    self:MoveToFront()

    --> The press that opened it is almost always still held. Taking it as held
    --> rather than as a fresh press keeps Think from closing the popup on the
    --> same click that opened it.
    self.wasdown = occ.mousedown()

    self:Fade(255)
end

--- Takes the popup back down.
--- @param force boolean|nil Take it down whatever is holding it up.
function POPUP:Close(force)
    --> Whatever is on the popup gets to hold it up while it animates its way
    --> out. It is then the one that closes the popup, with force, at the end of
    --> that - so every way down, the button and a click off it alike, runs
    --> through the same animation.
    if not force and self.holdclose and self.holdclose(self) == false then return end

    self.opened = false

    self:Fade(0)
end

--- Is the popup up?
--- @return boolean
function POPUP:IsOpen()
    return self.opened
end

--- Brings it up if it is down, and down if it is up.
--- @param x number|nil Where to put it when it goes up.
--- @param y number|nil
function POPUP:Toggle(x, y)
    if self.opened then
        self:Close()
        return
    end

    self:Open(x, y)
end

--- Creates a popup.
--- @param parent table|nil Widget to parent it to, occ.root by default - it is
--- meant to be top level, so there is rarely a reason to pass anything else.
--- @return table popup
function occ.popup(parent)
    return occ.create("popup", parent or occ.root)
end
