--[[
    notification.lua
    A line of text that slides in from the left, holds, then tweens back out
    and deletes itself.

    Example:
    root (base)
    |_notification
]]

local NOTIFICATION = occ.register("notification", "base")

local tween = lje.include("backend/tween.lua")

local SysTime = SysTime or lje.secure.pull("SysTime", lje.state.menu)

--- Notifications currently on screen, oldest first - they stack down from the
--- top of the screen in this order.
local active = {}

--- Where notifications go on the screen, shared by all of them. Set it with
--- occ.setnotificationarea.
---   x, y   the corner the stack starts from
---   align  "left": the left edge sits on x and they slide in from the left of
---          the screen. "right": the right edge sits on x and they slide in
---          from the right.
---   grow   "down" stacks under y, "up" stacks above it - for the bottom corners.
--> Kept across a reload, like occ.opened, so a script that moved it does not
--> see it jump back.
occ.notificationarea = occ.notificationarea or {x = 5, y = 24, align = "left", grow = "down"}

--- Moves the notification area. Anything left nil keeps what it was.
--- @param x number|nil
--- @param y number|nil
--- @param align string|nil "left" or "right".
--- @param grow string|nil "down" or "up".
function occ.setnotificationarea(x, y, align, grow)
    local area = occ.notificationarea

    if x then area.x = x end
    if y then area.y = y end
    if align == "left" or align == "right" then area.align = align end
    if grow == "down" or grow == "up" then area.grow = grow end
end

--- Are notifications shown? Off, occ.notification still hands back a widget
--- so callers can use it as normal, but it never goes on screen.
--> Kept across a reload like the area.
if occ.shownotifications == nil then
    occ.shownotifications = true
end

--- Turns notifications on or off. Turning them off takes down any on screen.
--- @param show boolean
function occ.setnotificationsenabled(show)
    show = show and true or false

    if occ.shownotifications == show then return end

    occ.shownotifications = show

    if not show then
        for i = #active, 1, -1 do
            active[i]:Remove()
        end
    end
end

--- Are notifications shown?
--- @return boolean
function occ.notificationsenabled()
    return occ.shownotifications
end

--- Gets the notification area.
--- @return number x
--- @return number y
--- @return string align
--- @return string grow
function occ.getnotificationarea()
    local area = occ.notificationarea

    return area.x, area.y, area.align, area.grow
end

--- Initializes the notification.
function NOTIFICATION:Init()
    self.name = "notification"

    self.w = 200
    self.h = 32

    --- Text the notification shows.
    self.text = ""

    --- Seconds it stays on screen for, not counting the tweens.
    self.timeout = 5

    --- Seconds a tween takes, nil for the one the style picks.
    self.tweentime = nil

    --- Space around the text.
    self.padding = 7

    --- Space between stacked notifications.
    self.spacing = 4

    --- How far in the notification is, 0 is off screen and 1 is resting.
    self.state = {offset = 0}

    --- How much of the hold has elapsed, drives the bar under the text.
    self.progress = 0

    --- Is it tweening back out?
    self.closing = false

    --- When the hold is over, set once it has finished sliding in.
    self.holduntil = nil

    self.lastthink = SysTime()

    --- Has the widget been sized to its text yet?
    self.sized = false

    self.animation = tween.new(self:GetTweenTime(), self.state, {offset = 1}, "inOutQuad")
end

--- Drives the tween, and drops the notification once it has tweened out.
function NOTIFICATION:Think()
    local now = SysTime()
    local dt = now - self.lastthink

    self.lastthink = now

    if not self.sized then
        local style = occ.style.notification

        surface.SetFont(occ.font(style.font))

        local tw, th = surface.GetTextSize(self.text)

        self.w = tw + self.padding * 2
        self.h = th + self.padding * 2
        self.sized = true
    end

    if self.animation:update(dt) then
        if self.closing then
            self:Remove()
            return
        end

        --> Done sliding in - hold, then tween back out the way it came.
        if not self.holduntil then
            self.holduntil = now + self.timeout
        elseif now >= self.holduntil then
            self.closing = true
            self.animation = tween.new(self:GetTweenTime(), self.state, {offset = 0}, "inBack")
        end
    end

    if self.holduntil then
        self.progress = math.min(1, 1 - (self.holduntil - now) / self.timeout)
    end

    local offset = self.state.offset

    --> A notification that is no longer in the tree never gets another Think
    --> to remove itself with - reloading swaps occ.notifications out from under
    --> them - so drop those here instead of stacking below them forever.
    for i = #active, 1, -1 do
        if not active[i].parent then
            table.remove(active, i)
        end
    end

    --- Stack away from the area's corner, in the order they were created.
    local area = occ.notificationarea
    local stack = 0

    for i = 1, #active do
        local other = active[i]

        if other == self then break end

        stack = stack + other.h + self.spacing
    end

    local y

    if area.grow == "up" then
        y = area.y - self.h - stack
    else
        y = area.y + stack
    end

    --> Slides in from the edge of the screen on its own side, so offset 0 is
    --> just off screen and 1 is resting on the area.
    local x

    if area.align == "right" then
        local rest = area.x - self.w
        local screen = self.parent and self.parent.w or rest + self.w

        x = rest + (screen - rest) * (1 - offset)
    else
        x = area.x - (area.x + self.w) * (1 - offset)
    end

    --> inBack and outBack overshoot on purpose, so the alpha has to be clamped.
    self:SetAlpha(math.max(0, math.min(255, 255 * offset)))
    self:SetPos(x, y)
end

--- Paints the notification.
--- @param x number
--- @param y number
--- @param w number
--- @param h number
function NOTIFICATION:Paint(x, y, w, h)
    local alpha = self:GetAbsoluteAlpha() / 255
    local style = occ.style.notification
    local border = occ.style.border.base

    surface.SetDrawColor(style.background[1], style.background[2], style.background[3], style.background[4] * alpha)
    surface.DrawRect(x, y, w, h)

    surface.SetDrawColor(border[1], border[2], border[3], border[4] * alpha)
    surface.DrawOutlinedRect(x, y, w, h)

    surface.SetFont(occ.font(style.font))
    surface.SetTextColor(style.text[1], style.text[2], style.text[3], style.text[4] * alpha)
    surface.SetTextPos(x + self.padding, y + self.padding)
    surface.DrawText(self.text)

    --> How much of the hold has gone by, grows to the full width before the
    --> notification tweens back out.
    local accent = occ.style.accent

    surface.SetDrawColor(accent[1], accent[2], accent[3], accent[4] * alpha)
    surface.DrawRect(x, y + h - 1, w * self.progress, 1)
end

--- Seconds a tween takes.
--- @return number
function NOTIFICATION:GetTweenTime()
    return self.tweentime or occ.style.notification.tweentime
end

--- Sets the text of the notification.
--- @param text string
function NOTIFICATION:SetText(text)
    self.text = text
    self.sized = false
end

--- Gets the text of the notification.
--- @return text string
function NOTIFICATION:GetText()
    return self.text
end

--- Sets how long the notification stays on screen for.
--- @param timeout number
function NOTIFICATION:SetTimeout(timeout)
    self.timeout = timeout
end

--- Gets how long the notification stays on screen for.
--- @return number timeout
function NOTIFICATION:GetTimeout()
    return self.timeout
end

--- Takes the notification off the screen and out of the hierarchy.
function NOTIFICATION:Remove()
    for i = #active, 1, -1 do
        if active[i] == self then
            table.remove(active, i)
        end
    end

    self:SetParent(nil)
end

--- Creates a notification.
--- @param text string Text the notification shows.
--- @param timeout number|nil Seconds it stays on screen, 5 by default.
--- @return table notification
function occ.notification(text, timeout)
    --> Its own root, not occ.root - the overlay fades out when it is closed and
    --> a notification has to be seen whether it is open or not.
    --> Turned off, it is made but never parented or stacked, so it is not
    --> drawn and does not hold a place for later.
    local parent = occ.shownotifications and (occ.notifications or occ.root) or nil
    local notification = occ.create("notification", parent)

    notification:SetText(text)
    notification:SetTimeout(timeout or 5)

    if parent then
        table.insert(active, notification)
    end

    return notification
end
