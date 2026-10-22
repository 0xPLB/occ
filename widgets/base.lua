--[[
    base.lua
    The base element that every widget derives, also a root element in hierarchy.

    Example:
    root (base)
    |_window
     |_other widgets
]]

local BASE = occ.register("base")

local MOUSE_LEFT = MOUSE_LEFT or 107
local MOUSE_RIGHT = MOUSE_RIGHT or 108

--- Initializes the widget
--- Override this!
function BASE:Init()
    --- Name of the widget.
    self.name = "base"

    --- X position of the widget.
    self.x = 0

    --- Y position of the widget.
    self.y = 0

    --- Width of the widget.
    self.w = 100

    --- Height of the widget.
    self.h = 100

    --- Z-index of the widget.
    self.z = 0

    --- Where the widget came in the order its parent took its children on, the
    --- tie break between two of them sharing a z-index.
    self.order = 0

    --- Opacity (alpha) of the widget.
    self.alpha = 255

    --- Children of the widget.
    self.children = {}

    --- Parent of the widget.
    self.parent = nil

    --- Needs layout to perform?
    self.needsLayout = true

    --- Hovered state of the widget.
    self.hovered = false

    --- Visibility of the widget.
    self.visible = true

end

--- Think runs per frame.
--- Override this!
function BASE:Think() end

--- Paints the widget
--- Override this!
--- @param x number
--- @param y number
--- @param w number
--- @param h number
function BASE:Paint(x, y, w, h) end

--- The area, in screen space, the widget holds its children's drawing to.
--- Nothing is clipped by default. Override it to return a rect and the paint
--- pass scissors every child of this widget to it - the widget's own Paint is
--- left alone, so a frame can still be drawn around what is being clipped.
--- Rects nest, a child that clips as well only ever narrows its parent's.
--- *Override this!*
--- @return number|nil x
--- @return number|nil y
--- @return number|nil w
--- @return number|nil h
function BASE:GetClipBounds() end

--- Sets the alpha (opacity) of the widget.
--- @param alpha number (0-255)
function BASE:SetAlpha(alpha)
    self.alpha = alpha
end

--- Gets the alpha (opacity) of the widget.
--- @return alpha number
function BASE:GetAlpha()
    return self.alpha or 255
end

--- Checks the alpha of a parent widget.
--- @return alpha nubmer
function BASE:GetAbsoluteAlpha()
    local alpha = self:GetAlpha()
    local parent = self.parent

    while parent do
        alpha = alpha * (parent:GetAlpha() / 255)
        parent = parent.parent
    end

    return alpha
end

--- Performs a layout 
--- This is only used internally - do not touch this.
function BASE:PerformLayoutInternal()
    if self.needsLayout then
        self:PerformLayout()
        self.needsLayout = false
    end

    for _, child in ipairs(self.children) do
        child:PerformLayoutInternal()
    end
end

--- Performs a layout on widget.
--- *Override this!*
function BASE:PerformLayout() end

--- Invalidates the layout of a widget.
function BASE:InvalidateLayout()
    if self.needsLayout then return end

    self.needsLayout = true

    if self.parent then
        self.parent:InvalidateLayout()
    end
end

--- Sets the position of the widget.
function BASE:SetPos(x, y)
    self.x = x
    self.y = y
    self:InvalidateLayout()
end

--- Gets the position of a widget.
--- @return x number
--- @return y number
function BASE:GetPos()
    return self.x, self.y
end 

--- Returns the absolute position of a widget.
--- @return x number
--- @return y number
function BASE:GetAbsolutePos()
    local x, y = self.x, self.y
    local parent = self.parent

    while parent do
        x = x + parent.x
        y = y + parent.y
        parent = parent.parent
    end

    return x, y
end

--- Sets the size of the widget.
--- @param w number
--- @param h number
function BASE:SetSize(w, h)
    self.w = w 
    self.h = h
    self:InvalidateLayout()
end 

--- Gets the size of the widget.
--- @return number w 
--- @return number h
function BASE:GetSize()
    return self.w, self.h
end

--- Sets the width of the widget
--- @param w number
function BASE:SetWide(w)
    self.w = w
    self:InvalidateLayout()
end

--- Gets the width of the widget
--- @return number w 
function BASE:GetWide()
    return self.w
end

--- Sets the height of the widget.
--- @param h number
function BASE:SetTall(h)
    self.h = h
    self:InvalidateLayout()
end

--- Gets the height of the widget.
--- @return number h
function BASE:GetTall()
    return self.h
end

--- Sorts all children in widget for z-index.
function BASE:SortChildren()
    --> table.sort is not stable, so children sharing a z-index would come back
    --> in a different order every time another one is added. The order they
    --> were taken on in breaks the tie, which keeps both the order they are
    --> drawn in and anything laying them out from shuffling about.
    table.sort(self.children, function(a, b)
        if a.z ~= b.z then
            return a.z < b.z
        end

        return a.order < b.order
    end)
end

--- Sets the z-index of the widget.
--- @param z number
function BASE:SetZPos(z)
    self.z = z

    if self.parent then
        self.parent:SortChildren()
    end
end

--- Gets the z-index of the widget.
--- @return number z
function BASE:GetZPos()
    return self.z
end

--- Puts the widget above its siblings.
function BASE:MoveToFront()
    if not self.parent then return end

    local top = 0

    for _, child in ipairs(self.parent:GetChildren()) do
        if child ~= self and child.z > top then
            top = child.z
        end
    end

    self:SetZPos(top + 1)
end

--- Sets the visibility of the widget.
--- @param visible boolean
function BASE:SetVisible(visible)
    if self.visible == visible then return end

    self.visible = visible

    --> A layout can leave out a widget that is not showing, so hiding one is a
    --> change to the parent's layout rather than only to this widget.
    if self.parent then
        self.parent:InvalidateLayout()
    end
end

--- Gets the visibility status of the widget.
--- @return boolean visible
function BASE:IsVisible()
    return self.visible
end

--- Parents a widget.
--- @param widget table
function BASE:SetParent(widget)
    if self.parent == widget then return end

    if self.parent then
        self.parent:RemoveChild(self)
    end

    self.parent = widget

    if widget then
        widget:AddChild(self)
    end
end

--- Gets the widget's parent.
--- @return parent table
function BASE:GetParent()
    return self.parent
end

--- Adds a child to a widget. 
--- @param widget table
function BASE:AddChild(widget)
    if not widget then return end

    if widget == self then return end

    for _, child in ipairs(self.children) do
        if child == widget then return end
    end

    if widget.parent and widget.parent ~= self then
        widget.parent:RemoveChild(widget)
    end

    self.taken = (self.taken or 0) + 1

    table.insert(self.children, widget)

    widget.parent = self
    widget.order = self.taken

    self:SortChildren()

    --> A widget lays its children out, so taking one on is a change to its own
    --> layout. A fresh widget is already waiting for one of its own, and
    --> InvalidateLayout stops there, so the parent has to be told from here.
    self:InvalidateLayout()
end

--- Removes a child from a widget.
--- @param widget table
function BASE:RemoveChild(widget)
    if not widget then return end

    for i = #self.children, 1, -1 do
        if self.children[i] == widget then
            table.remove(self.children, i)
            widget.parent = nil

            self:InvalidateLayout()
            return
        end
    end
end

--- Gets all children from a widget.
--- @return table
function BASE:GetChildren()
    return self.children
end

--- Clears all children from a widget.
function BASE:ClearChildren()
    for i = #self.children, 1, -1 do
        local child = self.children[i]
        child.parent = nil
        self.children[i] = nil
    end
end

--- Finds a child in widget.
--- @param name string
--- @return child table 
function BASE:FindChildByName(name)
    for _, child in ipairs(self.children) do
        if child.name == name then
            return child
        end

        local found = child:FindChildByName(name)
        if found then return found end
    end

    return nil
end

--- Sets the name of a widget.
--- @param name string
function BASE:SetName(name)
    self.name = name
end 

--- Gets the name of a widget.
--- @return name string
function BASE:GetName()
    return self.name
end

--- Checks if mouse cursor is in bounds of the widget.
--- @param mx number
--- @param my number
--- @return boolean
function BASE:IsInBounds(mx, my)
    if not self.visible then return false end

    local x, y = self:GetAbsolutePos()
    local w, h = self:GetSize()

    return mx >= x and my >= y and mx <= x + w and my <= y + h
end

--- Hit test
--- @param mx number
--- @param my number
function BASE:HitTest(mx, my)
    if not self.visible then return nil end

    --> A child drawn outside the clip is not on screen, so it is not there to
    --> be clicked either - scrolling a page slides widgets out of sight rather
    --> than out of the tree.
    local cx, cy, cw, ch = self:GetClipBounds()
    local outside = cx ~= nil and (mx < cx or my < cy or mx >= cx + cw or my >= cy + ch)

    if not outside then
        for i = #self.children, 1, -1 do
            local child = self.children[i]
            local hit = child:HitTest(mx, my)
            if hit then return hit end
        end
    end

    if self:IsInBounds(mx, my) then
        return self
    end

    return nil
end

--- Runs the input pass for the hierarchy, called on the root every frame.
--- Cursor state lives on the root, the widget under the cursor gets the events.
--- This is only used internally - do not touch this.
function BASE:ProcessInputInternal()
    local mx, my = occ.mousepos()
    local down = occ.mousedown()

    local dx, dy = mx - (self.mouseX or mx), my - (self.mouseY or my)

    self.mouseX = mx
    self.mouseY = my

    --> A widget that captured the cursor keeps every event until it lets go,
    --> so dragging carries on outside of the widget's own bounds.
    local captured = occ.__getcapture()
    local target = captured or self:HitTest(mx, my)

    if self.hoveredWidget ~= target then
        if self.hoveredWidget then
            self.hoveredWidget:OnCursorExited()
        end

        if target then
            target:OnCursorEntered()
        end

        self.hoveredWidget = target
    end

    if target and (dx ~= 0 or dy ~= 0) then
        target:OnMouseMoved(mx, my, dx, dy)
    end

    local wheel = occ.mousewheel()

    --> The widget under the cursor gets first refusal on the wheel, and what it
    --> turns down goes to whatever is holding it - a label does not scroll, the
    --> group it sits on does.
    if wheel ~= 0 then
        local widget = target

        while widget do
            if widget:OnMouseWheeled(wheel) then break end

            widget = widget.parent
        end
    end

    if down and not self.mouseDown then
        if target then
            occ.__setcapture(target)
            target:OnMousePressed(mx, my, MOUSE_LEFT)
        end
    elseif not down and self.mouseDown then
        if target then
            target:OnMouseReleased(mx, my, MOUSE_LEFT)
        end

        occ.__releasecapture(target)
    end

    self.mouseDown = down

    --> The right button goes to whatever is under the cursor without taking
    --> hold of it. There is the one capture to go round, dragging is what it is
    --> for, and a right click is over as soon as it has happened.
    local right = occ.mouserightdown()

    if right ~= self.rightDown and target then
        if right then
            target:OnMousePressed(mx, my, MOUSE_RIGHT)
        else
            target:OnMouseReleased(mx, my, MOUSE_RIGHT)
        end
    end

    self.rightDown = right
end

--- Checks if mouse cursor is hovering over a widget.
--- *Override this!*
--- @return hovered boolean
function BASE:IsHovered()
    return self.hovered
end

--- Checks if a cursor has entered the widget bounds.    
function BASE:OnCursorEntered()
    self.hovered = true
end

--- Checks if a cursor has left the widget bounds.     
--- *Override this!*
function BASE:OnCursorExited()
    self.hovered = false
end

--- Checks whether the mouse was pressed within the widget's bounds.
--- *Override this!*
--- @param mx number Mouse X position
--- @param my number Mouse Y position
--- @param key number Mouse button/key pressed
function BASE:OnMousePressed(mx, my, key) end

--- Checks whether the mouse was released within the widget's bounds.
--- *Override this!*
--- @param mx number Mouse X position
--- @param my number Mouse Y position
--- @param key number Mouse button/key released
function BASE:OnMouseReleased(mx, my, key) end

--- Called when the cursor moves over this widget.
--- @param mx number Mouse X position (usually local to the widget)
--- @param my number Mouse Y position (usually local to the widget)
--- @param dx number Change in X since last frame
--- @param dy number Change in Y since last frame
function BASE:OnMouseMoved(mx, my, dx, dy) end

--- Called when the mouse wheel is scrolled while the cursor is over this widget.
--- Returning nothing passes it on to the parent, so a widget with no use for it
--- never gets in the way of one that has.
--- *Override this!*
--- @param delta number Scroll amount (positive = up, negative = down)
--- @return boolean|nil handled True to keep it from going any further up.
function BASE:OnMouseWheeled(delta) end