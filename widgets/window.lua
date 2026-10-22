--[[
    window.lua
    A draggable, titled frame that holds other widgets.

    Example:
    root (base)
    |_window
     |_other widgets
]]

local WINDOW = occ.register("window", "base")

local MOUSE_LEFT = MOUSE_LEFT or 107

local SysTime = SysTime or lje.secure.pull("SysTime", lje.state.menu)

--- Initializes the window.
function WINDOW:Init()
    self.name = "window"

    self.w = 400
    self.h = 300

    --- Title drawn in the title bar.
    self.title = "window"

    --- Height of the title bar.
    self.titleHeight = 19

    --- Gap between the "borders" and main content area 
    self.gap = 8

    --- Margin of the main content
    self.main_margin = 5

    --- Space between the groups sharing the main content area.
    self.spacing = 4

    --- Columns the groups sharing the main content area are dealt into.
    self.columns = 2

    --- Can the window be dragged by its title bar?
    self.draggable = true

    --- Is the window being dragged right now?
    self.dragging = false

    --- Cursor offset from the window origin while dragging.
    self.dragX = 0
    self.dragY = 0

    --- Can the window be resized by its bottom right corner?
    self.resizable = true

    --- Is the window being resized right now?
    self.resizing = false

    --- Cursor offset from the far corner while resizing.
    self.resizeX = 0
    self.resizeY = 0

    --- How far in from the bottom right corner the grab for a resize reaches.
    --- It sits in the frame the window paints, clear of anything on it.
    self.grip = 12

    --- How small a resize is allowed to leave the window.
    self.minw = 120
    self.minh = 100

    --- Widget filling the main content area, kept sized to it. The first group
    --- parented to the window claims it.
    self.main = nil

    --- Width of the bar down a window holding more than fits.
    self.scrollw = 4

    --- Pixels a notch of the wheel moves the content by.
    self.scrollstep = 32

    --- How quickly the content catches up with the wheel, per second, nil for
    --- the one the style picks.
    self.scrollspeed = nil

    --- How far down the content is, where it is heading, and how tall it came
    --- out. Only a stacked window scrolls - columns are sized to the area, so
    --- there is never anything of them left over.
    self.scroll = 0
    self.target = 0
    self.content = 0

    self.lastthink = SysTime()
end

--- Eases the scroll along.
function WINDOW:Think()
    local now = SysTime()

    --> Capped the same way a group caps its own, so a window that has not been
    --> drawn for a while does not jump the moment it comes back.
    local dt = math.min(now - self.lastthink, 0.25)

    self.lastthink = now

    local _, _, _, h = self:GetMainBounds()

    if occ.scrollstep(self, h, dt, self:GetScrollSpeed()) then
        self:InvalidateLayout()
    end
end

--- How quickly the content catches up with the wheel, per second.
--- @return number
function WINDOW:GetScrollSpeed()
    return self.scrollspeed or occ.style.scroll.speed
end

--- Scrolls the content, when there is more of it than fits.
--- @param delta number
--- @return boolean|nil handled
function WINDOW:OnMouseWheeled(delta)
    local _, _, _, h = self:GetMainBounds()

    return occ.scrollwheel(self, h, delta, self.scrollstep)
end

--- How far the content can be scrolled before it runs out.
--- @return number
function WINDOW:GetScrollMax()
    local _, _, _, h = self:GetMainBounds()

    return math.max(0, self.content - h)
end

--- Holds everything on the window inside the main content area.
--- The frame, title bar and borders are drawn before this bites, so what is
--- clipped is the content and nothing else.
--- @return number x
--- @return number y
--- @return number w
--- @return number h
function WINDOW:GetClipBounds()
    local x, y = self:GetAbsolutePos()
    local mx, my, mw, mh = self:GetMainBounds()

    return x + mx, y + my, mw, mh
end

--- Paints the window.
--- @param x number
--- @param y number
--- @param w number
--- @param h number
function WINDOW:Paint(x, y, w, h)
    local alpha = self:GetAbsoluteAlpha() / 255
    local style = occ.style.window
    local bstyle = occ.style.border
    local accent = occ.style.accent
    local th = self.titleHeight
    local gap = self.gap

    surface.SetDrawColor(style.background[1], style.background[2], style.background[3], style.background[4] * alpha)
    surface.DrawRect(x, y, w, h)

    surface.SetDrawColor(style.titlebar[1], style.titlebar[2], style.titlebar[3], style.titlebar[4] * alpha)
    surface.DrawRect(x, y, w, th)

    -- left
    surface.SetDrawColor(style.titlebar[1], style.titlebar[2], style.titlebar[3], style.titlebar[4] * alpha)
    surface.DrawRect(x, y, gap, h)

    -- bottom
    surface.SetDrawColor(style.titlebar[1], style.titlebar[2], style.titlebar[3], style.titlebar[4] * alpha)
    surface.DrawRect(x, y + h - gap, w, gap)

    -- right
    surface.SetDrawColor(style.titlebar[1], style.titlebar[2], style.titlebar[3], style.titlebar[4] * alpha)
    surface.DrawRect(x + w - gap, y, gap, h)

    -- gradient over the frame
    surface.SetDrawColor(33, 33, 33, 220 * alpha)
    surface.SetMaterial(occ.material("gradient-up"))

    --> One gradient spanning the whole window, drawn only where the frame is.
    --> Every piece samples its own slice of the texture, so the four of them
    --> read as a single gradient instead of four little ones.
    surface.DrawTexturedRectUV(x, y, w, th, 0, 0, 1, th / h)
    surface.DrawTexturedRectUV(x, y + th, gap, h - th, 0, th / h, gap / w, 1)
    surface.DrawTexturedRectUV(x + w - gap, y + th, gap, h - th, 1 - gap / w, th / h, 1, 1)
    surface.DrawTexturedRectUV(x + gap, y + h - gap, w - gap * 2, gap, gap / w, 1 - gap / h, 1 - gap / w, 1)

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
    surface.SetDrawColor(bstyle.window[1], bstyle.window[2], bstyle.window[3], bstyle.window[4] * alpha)
    surface.DrawRect(x, y + 3, w, 1)

    --> A row further down than it was, the accent having taken the one it used
    --> to start on. The foot of it is where it always was.
    -- "outside" border
    surface.SetDrawColor(bstyle.base[1], bstyle.base[2], bstyle.base[3], bstyle.base[4] * alpha)
    surface.DrawOutlinedRect(x + 1, y + 4, w - 2, h - 5)

    -- "inside" border
    surface.SetDrawColor(bstyle.window[1], bstyle.window[2], bstyle.window[3], bstyle.window[4] * alpha)
    surface.DrawOutlinedRect(
        x + gap + 1, 
        y + th + 1, 
        w - 2 - gap * 2, h - 2 - th - gap)
    
    -- "inside" "inside" border
    surface.SetDrawColor(bstyle.base[1], bstyle.base[2], bstyle.base[3], bstyle.base[4] * alpha)
    surface.DrawOutlinedRect(x + gap, y + th, w - gap * 2, h - th - gap)


    -- border for the window
    surface.SetDrawColor(bstyle.window[1], bstyle.window[2], bstyle.window[3], bstyle.window[4] * alpha)
    surface.DrawOutlinedRect(x, y, w, h)

    surface.SetFont(occ.font(style.font))
    surface.SetTextColor(style.text[1], style.text[2], style.text[3], style.text[4] * alpha)

    local _, tall = surface.GetTextSize(self.title)

    --> Down the middle of the title bar, 4px in from the left of it.
    surface.SetTextPos(x + 4, y + (th - tall) * 0.5 + 3)
    surface.DrawText(self.title)

    --> A bar down the right of the main area when there is more on the window
    --> than fits. Drawn before the content, which is why the layout keeps the
    --> content clear of it.
    local mx, my, mw, mh = self:GetMainBounds()
    local bw = self.scrollw

    occ.scrollbar(self, x + mx + mw - bw, y + my, bw, mh, alpha)
end

--- Sets the title of the window.
--- @param title string
function WINDOW:SetTitle(title)
    self.title = title
end

--- Gets the title of the window.
--- @return title string
function WINDOW:GetTitle()
    return self.title
end

--- Sets the height of the title bar.
--- @param h number
function WINDOW:SetTitleHeight(h)
    self.titleHeight = h
    self:InvalidateLayout()
end

--- Gets the height of the title bar.
--- @return number h
function WINDOW:GetTitleHeight()
    return self.titleHeight
end

--- Sets the gap between the borders and the main content area.
--- @param gap number
function WINDOW:SetGap(gap)
    self.gap = gap
    self:InvalidateLayout()
end

--- Gets the gap between the borders and the main content area.
--- @return number gap
function WINDOW:GetGap()
    return self.gap
end

--- Sets the margin of the main content area.
--- @param margin number
function WINDOW:SetMainMargin(margin)
    self.main_margin = margin
    self:InvalidateLayout()
end

--- Gets the margin of the main content area.
--- @return number margin
function WINDOW:GetMainMargin()
    return self.main_margin
end

--- The main content area, local to the window.
--- It is the space the title bar and the borders leave over, pulled in by the
--- main margin so it clears the inside border the window paints.
--- @return number x
--- @return number y
--- @return number w
--- @return number h
function WINDOW:GetMainBounds()
    local th = self.titleHeight
    local gap = self.gap
    local margin = self.main_margin

    local x = gap + margin
    local y = th + margin
    local w = self.w - (gap + margin) * 2
    local h = self.h - th - gap - margin * 2

    return x, y, math.max(0, w), math.max(0, h)
end

--- Puts a widget in the main content area, parenting it if it is not already.
--- @param widget table|nil Widget to fill the area with, nil to free it.
function WINDOW:SetMainContent(widget)
    self.main = widget

    --> SetParent comes back around through AddChild, which leaves the area
    --> alone because it is taken by this point.
    if widget and widget.parent ~= self then
        widget:SetParent(self)
    end

    self:InvalidateLayout()
end

--- Gets the widget filling the main content area.
--- @return table|nil main
function WINDOW:GetMainContent()
    return self.main
end

--- Lays the main content area out.
--- One group fills it, which is the main content widget doing what it always
--- did, and any after that share it column by column. A window with no groups
--- on it stacks whatever it does have from the top down instead.
function WINDOW:PerformLayout()
    local x, y, w, h = self:GetMainBounds()
    local main = self.main

    --> The main content area can be handed to a widget by hand, and one that is
    --> not a group has no column layout to take part in - it fills the area.
    if main and not occ.isa(main, "group") then
        if main.x ~= x or main.y ~= y then
            main:SetPos(x, y)
        end

        if main.w ~= w or main.h ~= h then
            main:SetSize(w, h)
        end

        self.content = h
        return
    end

    --> Groups share the area out between them. Nothing to share it between and
    --> the children go down it one under the next, at whatever height each of
    --> them is already.
    if occ.masonry(self, x, y, w, h, self.columns, self.spacing) == 0 then
        local cw = w

        --> The bar takes its width off the content rather than sitting over it,
        --> so nothing ends up underneath it.
        if self.content > h then
            cw = cw - self.scrollw
        end

        self.content = occ.stack(self, x, y - self.scroll, math.max(0, cw), self.spacing)
    else
        --> Columns are sized to the area, so there is never anything of them
        --> left over to scroll to.
        self.content = h
    end
end

--- Adds a child, handing the main content area to the first group.
--- @param widget table
function WINDOW:AddChild(widget)
    WINDOW.BaseClass.AddChild(self, widget)

    if self.main then return end

    --> AddChild turns down a widget it already holds, itself and nil, so the
    --> area only goes to one that actually ended up on the window.
    if not widget or widget.parent ~= self then return end
    if not occ.isa(widget, "group") then return end

    self:SetMainContent(widget)
end

--- Removes a child, freeing the main content area if it was filling it.
--- @param widget table
function WINDOW:RemoveChild(widget)
    WINDOW.BaseClass.RemoveChild(self, widget)

    if self.main == widget then
        self.main = nil
    end
end

--- Sets whether the window can be dragged by its title bar.
--- @param draggable boolean
function WINDOW:SetDraggable(draggable)
    self.draggable = draggable
end

--- Checks whether the window can be dragged by its title bar.
--- @return boolean draggable
function WINDOW:IsDraggable()
    return self.draggable
end

--- Sets whether the window can be resized by its bottom right corner.
--- @param resizable boolean
function WINDOW:SetResizable(resizable)
    self.resizable = resizable
end

--- Checks whether the window can be resized by its bottom right corner.
--- @return boolean resizable
function WINDOW:IsResizable()
    return self.resizable
end

--- Checks if a point is in the corner the window is resized by.
--- @param mx number
--- @param my number
--- @return boolean
function WINDOW:IsInResizeGrip(mx, my)
    local x, y = self:GetAbsolutePos()
    local grip = self.grip

    return mx >= x + self.w - grip and mx <= x + self.w
        and my >= y + self.h - grip and my <= y + self.h
end

--- Checks if a point is inside the title bar.
--- @param mx number
--- @param my number
--- @return boolean
function WINDOW:IsInTitleBar(mx, my)
    local x, y = self:GetAbsolutePos()

    return mx >= x and my >= y and mx <= x + self.w and my <= y + self.titleHeight
end

--- Closes the window, detaching it from its parent.
function WINDOW:Close()
    self:SetVisible(false)

    if self.parent then
        self.parent:RemoveChild(self)
    end
end

--- Starts dragging when the title bar is grabbed, or resizing when the corner
--- is.
--- @param mx number
--- @param my number
--- @param key number
function WINDOW:OnMousePressed(mx, my, key)
    if key ~= MOUSE_LEFT then return end

    self:MoveToFront()

    --> The corner is tried first. It sits in the frame rather than the title
    --> bar, so the two of them are never both answered by the one press.
    if self.resizable and self:IsInResizeGrip(mx, my) then
        local x, y = self:GetAbsolutePos()

        --> Held by how far the corner is from the cursor, so it stays where it
        --> was grabbed rather than snapping under it.
        self.resizing = true
        self.resizeX = x + self.w - mx
        self.resizeY = y + self.h - my

        return
    end

    if not self.draggable then return end
    if not self:IsInTitleBar(mx, my) then return end

    local x, y = self:GetAbsolutePos()

    self.dragging = true
    self.dragX = mx - x
    self.dragY = my - y
end

--- Stops dragging.
--- @param mx number
--- @param my number
--- @param key number
function WINDOW:OnMouseReleased(mx, my, key)
    if key ~= MOUSE_LEFT then return end

    self.dragging = false
    self.resizing = false
end

--- Drags or resizes the window, keeping the grab offset.
--- The cursor is captured on the press, so either one carries on while the
--- button is held whether or not the cursor is still over the window.
--- @param mx number
--- @param my number
--- @param dx number
--- @param dy number
function WINDOW:OnMouseMoved(mx, my, dx, dy)
    if self.resizing then
        local x, y = self:GetAbsolutePos()

        --> SetSize invalidates the layout, so whatever is on the window is
        --> dealt out again as it goes rather than when it is let go of.
        self:SetSize(
            math.max(self.minw, mx + self.resizeX - x),
            math.max(self.minh, my + self.resizeY - y)
        )

        return
    end

    if not self.dragging then return end

    --- Position is local to the parent, so the parent origin comes back off.
    local px, py = 0, 0

    if self.parent then
        px, py = self.parent:GetAbsolutePos()
    end

    self:SetPos(mx - self.dragX - px, my - self.dragY - py)
end

--- Creates a window.
--- @param title string|nil Title of the window, also used as its name.
--- @param parent table|nil Widget to parent it to, occ.root by default.
--- @return table window
function occ.window(title, parent)
    local window = occ.create("window", parent or occ.root)

    if title then
        window:SetName(title)
        window:SetTitle(title)
    end

    window:MoveToFront()

    return window
end
