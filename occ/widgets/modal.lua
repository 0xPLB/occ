--[[
    modal.lua
    A window that holds everything else off while it is up. The screen behind it
    is laid over with a dark sheet, and nothing under that sheet can be clicked
    until the modal goes down again.

    It is a window in every other way - the same frame, title bar and accent,
    dragged by its title and resized by its corner, and anything parented to it
    is laid out the way a window lays it out. The first group handed to it takes
    its main content area, and with no groups it stacks what it holds.

    Example:
    root (base)
    |_modal
     |_other widgets

    It is meant to be top level. The sheet is drawn from the top of the tree it
    hangs off, so one parented inside something that clips has its sheet cut off
    at that thing's edges.
]]

local MODAL = occ.register("modal", "window")

local tween = lje.include("backend/tween.lua")

local MOUSE_LEFT = MOUSE_LEFT or 107

local SysTime = SysTime or lje.secure.pull("SysTime", lje.state.menu)

--- Initializes the modal.
function MODAL:Init()
    self.name = "modal"
    self.title = "modal"

    self.w = 300
    self.h = 180

    --> Nothing is up until something opens it.
    self.visible = false

    --- Is it meant to be up? Not the same as it being on screen - one on its
    --- way out is still there until it has faded, and has already stopped
    --- holding the rest of the screen off.
    self.opened = false

    --- Is the dark sheet drawn behind it? Off, the modal still holds the rest
    --- of the screen off, it just does not dim it.
    self.overlay = true

    --- Colour of the sheet, alpha included, nil for the one the style picks.
    self.overlaycolor = nil

    --- Does a click on the sheet, off the window, take the modal down?
    self.dismissable = false

    --- Seconds it takes to fade in or out, nil for the one the style picks, 0
    --- for no fade at all.
    self.fadetime = nil

    --- The fade it is part way through, nil once it has settled.
    self.animation = nil

    --- Has it been put anywhere yet? The first time it opens without being told
    --- where, it goes in the middle of whatever it is on. After that it stays
    --- wherever it was dragged to.
    self.placed = false

    --- Is it waiting to be put in the middle? Opened before the first frame, the
    --- root has not been sized to the screen yet, so the centring is held off
    --- until the modal's next Think, by which time it has.
    self.centering = false

    --- Run when the modal goes down, nil for nothing.
    self.closecallback = nil
end

--- Seconds it takes to fade in or out.
--- @return number
function MODAL:GetFadeTime()
    return self.fadetime or occ.style.modal.fadetime
end

--- Fades the modal towards an alpha, or puts it straight there when it is set
--- to not fade at all.
--- @param alpha number Alpha to end on, 0 to 255.
function MODAL:Fade(alpha)
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

--- Drives the fade, and the scroll the window carries.
function MODAL:Think()
    --> Read off the window's clock before its own Think moves it on, so the
    --> fade and the scroll are stepped by the same time rather than the modal
    --> keeping a second clock of its own. Capped the way the window caps it.
    local dt = math.min(SysTime() - self.lastthink, 0.25)

    MODAL.BaseClass.Think(self)

    --> The render pass sizes the root to the screen before anything under it
    --> thinks, so by here the middle of the parent is the middle of the screen.
    if self.centering then
        self.centering = false

        self:Center()
    end

    local animation = self.animation

    if animation and animation:update(dt) then
        self.animation = nil

        --> Faded out for good - off the screen and out of the hit test.
        if self:GetAlpha() <= 0 then
            self:SetVisible(false)
        end
    end
end

--- The top of the tree the modal hangs off, which is what the sheet covers.
--- @return table
function MODAL:GetOverlayTarget()
    local top = self

    while top.parent do
        top = top.parent
    end

    return top
end

--- Paints the sheet over everything behind the modal, then the window on top.
--- A widget's own Paint is not clipped by it, and the root clips nothing, so
--- the sheet reaches the edges of the screen from here.
--- @param x number
--- @param y number
--- @param w number
--- @param h number
function MODAL:Paint(x, y, w, h)
    if self.overlay then
        local alpha = self:GetAbsoluteAlpha() / 255
        local colour = self:GetOverlayColor()
        local top = self:GetOverlayTarget()
        local tx, ty = top:GetAbsolutePos()

        surface.SetDrawColor(colour[1], colour[2], colour[3], colour[4] * alpha)
        surface.DrawRect(tx, ty, top.w, top.h)
    end

    MODAL.BaseClass.Paint(self, x, y, w, h)
end

--- Hit test.
--- Anything on the window is found the way it always is. Anywhere else, while
--- the modal is up, lands on the modal itself - that is what holds the rest of
--- the screen off, the widgets behind it never being handed the cursor.
--- @param mx number
--- @param my number
function MODAL:HitTest(mx, my)
    local hit = MODAL.BaseClass.HitTest(self, mx, my)

    if hit then return hit end

    if self.visible and self.opened then
        return self
    end

    return nil
end

--- Takes the modal down on a click off it when it is set to, and otherwise
--- does what a window does with a press.
--- @param mx number
--- @param my number
--- @param key number
function MODAL:OnMousePressed(mx, my, key)
    if not self:IsInBounds(mx, my) then
        if key == MOUSE_LEFT and self.dismissable then
            self:Close()
        end

        return
    end

    MODAL.BaseClass.OnMousePressed(self, mx, my, key)
end

--- Scrolls the content when the wheel is turned over the window, and swallows
--- it anywhere else - the sheet is in the way of whatever is behind it.
--- @param delta number
--- @return boolean|nil handled
function MODAL:OnMouseWheeled(delta)
    if not self:IsInBounds(occ.mousepos()) then
        return true
    end

    return MODAL.BaseClass.OnMouseWheeled(self, delta)
end

--- Puts the modal in the middle of whatever it is on.
function MODAL:Center()
    local parent = self.parent

    if not parent then return end

    self:SetPos(
        math.floor((parent.w - self.w) * 0.5 + 0.5),
        math.floor((parent.h - self.h) * 0.5 + 0.5))

    self.placed = true
end

--- Brings the modal up, over everything else.
--- @param x number|nil Where to put it. Left out, it goes in the middle the
--- first time it opens and stays where it was left every time after.
--- @param y number|nil
function MODAL:Open(x, y)
    if x and y then
        self:SetPos(x, y)
        self.placed = true
        self.centering = false
    elseif not self.placed then
        self:Center()

        --> Done again on the next Think, once whatever it is on has its real
        --> size - a modal opened as the script loads would otherwise go in the
        --> middle of a root that is still the size a base widget starts at.
        self.centering = true
    end

    self.opened = true

    --> One that is already on screen carries on from the alpha it is at, so
    --> opening it again part way through a fade picks up rather than restarts.
    if not self:IsVisible() then
        self:SetAlpha(0)
        self:SetVisible(true)
    end

    self:MoveToFront()

    self:Fade(255)
end

--- Takes the modal back down. It stays on whatever it is on, unlike a window,
--- so it can be opened again as it was left.
function MODAL:Close()
    if not self.opened then return end

    self.opened = false
    self.dragging = false
    self.resizing = false

    self:Fade(0)

    if self.closecallback then
        self.closecallback(self)
    end
end

--- Is the modal up?
--- @return boolean
function MODAL:IsOpen()
    return self.opened
end

--- Brings it up if it is down, and down if it is up.
function MODAL:Toggle()
    if self.opened then
        self:Close()
        return
    end

    self:Open()
end

--- Sets what runs when the modal goes down.
---     modal:OnClose(function(self) ... end)
--- @param callback function|nil
function MODAL:OnClose(callback)
    self.closecallback = callback
end

--- Shows or hides the dark sheet behind the modal. Hidden, the rest of the
--- screen is still held off, just not dimmed.
--- @param overlay boolean
function MODAL:SetOverlay(overlay)
    self.overlay = overlay and true or false
end

--- Is the dark sheet drawn behind the modal?
--- @return boolean
function MODAL:HasOverlay()
    return self.overlay
end

--- Sets the colour of the sheet, alpha included.
---     modal:SetOverlayColor(occ.color(0, 0, 0, 200))
---     modal:SetOverlayColor(Color(0, 0, 0, 200))
---     modal:SetOverlayColor(0, 0, 0, 200)
--- @param colour table|number|nil One of occ.color's, one of the game's own
--- Color tables, or the red of four numbers. nil for the one the style picks.
--- @param g number|nil
--- @param b number|nil
--- @param a number|nil 255 when left out.
function MODAL:SetOverlayColor(colour, g, b, a)
    if type(colour) == "number" then
        colour = occ.color(colour, g, b, a)

    --> The game's Color keeps its channels by name rather than in order, and
    --> the sheet is drawn off colour[1] to colour[4] like every other colour
    --> in the menu - so it is copied across into one of those.
    elseif type(colour) == "table" and colour[1] == nil and colour.r then
        colour = occ.color(colour.r, colour.g, colour.b, colour.a)
    end

    self.overlaycolor = colour
end

--- Gets the colour of the sheet.
--- @return table colour
function MODAL:GetOverlayColor()
    return self.overlaycolor or occ.style.modal.overlay
end

--- Sets how dark the sheet is, keeping the colour it already has.
--- @param alpha number 0 to 255.
function MODAL:SetOverlayAlpha(alpha)
    local colour = self:GetOverlayColor()

    --> A copy rather than the style's own table, so darkening one modal does
    --> not darken every other one along with it.
    self.overlaycolor = occ.color(colour[1], colour[2], colour[3], alpha)
end

--- Sets whether a click on the sheet takes the modal down.
--- @param dismissable boolean
function MODAL:SetDismissable(dismissable)
    self.dismissable = dismissable and true or false
end

--- Does a click on the sheet take the modal down?
--- @return boolean
function MODAL:IsDismissable()
    return self.dismissable
end

--- Creates a modal. It starts down - Open is what brings it up.
--- @param title string|nil Title of the modal, also used as its name.
--- @param parent table|nil Widget to parent it to, occ.root by default.
--- @return table modal
function occ.modal(title, parent)
    local modal = occ.create("modal", parent or occ.root)

    if title then
        modal:SetName(title)
        modal:SetTitle(title)
    end

    return modal
end
