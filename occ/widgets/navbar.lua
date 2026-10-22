--[[
    navbar.lua
    A strip across the top of the screen, with a button on it for every window
    it opens. Pressing a button puts its window up, pressing it again takes it
    back down.

    The bar runs the whole width of whatever it is on, occ.root by default, so
    it goes from one corner to the other. The windows are top level - they go on
    occ.root wherever the bar itself is, so they can be dragged anywhere rather
    than being stuck to it.

    Example:
    root (base)
    |_navbar
    | |_button
    |_window (the one that button opens)
]]

local NAVBAR = occ.register("navbar", "base")

local tween = lje.include("backend/tween.lua")

local SysTime = SysTime or lje.secure.pull("SysTime", lje.state.menu)

--- Initializes the navbar.
function NAVBAR:Init()
    self.name = "navbar"

    self.x = 0
    self.y = 0

    self.w = 200

    --- Height of the bar, the accent at the top of it included.
    self.h = 26

    --- Space above the buttons.
    self.top = 3

    --- Height of the accent along the bottom of the bar, inside the line that
    --- goes round it.
    self.accentHeight = 2

    --- Space between the first button and the left of the bar.
    self.padding = 4

    --- Space between one button and the next.
    self.spacing = 2

    --- Height of the mark under the button whose window is up.
    self.markHeight = 2

    --- Does the bar run the full width of whatever it is on? Off to set the
    --- width by hand.
    self.fill = true

    --- How the time and date at the end of the status line are written out.
    self.clock = "%H:%M:%S  %d/%m/%Y"

    --- What the pieces of that line are parted by.
    self.separator = " | "

    --- Space between the status line and the first button after it.
    self.statusGap = 10

    --- How wide the status line came out, which is where the buttons start.
    self.statusWidth = 0

    --- Seconds a window takes to fade when its button is pressed, nil for the
    --- one the style picks, 0 for no fade at all.
    self.fadetime = nil

    --- Buttons on the bar, in the order they were added.
    --- {name = string, button = table, window = table, placed = boolean}
    self.entries = {}

    self.lastthink = SysTime()

    self:RollSentence()
end

--- Takes another of occ.sentences.
--- One is picked when the bar is made and kept, rather than being drawn afresh
--- every frame - a line that changed sixty times a second would be unreadable.
function NAVBAR:RollSentence()
    local sentences = occ.sentences

    if not sentences or #sentences == 0 then
        self.sentence = nil
        return
    end

    self.sentence = sentences[math.random(#sentences)]
end

--- The line down the right of the bar - the tag, one of occ.sentences, and the
--- time and date, parted by bars.
--- @return string
function NAVBAR:GetStatus()
    local parts = {}

    if occ.tag then
        parts[#parts + 1] = occ.tag
    end

    if self.sentence then
        parts[#parts + 1] = self.sentence
    end

    parts[#parts + 1] = os.date(self.clock)

    return table.concat(parts, self.separator)
end

--- How much of the bottom of the bar the accent takes, the line round it
--- included. The buttons stop above it.
--- @return number
function NAVBAR:GetAccentHeight()
    return self.accentHeight + 2
end

--- Runs the bar across its parent and lays the buttons out along it.
function NAVBAR:PerformLayout()
    --> The bar spans what it is on rather than sizing itself to its buttons -
    --> occ.root is the screen, so it goes corner to corner.
    if self.fill and self.parent and self.w ~= self.parent.w then
        self:SetWide(self.parent.w)
    end

    local style = occ.style.navbar

    surface.SetFont(occ.font(style.font))

    --> The status line comes first and the buttons after it, so how wide it is
    --> decides where they start. Measured here rather than every frame, so the
    --> buttons hold still while the clock ticks under them.
    self.statusWidth = surface.GetTextSize(self:GetStatus())

    local top = self.top

    --> The buttons stop short of the accent along the bottom. They are children
    --> and so are painted after the bar, and would draw straight over it.
    local tall = self.h - top - self:GetAccentHeight()
    local at = self.padding + self.statusWidth + self.statusGap

    for _, entry in ipairs(self.entries) do
        local button = entry.button

        --> Only the width comes off the button. The bar is a fixed height and
        --> the buttons fill what is left of it, which is why they are not left
        --> to size themselves.
        local bw = button:Measure()

        if button.x ~= at or button.y ~= top then
            button:SetPos(at, top)
        end

        if button.w ~= bw or button.h ~= tall then
            button:SetSize(bw, tall)
        end

        at = at + bw + self.spacing
    end
end

--- Paints the navbar.
--- @param x number
--- @param y number
--- @param w number
--- @param h number
function NAVBAR:Paint(x, y, w, h)
    local alpha = self:GetAbsoluteAlpha() / 255
    local style = occ.style.navbar
    local bstyle = occ.style.border
    local accent = occ.style.accent

    surface.SetDrawColor(style.background[1], style.background[2], style.background[3], style.background[4] * alpha)
    surface.DrawRect(x, y, w, h)

    surface.SetDrawColor(30, 30, 30, 255 * alpha)
    surface.SetMaterial(occ.material("gradient-down"))
    surface.DrawTexturedRect(x, y, w, h)

    -- border for the bar
    surface.SetDrawColor(bstyle.window[1], bstyle.window[2], bstyle.window[3], bstyle.window[4] * alpha)
    surface.DrawOutlinedRect(x, y, w, h)

    --> The accent runs along the bottom of the bar rather than the top the way a
    --> window's does, with a line of its own round it.
    local band = self:GetAccentHeight()

    surface.SetDrawColor(bstyle.window[1], bstyle.window[2], bstyle.window[3], bstyle.window[4] * alpha)
    surface.DrawOutlinedRect(x, y + h - band, w, band)

    local top = y + h - band + 1

    surface.SetDrawColor(accent[1], accent[2], accent[3], accent[4] * alpha)
    surface.DrawRect(x + 1, top, w - 2, self.accentHeight)

    --> The lower of its rows taken down to half the accent, the way a window
    --> and a group both do it, so the bar has a lit edge and a shaded one
    --> rather than one flat band of colour.
    local shade = occ.shcolor(50, accent)

    surface.SetDrawColor(shade[1], shade[2], shade[3], shade[4] * alpha)
    surface.DrawRect(x + 1, top + self.accentHeight - 1, w - 2, 1)

    --> A mark along the bottom of whichever buttons have their window up, so the
    --> bar says what is open without the buttons needing a state of their own.
    for _, entry in ipairs(self.entries) do
        if entry.open then
            local button = entry.button
            local mark = self.markHeight

            surface.SetDrawColor(accent[1], accent[2], accent[3], accent[4] * alpha)
            surface.DrawRect(x + button.x, y + button.y + button.h - mark, button.w, mark)
        end
    end

    --> First on the bar, with the buttons laid out after it. The clock is read
    --> every frame so it ticks along.
    surface.SetFont(occ.font(style.font))

    local status = self:GetStatus()
    local _, th = surface.GetTextSize(status)

    surface.SetTextColor(style.text[1], style.text[2], style.text[3], style.text[4] * alpha)
    surface.SetTextPos(x + self.padding + 4, y + self.top + (h - self.top - th) * 0.3)
    surface.DrawText(status)
end

--- Puts a button on the bar, with a window of its own behind it.
--- @param name string Text on the button, also the window's title.
--- @return table window The window that button opens.
function NAVBAR:AddButton(name)
    local button = occ.button(name, self)

    --> The bar hands it a height, so it does not go taking one of its own.
    button:SetAutoSize(false)

    --> Windows are top level wherever the bar is, so this one goes to occ.root
    --> the way any other does. It starts down - the button is what puts it up.
    local window = occ.window(name)

    window:SetVisible(false)

    table.insert(self.entries, {
        name = name,
        button = button,
        window = window,

        --- Is its window meant to be up? Not the same as the window being on
        --- screen - one on its way out is still there until it has faded.
        open = false,

        --- The fade its window is part way through, nil when it is not fading.
        animation = nil,

        --- Has it been put somewhere yet? The first press places it under the
        --- bar, after which wherever it was dragged to is left alone.
        placed = false
    })

    button:OnClick(function()
        self:Toggle(name)
    end)

    self:InvalidateLayout()

    return window
end

--- Finds an entry by its name or by its place on the bar.
--- @param key string|number
--- @return table|nil entry
function NAVBAR:Find(key)
    if type(key) == "number" then
        return self.entries[key]
    end

    for _, entry in ipairs(self.entries) do
        if entry.name == key then
            return entry
        end
    end

    return nil
end

--- Gets the window a button opens, which is where its widgets go.
--- @param key string|number Name or place on the bar.
--- @return table|nil window
function NAVBAR:GetWindow(key)
    local entry = self:Find(key)

    return entry and entry.window or nil
end

--- Gets a button on the bar.
--- @param key string|number Name or place on the bar.
--- @return table|nil button
function NAVBAR:GetButton(key)
    local entry = self:Find(key)

    return entry and entry.button or nil
end

--- Gets how many buttons are on the bar.
--- @return number count
function NAVBAR:GetButtonCount()
    return #self.entries
end

--- Is a button's window up?
--- @param key string|number Name or place on the bar.
--- @return boolean
function NAVBAR:IsOpen(key)
    local entry = self:Find(key)

    --> What it was asked for rather than what is on screen, so a window part way
    --> through fading out does not still read as open.
    return entry ~= nil and entry.open
end

--- Seconds a window takes to fade when its button is pressed.
--- @return number
function NAVBAR:GetFadeTime()
    return self.fadetime or occ.style.navbar.fadetime
end

--- Fades a window towards an alpha, or puts it straight there when the bar is
--- set to not fade at all.
--- @param entry table
--- @param alpha number 0 to 255.
function NAVBAR:FadeWindow(entry, alpha)
    local time = self:GetFadeTime()

    if time > 0 then
        entry.animation = tween.new(time, entry.window, {alpha = alpha}, "outQuad")
        return
    end

    entry.animation = nil

    entry.window:SetAlpha(alpha)
    entry.window:SetVisible(alpha > 0)
end

--- Drives the fades.
function NAVBAR:Think()
    local now = SysTime()

    --> Capped the way the other widgets cap theirs, so a long gap between frames
    --> does not throw a fade straight to the end.
    local dt = math.min(now - self.lastthink, 0.25)

    self.lastthink = now

    for _, entry in ipairs(self.entries) do
        local animation = entry.animation

        if animation and animation:update(dt) then
            entry.animation = nil

            --> Faded out for good - off the screen and out of the hit test.
            if entry.window:GetAlpha() <= 0 then
                entry.window:SetVisible(false)
            end
        end
    end
end

--- Puts a button's window up and on top of the others.
--- @param key string|number Name or place on the bar.
function NAVBAR:Open(key)
    local entry = self:Find(key)

    if not entry then return end

    --> Dropped under the bar the first time it goes up. After that it keeps
    --> wherever it was dragged to.
    if not entry.placed then
        local x, y = self:GetAbsolutePos()

        entry.window:SetPos(x, y + self.h + self.spacing)
        entry.placed = true
    end

    --> One that is already on screen carries on from the alpha it is at, so
    --> pressing twice in quick succession picks up rather than starting over.
    if not entry.window:IsVisible() then
        entry.window:SetAlpha(0)
        entry.window:SetVisible(true)
    end

    entry.open = true

    entry.window:MoveToFront()

    self:FadeWindow(entry, 255)
end

--- Takes a button's window back down.
--- @param key string|number Name or place on the bar.
function NAVBAR:Close(key)
    local entry = self:Find(key)

    if not entry then return end

    entry.open = false

    self:FadeWindow(entry, 0)
end

--- Puts a button's window up if it is down, and down if it is up.
--- @param key string|number Name or place on the bar.
function NAVBAR:Toggle(key)
    if self:IsOpen(key) then
        self:Close(key)
        return
    end

    self:Open(key)
end

--- Creates a navbar.
--- @param buttons table|nil Names to put on it, each one given a window.
--- @param parent table|nil Widget to parent it to, occ.root by default.
--- @return table navbar
function occ.navbar(buttons, parent)
    local navbar = occ.create("navbar", parent or occ.root)

    for _, name in ipairs(buttons or {}) do
        navbar:AddButton(name)
    end

    return navbar
end
