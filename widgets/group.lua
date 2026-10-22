--[[
    group.lua
    A box of tabs, every tab holding its own page of widgets.
    The first group parented to a window fills that window's main area.

    Example:
    root (base)
    |_window
     |_group
      |_page (base)
       |_other widgets

    Widgets can be parented to the group itself - they land on the page that is
    showing, and the page stacks them down it.
]]

local GROUP = occ.register("group", "base")

local tween = lje.include("backend/tween.lua")

local MOUSE_LEFT = MOUSE_LEFT or 107

local SysTime = SysTime or lje.secure.pull("SysTime", lje.state.menu)

--- Initializes the group.
function GROUP:Init()
    self.name = "group"

    self.w = 200
    self.h = 150

    --- Height of the tab strip, the accent bar at the top of the group and the
    --- line under the strip included.
    self.tabHeight = 22

    --- Space above the tabs, clearing the accent bar. They start on the row
    --- the line under the bar is drawn along, the tab's own top edge and that
    --- line sharing the one pixel rather than stacking into a band of two.
    self.tabTop = 3

    --- Space either side of a tab label, a tab is as wide as it needs to be.
    self.tabPadding = 8

    --- How far a tab label is nudged from where it lands on its own. A group on
    --- another group's page carries the frame of the one holding it to the left
    --- of its tabs, so its labels are pushed a pixel further over than the ones
    --- on a group filling a window.
    self.tabTextX = 1
    self.tabTextNestedX = 2
    self.tabTextY = 0

    --- Width of the gap between one tab and the next. The tabs carry no left
    --- edge, so they are meant to butt up against each other.
    self.tabSpacing = 0

    --- Margin of the page inside the border.
    self.padding = 0

    --- Margin over and under the content stacked on a page. Groups laid out on
    --- one take the whole of it, this is for what goes inside a group.
    self.margin = 5

    --- What the content gets either side of it.
    self.sidemargin = 5

    --- Space between the groups laid out on a page.
    self.spacing = 4

    --- Space between one widget stacked on a page and the next, so a run of
    --- checkboxes is not laid down one straight under the other.
    self.contentspacing = 4

    --- Margins the groups laid out on a page are held off the edges of it by,
    --- so a group sitting on another one is not up against the borders of the
    --- one holding it.
    self.groupleft = 3
    self.groupright = 3
    self.grouptop = 4
    self.groupbottom = 2

    --- Columns the groups on a page are dealt into.
    self.columns = 2

    --- Tabs in the order they were added, {name = string, page = table, w = number}.
    self.tabs = {}

    --- Index of the tab whose page is showing, 0 when there are none.
    self.active = 0

    --- Index of the tab under the cursor, 0 when the cursor is off the strip.
    self.hoveredTab = 0

    --- Text written across the strip in place of the tabs, nil to show tabs.
    self.title = nil
    self.subtitle = nil

    --- Space left of the text, and kept clear right of it.
    self.textPadding = 4

    --- The two cut down to what fits, worked out in PerformLayout.
    self.titleshown = nil
    self.subtitleshown = nil

    --- Seconds a page takes to fade when the tab changes, nil for the one the
    --- style picks, 0 for no fade at all.
    self.fadetime = nil

    --- Width of the bar down a page that has more on it than fits.
    self.scrollw = 4

    --- Pixels a notch of the wheel moves a page by.
    self.scrollstep = 32

    --- How quickly a page catches up with the wheel, per second, nil for the one
    --- the style picks.
    self.scrollspeed = nil

    self.lastthink = SysTime()
end

--- Drives the fade between one tab's page and the next.
function GROUP:Think()
    local now = SysTime()

    --> A page that is not showing is never painted, and Think comes off the
    --> paint pass, so a group can go a long time between two of them. Capping
    --> the step keeps a tab that was left alone from snapping to the end of its
    --> fade the moment it comes back.
    local dt = math.min(now - self.lastthink, 0.25)

    self.lastthink = now

    for _, tab in ipairs(self.tabs) do
        local animation = tab.animation

        if animation and animation:update(dt) then
            tab.animation = nil

            --> Faded out for good - off the screen and out of the hit test.
            if tab.page:GetAlpha() <= 0 then
                tab.page:SetVisible(false)
            end
        end

        local _, _, _, ph = self:GetPageBounds()

        if occ.scrollstep(tab, ph, dt, self:GetScrollSpeed()) then
            self:InvalidateLayout()
        end
    end
end

--- Area the pages sit in, local to the group.
--- @return number x
--- @return number y
--- @return number w
--- @return number h
function GROUP:GetPageBounds()
    local th = self.tabHeight
    local p = self.padding

    local x = p
    local y = th + p
    local w = self.w - p * 2
    local h = self.h - th - p * 2

    return x, y, math.max(0, w), math.max(0, h)
end

--- Holds everything on a page inside the page.
--- The group's own frame, tabs and borders are drawn before this bites, so what
--- is clipped is the content and nothing else.
--- @return number x
--- @return number y
--- @return number w
--- @return number h
function GROUP:GetClipBounds()
    local x, y = self:GetAbsolutePos()
    local px, py, pw, ph = self:GetPageBounds()

    return x + px, y + py, pw, ph
end

--- Measures the tabs and sizes every page to the body.
function GROUP:PerformLayout()
    local style = occ.style.group

    surface.SetFont(occ.font(style.font))

    local x, y, w, h = self:GetPageBounds()

    if self.title then
        --> Title first, then as much of the subtitle as is left room for, either
        --> one cut short with dots rather than running past the border.
        local room = self.w - self.textPadding * 2
        local title = self.title

        if surface.GetTextSize(title) > room then
            while #title > 0 and surface.GetTextSize(title .. "...") > room do
                title = title:sub(1, -2)
            end

            title = title .. "..."
        end

        local subtitle = nil

        if self.subtitle and self.subtitle ~= "" then
            local left = room - surface.GetTextSize(title)

            subtitle = " - " .. self.subtitle

            if surface.GetTextSize(subtitle) > left then
                while #subtitle > 3 and surface.GetTextSize(subtitle .. "...") > left do
                    subtitle = subtitle:sub(1, -2)
                end

                subtitle = #subtitle > 3 and subtitle .. "..." or nil
            end
        end

        self.titleshown = title
        self.subtitleshown = subtitle
    end

    for _, tab in ipairs(self.tabs) do
        local tw = surface.GetTextSize(tab.name)

        tab.w = tw + self.tabPadding * 2

        --> Pages are stacked on top of each other and only the active one is
        --> visible, so they all get the same bounds.
        local page = tab.page

        --> Scrolling slides the page up under the clip rect, which stays where
        --> it is - so the content moves and the hole it is seen through does
        --> not.
        if page.x ~= x or page.y ~= y - tab.scroll then
            page:SetPos(x, y - tab.scroll)
        end

        if page.w ~= w or page.h ~= h then
            page:SetSize(w, h)
        end

        local gl, gr = self.groupleft, self.groupright
        local gt, gb = self.grouptop, self.groupbottom

        local gw = math.max(0, w - gl - gr)
        local gh = math.max(0, h - gt - gb)

        --> Groups on the page share out what the margins leave of it, column by
        --> column, their own borders being what sets them apart. A page with
        --> none of them stacks what it does have inside the margin instead, so
        --> the content is not up against the group's border.
        if occ.masonry(page, gl, gt, gw, gh, self.columns, self.spacing) == 0 then
            local m = self.margin
            local sm = self.sidemargin
            local cw = w - sm * 2

            --> The bar takes its width off the content rather than sitting over
            --> it, so nothing ends up underneath it.
            if tab.content > h then
                cw = cw - self.scrollw
            end

            tab.content = occ.stack(page, sm, m, math.max(0, cw), self.contentspacing) + m * 2
        else
            --> Columns are sized to the area, so there is never anything of
            --> them left over to scroll to.
            tab.content = h
        end
    end
end

--- Seconds a page takes to fade when the tab changes.
--- @return number
function GROUP:GetFadeTime()
    return self.fadetime or occ.style.group.fadetime
end

--- How quickly a page catches up with the wheel, per second.
--- @return number
function GROUP:GetScrollSpeed()
    return self.scrollspeed or occ.style.scroll.speed
end

--- How far a page can be scrolled before it runs out.
--- @param tab table Tab whose page to measure.
--- @return number
function GROUP:GetScrollMax(tab)
    local _, _, _, h = self:GetPageBounds()

    return math.max(0, tab.content - h)
end

--- Scrolls the page that is showing, when there is more on it than fits.
--- @param delta number
--- @return boolean|nil handled
function GROUP:OnMouseWheeled(delta)
    local tab = self.tabs[self.active]

    if not tab then return end

    local _, _, _, ph = self:GetPageBounds()

    --> Nothing to scroll and the wheel carries on up to whatever is holding
    --> this group - a group inside one that does scroll still works.
    return occ.scrollwheel(tab, ph, delta, self.scrollstep)
end

--- Paints the group.
--- @param x number
--- @param y number
--- @param w number
--- @param h number
function GROUP:Paint(x, y, w, h)
    local alpha = self:GetAbsoluteAlpha() / 255
    local style = occ.style.group
    local line = occ.style.border.window
    local line2 = occ.style.border.base

    local accent = occ.style.accent
    local th = self.tabHeight

    surface.SetDrawColor(style.background[1], style.background[2], style.background[3], style.background[4] * alpha)
    surface.DrawRect(x, y, w, h)

    --> The strip runs the full width behind the tabs, so a tab only has to
    --> draw what makes it stand out from it.
    surface.SetDrawColor(style.frame[1], style.frame[2], style.frame[3], style.frame[4] * alpha)
    surface.DrawRect(x, y, w, th)

    --> Tabs are flat - no box of their own, just a fill and a label, with a
    --> line in the gap between one and the next.
    local top = y + self.tabTop
    local tall = th - self.tabTop - 1
    local at = x

    --> Shading over the strip, up into the accent bar.
    local fade = style.framefade

    surface.SetDrawColor(fade[1], fade[2], fade[3], fade[4] * alpha)
    surface.SetMaterial(occ.material("gradient-up"))
    surface.DrawTexturedRect(x, y, w, th)

    --> Every tab takes a gradient of its own over its fill, so each one starts
    --> the shading again rather than taking a slice of the strip's.
    for i, tab in ipairs(self.tabs) do
        if i ~= self.active and not self.title then
            local background = i == self.hoveredTab and style.tabhovered or style.tab

            surface.SetDrawColor(background[1], background[2], background[3], background[4] * alpha)
            surface.DrawRect(at, top, tab.w, tall)

            local fade = style.tabfade

            surface.SetDrawColor(fade[1], fade[2], fade[3], fade[4] * alpha)
            surface.SetMaterial(occ.material("gradient-down"))
            surface.DrawTexturedRect(at, top, tab.w, tall)

            --> The same edges the active tab gets - a pixel taller than the
            --> fill, so the top lands on the line under the accent bar and the
            --> foot of it on the strap, one line of black at either end of the
            --> tab rather than two. No left edge, the tab before it having laid
            --> one down already and the group's own border standing in for it
            --> on the first tab along.
            surface.SetDrawColor(line[1], line[2], line[3], line[4] * alpha)
            surface.DrawRect(at, top, tab.w, 1)
            surface.DrawRect(at, top + tall, tab.w, 1)
            surface.DrawRect(at + tab.w - 1, top, 1, tall + 1)
        end

        at = at + tab.w + self.tabSpacing
    end


    
    --> A 1px strap under the strip, laid down a piece at a time - under every
    --> tab that is not showing its page, through the gaps between them, and on
    --> past the last one to the edge of the group. The active tab is the one
    --> break in it, so it and its page read as one piece.
    surface.SetDrawColor(line[1], line[2], line[3], line[4] * alpha)

    at = x

    --> With text in place of the tabs there is no strap at all, the text and
    --> its page reading as one piece the way an active tab and its page do.
    if not self.title then
        for i, tab in ipairs(self.tabs) do
            if i ~= self.active then
                surface.DrawRect(at, y + th - 1, tab.w, 1)
            end

            at = at + tab.w

            surface.DrawRect(at, y + th - 1, self.tabSpacing, 1)

            at = at + self.tabSpacing
        end

        surface.DrawRect(at, y + th - 1, math.max(0, x + w - at), 1)
    end

    surface.SetFont(occ.font(style.font))

    --> Which of the two nudges the labels take, worked out the once rather than
    --> per tab.
    local textx = occ.isa(self.parent, "window") and self.tabTextX or self.tabTextNestedX

    if self.titleshown and self.title then
        local tw, tt = surface.GetTextSize(self.titleshown)
        local tx = x + self.textPadding + textx
        local ty = math.floor(top + (tall - tt) * 0.5 + 0.5) + self.tabTextY
        local text = style.textactive

        surface.SetTextColor(text[1], text[2], text[3], text[4] * alpha)
        surface.SetTextPos(tx, ty)
        surface.DrawText(self.titleshown)

        if self.subtitleshown then
            local subtext = style.text

            surface.SetTextColor(subtext[1], subtext[2], subtext[3], subtext[4] * alpha)
            surface.SetTextPos(tx + tw, ty)
            surface.DrawText(self.subtitleshown)
        end
    end

    at = x

    for i = 1, self.title and 0 or #self.tabs do
        local tab = self.tabs[i]
        local active = i == self.active

        if active then
            --> The active tab takes the background of its page and runs a pixel
            --> further down than the rest, over the line under the strip, so the
            --> two of them read as one piece.
            local background = style.tabactive

            surface.SetDrawColor(background[1], background[2], background[3], background[4] * alpha)
            surface.DrawRect(at, top, tab.w, tall + 1)

            --> Its own gradient like the rest of them. gradient-down has faded
            --> out by the bottom, so the edge that meets the page is left with
            --> the page's own background and the two still join up.
            local fade = style.tabactivefade

            surface.SetDrawColor(fade[1], fade[2], fade[3], fade[4] * alpha)
            surface.SetMaterial(occ.material("gradient-down"))
            surface.DrawTexturedRect(at, top, tab.w, tall + 1)

            --> Top and right, the left left to the tab before it and no foot at
            --> all - the strap breaks here too, so the tab runs down into its
            --> page with nothing across the join.
            surface.SetDrawColor(line[1], line[2], line[3], line[4] * alpha)
            surface.DrawRect(at, top, tab.w, 1)
            surface.DrawRect(at + tab.w - 1, top, 1, tall + 1)
        end

        local text = active and style.textactive or style.text
        local tw, tt = surface.GetTextSize(tab.name)

        surface.SetTextColor(text[1], text[2], text[3], text[4] * alpha)
        --> Middle of the tab both ways, rounded onto a pixel rather than left
        --> half way between two of them.
        surface.SetTextPos(
            math.floor(at + (tab.w - tw) * 0.5 + 0.5) + textx,
            math.floor(top + (tall - tt) * 0.5 + 0.5) + self.tabTextY)
        surface.DrawText(tab.name)

        --> No line in the gap any more, the two outlines either side of it
        --> already part one tab from the next.
        at = at + tab.w + self.tabSpacing
    end

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
    surface.SetDrawColor(line[1], line[2], line[3], line[4] * alpha)
    surface.DrawRect(x, y + 3, w, 1)

    -- border for the group
    surface.SetDrawColor(line[1], line[2], line[3], line[4] * alpha)
    surface.DrawOutlinedRect(x, y, w, h)

    --> A second frame a pixel inside the border, around the page rather than
    --> the whole group - it starts under the tabs, so the strip is left with
    --> the one edge. Unlike the strap above it this runs unbroken, the active
    --> tab included, the tab being joined to its page by the black strap
    --> stopping rather than by this line going round it.
    surface.SetDrawColor(line2[1], line2[2], line2[3], line2[4] * alpha)
    surface.DrawOutlinedRect(x + 1, y + th, math.max(0, w - 2), math.max(0, h - th - 1))

    --> Over the page rather than the whole group, so the strip is left to its
    --> own shading, and over the frame around it as well, the two of them
    --> shading together rather than the line staying flat on top of it. The
    --> content of the page is drawn after Paint, so that keeps clear of it.
    local pagefade = style.pagefade

    surface.SetDrawColor(pagefade[1], pagefade[2], pagefade[3], pagefade[4] * alpha)
    surface.SetMaterial(occ.material("gradient-down"))
    surface.DrawTexturedRect(x + 1, y + th, w - 2, math.max(0, h - th))

    --> A bar down the right of a page with more on it than fits. Drawn before
    --> the content, which is why the layout keeps the content clear of it.
    local tab = self.tabs[self.active]

    if tab then
        local px, py, pw, ph = self:GetPageBounds()
        local bw = self.scrollw

        occ.scrollbar(tab, x + px + pw - bw, y + py, bw, ph, alpha)
    end
end

--- Adds a tab, handing back the page its widgets are parented to.
--- @param name string Label drawn on the tab.
--- @return table page
function GROUP:AddTab(name)
    local page = occ.create("base")

    page:SetName(name)
    page:SetPos(0, 0)

    --> Only the active page is drawn and hit tested, and the first tab added
    --> is the one that starts off active.
    page:SetVisible(#self.tabs == 0)

    --> Straight to the base, past the group's own AddChild - a page is the
    --> group's own furniture, not something being put on one.
    GROUP.BaseClass.AddChild(self, page)

    table.insert(self.tabs, {
        name = name,
        page = page,
        w = 0,

        --- Fade its page is part way through, nil when it is not fading.
        animation = nil,

        --- How far down the page is scrolled, where it is heading, and how tall
        --- what is on it came out.
        scroll = 0,
        target = 0,
        content = 0
    })

    if self.active == 0 then
        self.active = 1
    end

    self:InvalidateLayout()

    return page
end

--- Writes text across the strip in place of the tabs, as "title - subtitle".
--- A group with no tabs yet gets one named after the title, so widgets parented
--- to the group have a page to land on. nil goes back to showing the tabs.
--- @param title string|nil
--- @param subtitle string|nil Drawn after the title in the dimmer text colour.
--- @return table self
function GROUP:SetText(title, subtitle)
    self.title = title
    self.subtitle = subtitle
    self.titleshown = nil
    self.subtitleshown = nil
    self.hoveredTab = 0

    if title and #self.tabs == 0 then
        self:AddTab(title)
    end

    self:InvalidateLayout()

    return self
end

--- Gets the text written across the strip.
--- @return string|nil title
--- @return string|nil subtitle
function GROUP:GetText()
    return self.title, self.subtitle
end

--- Finds a tab by its label or by its index.
--- @param key string|number
--- @return number|nil index
function GROUP:FindTab(key)
    if type(key) == "number" then
        return self.tabs[key] and key or nil
    end

    for i, tab in ipairs(self.tabs) do
        if tab.name == key then
            return i
        end
    end

    return nil
end

--- Gets the page of a tab.
--- @param key string|number Label or index of the tab.
--- @return table|nil page
function GROUP:GetPage(key)
    local index = self:FindTab(key)

    return index and self.tabs[index].page or nil
end

--- Fades a page towards an alpha, or puts it straight there when the group is
--- set to not fade at all.
--- @param tab table Tab whose page to fade.
--- @param alpha number Alpha to end on, 0 to 255.
function GROUP:FadePage(tab, alpha)
    local time = self:GetFadeTime()

    if time > 0 then
        tab.animation = tween.new(time, tab.page, {alpha = alpha}, "outQuad")
        return
    end

    tab.animation = nil

    tab.page:SetAlpha(alpha)
    tab.page:SetVisible(alpha > 0)
end

--- Shows the page of a tab, fading out whatever was showing.
--- Alpha runs down the tree through GetAbsoluteAlpha, so fading a page takes
--- everything on it along - the groups sitting on it, their own pages, and
--- whatever is on those.
--- @param key string|number Label or index of the tab.
function GROUP:SetActiveTab(key)
    local index = self:FindTab(key)

    if not index then return end
    if index == self.active then return end

    --> Every page that is not the one being asked for goes, not just the one
    --> that was active - a page caught part way through a fade is still on
    --> screen and has to be sent back out.
    for i, tab in ipairs(self.tabs) do
        if i ~= index and tab.page:IsVisible() then
            self:FadePage(tab, 0)
        end
    end

    local to = self.tabs[index]

    self.active = index

    --> One that is already on screen carries on from the alpha it is at, so
    --> switching back part way through a fade picks up rather than restarts.
    if not to.page:IsVisible() then
        to.page:SetAlpha(0)
        to.page:SetVisible(true)
    end

    self:FadePage(to, 255)
end

--- Gets the index of the tab that is showing.
--- @return number index
function GROUP:GetActiveTab()
    return self.active
end

--- Gets the page that is showing.
--- @return table|nil page
function GROUP:GetActivePage()
    local tab = self.tabs[self.active]

    return tab and tab.page or nil
end

--- Gets how many tabs the group has.
--- @return number count
function GROUP:GetTabCount()
    return #self.tabs
end

--- Is a widget one of the group's own pages?
--- @param widget table
--- @return boolean
function GROUP:IsPage(widget)
    for _, tab in ipairs(self.tabs) do
        if tab.page == widget then
            return true
        end
    end

    return false
end

--- Adds a child.
--- Anything that is not one of the group's own pages goes on the page that is
--- showing, so a widget can be parented to the group itself and still land
--- somewhere the group lays out.
--- @param widget table
function GROUP:AddChild(widget)
    local page = self:GetActivePage()

    if page and widget and widget ~= self and not self:IsPage(widget) then
        widget:SetParent(page)
        return
    end

    GROUP.BaseClass.AddChild(self, widget)
end

--- Sets how many columns the groups on a page are dealt into.
--- @param columns number
function GROUP:SetColumns(columns)
    self.columns = columns
    self:InvalidateLayout()
end

--- Gets how many columns the groups on a page are dealt into.
--- @return number columns
function GROUP:GetColumns()
    return self.columns
end

--- Removes a tab and everything on its page.
--- @param key string|number Label or index of the tab.
function GROUP:RemoveTab(key)
    local index = self:FindTab(key)

    if not index then return end

    local tab = table.remove(self.tabs, index)

    tab.page:SetParent(nil)

    --> The tab that took its place carries on, or the last one when the end of
    --> the strip was the one that went. Removing shifts every tab after it down
    --> an index, so the active one is stale whichever went - clearing it leaves
    --> SetActiveTab with something to do rather than an index that looks like
    --> the one it is already on.
    if #self.tabs == 0 then
        self.active = 0
    else
        self.active = 0
        self:SetActiveTab(math.min(index, #self.tabs))
    end

    self:InvalidateLayout()
end

--- Finds the tab under a cursor position.
--- @param mx number
--- @param my number
--- @return number index 0 when the cursor is not on a tab.
function GROUP:TabAt(mx, my)
    if self.title then return 0 end

    local x, y = self:GetAbsolutePos()

    if my < y + self.tabTop or my > y + self.tabHeight then return 0 end

    local at = x

    for i, tab in ipairs(self.tabs) do
        if mx >= at and mx <= at + tab.w then
            return i
        end

        at = at + tab.w + self.tabSpacing
    end

    return 0
end

--- Switches to the tab that was clicked.
--- @param mx number
--- @param my number
--- @param key number
function GROUP:OnMousePressed(mx, my, key)
    if key ~= MOUSE_LEFT then return end

    local index = self:TabAt(mx, my)

    if index == 0 then return end

    self:SetActiveTab(index)
end

--- Tracks the tab under the cursor.
--- @param mx number
--- @param my number
--- @param dx number
--- @param dy number
function GROUP:OnMouseMoved(mx, my, dx, dy)
    self.hoveredTab = self:TabAt(mx, my)
end

--- Drops the hover once the cursor leaves the group.
function GROUP:OnCursorExited()
    GROUP.BaseClass.OnCursorExited(self)

    self.hoveredTab = 0
end

--- Lays the groups parented to a widget out masonry style.
--- They are dealt into a fixed number of columns, each one going to whichever
--- column is carrying the fewest so far, and the groups that end up sharing a
--- column split its height between them. Every column is the same width, and
--- there are never more of them than there are groups to fill them.
--- So one group takes the area on its own, two come out side by side at half
--- the width each, and a third goes underneath one of those two rather than
--- squeezing all three into thirds.
--- Anything parented to the widget that is not a group is left where it is.
--- @param parent table Widget holding the groups.
--- @param x number Left of the area they share, local to the parent.
--- @param y number Top of the area.
--- @param w number
--- @param h number
--- @param columns number|nil Columns to deal them into, 2 by default.
--- @param spacing number|nil Space between columns and between rows, 0 default.
--- @return number count Groups it laid out, 0 if the widget holds none.
function occ.masonry(parent, x, y, w, h, columns, spacing)
    spacing = spacing or 0
    columns = columns or 2

    local groups = {}

    for _, child in ipairs(parent:GetChildren()) do
        if occ.isa(child, "group") then
            groups[#groups + 1] = child
        end
    end

    if #groups == 0 then return 0 end

    --> Never more columns than there are groups, so none of them comes out
    --> empty and the ones that are there always fill the width.
    local count = math.min(math.max(1, columns), #groups)

    --> Dealt out one at a time to the column carrying the fewest. Every group
    --> takes an even share of the column it lands in, so the column carrying
    --> the fewest is always the next one along.
    local into = {}

    for i = 1, count do
        into[i] = {}
    end

    for i = 1, #groups do
        local column = into[(i - 1) % count + 1]

        column[#column + 1] = groups[i]
    end

    local cw = (w - spacing * (count - 1)) / count

    for i = 1, count do
        local column = into[i]
        local ch = (h - spacing * (#column - 1)) / #column
        local cx = x + (cw + spacing) * (i - 1)

        for j = 1, #column do
            local group = column[j]
            local cy = y + (ch + spacing) * (j - 1)

            --> Rounded off the far edge rather than the width, so a column that
            --> does not divide evenly still tiles the area exactly instead of
            --> leaving a seam a pixel wide.
            local px, py = math.floor(cx + 0.5), math.floor(cy + 0.5)
            local pw, ph = math.floor(cx + cw + 0.5) - px, math.floor(cy + ch + 0.5) - py

            if group.x ~= px or group.y ~= py then
                group:SetPos(px, py)
            end

            if group.w ~= pw or group.h ~= ph then
                group:SetSize(pw, ph)
            end
        end
    end

    return #groups
end

--- Stacks the children of a widget down an area, one under the next.
--- Every widget takes the full width and keeps the height it already has, so
--- the stack comes out as tall as what is in it rather than sharing the area
--- out the way the columns do. One that is not visible is skipped and takes no
--- room, so showing and hiding widgets closes the stack up behind them.
--- @param parent table Widget holding them.
--- @param x number Left of the area, local to the parent.
--- @param y number Top of the area.
--- @param w number Width every widget takes.
--- @param spacing number|nil Space between one widget and the next, 0 default.
--- @return number height Height the stack came to.
function occ.stack(parent, x, y, w, spacing)
    spacing = spacing or 0

    local at = y

    for _, child in ipairs(parent:GetChildren()) do
        if child:IsVisible() then
            if child.x ~= x or child.y ~= at then
                child:SetPos(x, at)
            end

            if child.w ~= w then
                child:SetWide(w)
            end

            at = at + child.h + spacing
        end
    end

    --> The last widget does not carry a gap under it.
    if at == y then return 0 end

    return at - y - spacing
end

--- Eases a scroll along towards where the wheel has asked it to go.
--- @param state table Carries scroll, target and content.
--- @param view number How much of the content is on show.
--- @param dt number Seconds gone by since the last step.
--- @param speed number How quickly it catches up, per second.
--- @return boolean moved Whether it went anywhere.
function occ.scrollstep(state, view, dt, speed)
    --> Content that has shrunk can leave a scroll past its end, so where it is
    --> heading is pulled back into range every step rather than only when the
    --> wheel turns.
    state.target = math.min(math.max(state.target, 0), math.max(0, state.content - view))

    if state.scroll == state.target then return false end

    --> Eased by the time gone by rather than a flat step a frame, so it lands
    --> at the same speed whatever the framerate is doing.
    state.scroll = state.scroll + (state.target - state.scroll) * (1 - math.exp(-dt * speed))

    --> Asymptotes never arrive, so the last half pixel is a step.
    if math.abs(state.target - state.scroll) < 0.5 then
        state.scroll = state.target
    end

    return true
end

--- Moves a scroll by a turn of the wheel.
--- @param state table Carries scroll, target and content.
--- @param view number How much of the content is on show.
--- @param delta number Notches, positive scrolling up.
--- @param step number Pixels a notch is worth.
--- @return boolean|nil taken Nothing when there was nothing to scroll, so the
--- wheel carries on to whatever is holding this.
function occ.scrollwheel(state, view, delta, step)
    local max = math.max(0, state.content - view)

    if max <= 0 then return end

    state.target = math.min(math.max(state.target - delta * step, 0), max)

    return true
end

--- Draws the bar for a scroll down the right of an area.
--- Nothing is drawn when everything fits.
--- @param state table Carries scroll and content.
--- @param x number Left of the bar.
--- @param y number Top of the area, and of the track.
--- @param w number Width of the bar.
--- @param h number Height of the area on show.
--- @param alpha number 0 to 1.
function occ.scrollbar(state, x, y, w, h, alpha)
    local max = math.max(0, state.content - h)

    if max <= 0 then return end

    local style = occ.style.scroll

    --> As much of the bar as the area is showing of the content, and never so
    --> little of it that there is nothing left to see.
    local tall = math.max(12, h * h / state.content)
    local ty = y + (h - tall) * (state.scroll / max)

    surface.SetDrawColor(style.bar[1], style.bar[2], style.bar[3], style.bar[4] * alpha)
    surface.DrawRect(x, y, w, h)

    surface.SetDrawColor(style.thumb[1], style.thumb[2], style.thumb[3], style.thumb[4] * alpha)
    surface.DrawRect(x, ty, w, tall)
end

--- Creates a group.
--- @param parent table|nil Widget to parent it to, occ.root by default.
--- @param ... string Labels of tabs to add right away.
--- @return table group
function occ.group(parent, ...)
    local group = occ.create("group", parent or occ.root)

    for _, name in ipairs({...}) do
        group:AddTab(name)
    end

    return group
end
