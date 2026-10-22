--[[
    dropdown.lua
    A box with the pick written across it and a list that drops out of it when
    it is pressed. It takes one option at a time or as many as are wanted, and
    says which it is by the sign at its right - a plus for the one, turning to a
    minus while its list is down, and dots for the many.

    Two classes live here. The list is the rows inside the popup, and is no use
    on its own, so it is kept with the dropdown that makes it rather than given
    a file of its own.

    Example:
    root (base)
    |_group
    | |_dropdown
    |_popup
      |_dropdownlist
]]

local DROPDOWN = occ.register("dropdown", "base")
local LIST = occ.register("dropdownlist", "base")

local tween = lje.include("backend/tween.lua")

local MOUSE_LEFT = MOUSE_LEFT or 107

local SysTime = SysTime or lje.secure.pull("SysTime", lje.state.menu)

--> The rows and the box both cut their text to the room they have, and so does
--> the table panel, so the cutting lives on occ rather than in here.
local truncate = occ.truncate

--[[
    The list - the rows inside the popup.
]]

--- Initializes the list.
function LIST:Init()
    self.name = "dropdownlist"

    self.w = 100
    self.h = 0

    --- Height of one row.
    self.rowHeight = 14

    --- Space either side of a row's text.
    self.padding = 4

    --- Row under the cursor, 0 when the cursor is off the list.
    self.hoveredRow = 0

    --- How tall the list is heading for, the whole of it while the popup is up
    --- and nothing at all once it is on its way back down.
    self.target = 0

    --- The roll it is part way through, nil once it has settled.
    self.animation = nil

    --- Seconds the list takes to roll down or back up, nil for the one the
    --- style picks.
    self.revealtime = nil

    self.lastthink = SysTime()

    --- The dropdown this belongs to, asked what to draw and told what was
    --- pressed.
    self.dropdown = nil
end

--- How tall the list is with every row on it.
--- @return number
function LIST:GetFullHeight()
    local dropdown = self.dropdown

    return dropdown and #dropdown.options * self.rowHeight or 0
end

--- Seconds the list takes to roll down or back up.
--- @return number
function LIST:GetRevealTime()
    return self.revealtime or occ.style.dropdown.rolltime
end

--- Rolls the list down while the popup is up, and back up once it is not.
function LIST:Think()
    local now = SysTime()

    --> Capped the way the other widgets cap theirs, so a long gap between
    --> frames does not throw the roll straight to the end.
    local dt = math.min(now - self.lastthink, 0.25)

    self.lastthink = now

    local popup = self.parent
    local dropdown = self.dropdown

    --> Which way the list is heading is read off the dropdown rather than set
    --> when something asks for it, so a click off the popup rolls it up the
    --> same way the box does. The full height is read the same way, so an
    --> option added while it is down rolls out with the rest.
    local target = dropdown and dropdown.open and self:GetFullHeight() or 0

    if target ~= self.target then
        self.target = target

        local time = self:GetRevealTime()

        if time > 0 then
            --> Carries on from the height it is at, so a list caught part way
            --> through rolling up picks up rather than starting over.
            self.animation = tween.new(time, self, {h = target}, "outExpo")

            --> Nothing on a popup that is down is drawn, and Think comes off
            --> the paint pass, so this one has not run since the list was last
            --> up - which can be minutes. Stepping the roll by that gap would
            --> put it at its end before it had been seen, so the frame it
            --> starts on is not stepped at all and the next one carries a
            --> frame's worth like any other.
            return
        end

        self.animation = nil
        self.h = target
    end

    local animation = self.animation

    if animation and animation:update(dt) then
        self.animation = nil
    end

    --> The popup sizes itself to what is on it, so it is laid out again for
    --> every step of the roll.
    if animation and popup then
        popup:InvalidateLayout()
    end

    --> Rolled all the way back up, so there is nothing left to see and the
    --> popup can go. It is held up until this point rather than going down with
    --> the press, which is what gives the roll something to happen on.
    if target <= 0 and self.h <= 0 and popup and popup:IsOpen() then
        popup:Close(true)
    end
end

--- The row a cursor position is over.
--- @param mx number
--- @param my number
--- @return number index 0 when the cursor is not on a row.
function LIST:RowAt(mx, my)
    local dropdown = self.dropdown

    if not dropdown then return 0 end
    if not self:IsInBounds(mx, my) then return 0 end

    local _, y = self:GetAbsolutePos()
    local index = math.floor((my - y) / self.rowHeight) + 1

    if index < 1 or index > #dropdown.options then return 0 end

    return index
end

--- Paints the rows.
--- @param x number
--- @param y number
--- @param w number
--- @param h number
function LIST:Paint(x, y, w, h)
    local dropdown = self.dropdown

    if not dropdown then return end

    local alpha = self:GetAbsoluteAlpha() / 255
    local style = occ.style.dropdown
    local accent = occ.style.accent
    local tall = self.rowHeight

    surface.SetFont(occ.font(dropdown:GetFont()))

    for i, option in ipairs(dropdown.options) do
        local ry = y + (i - 1) * tall
        local picked = dropdown.picked[i]

        if i == self.hoveredRow then
            surface.SetDrawColor(style.rowhovered[1], style.rowhovered[2], style.rowhovered[3], style.rowhovered[4] * alpha)
            surface.DrawRect(x, ry, w, tall)
        end

        --> A picked row is said by the colour of its own text rather than by
        --> anything drawn beside it, so the accent picks it out without the
        --> list carrying a column of marks down its side.
        local text = picked and accent or style.rowtext
        local _, th = surface.GetTextSize(option)

        surface.SetTextColor(text[1], text[2], text[3], text[4] * alpha)
        surface.SetTextPos(x + self.padding, ry + math.floor((tall - th) * 0.5 + 0.5))
        surface.DrawText(truncate(option, w - self.padding * 2))
    end
end

--- Tracks the row under the cursor.
--- @param mx number
--- @param my number
--- @param dx number
--- @param dy number
function LIST:OnMouseMoved(mx, my, dx, dy)
    self.hoveredRow = self:RowAt(mx, my)
end

--- Drops the hover once the cursor leaves the list.
function LIST:OnCursorExited()
    LIST.BaseClass.OnCursorExited(self)

    self.hoveredRow = 0
end

--- Picks the row that was pressed.
--- @param mx number
--- @param my number
--- @param key number
function LIST:OnMousePressed(mx, my, key)
    if key ~= MOUSE_LEFT then return end

    local index = self:RowAt(mx, my)

    if index == 0 then return end

    self.dropdown:Pick(index)
end

--[[
    The dropdown itself.
]]

--- Initializes the dropdown.
function DROPDOWN:Init()
    self.name = "dropdown"

    self.w = 100
    self.h = 22

    --- Text drawn above the box.
    self.text = ""

    --- Everything that can be picked, in the order it was added.
    self.options = {}

    --- Which of them are picked, keyed by their place in that list.
    self.picked = {}

    --- Can more than one be picked at a time? The sign at the right of the box
    --- says which way it is set.
    self.multiple = false

    --- Height of the box itself, the outline round it included.
    self.boxHeight = 16

    --- Space between the label and the box under it. Measured off the whole of
    --- what the font reports, descenders and all.
    self.labelGap = 1

    --- Space either side of what is written in the box.
    self.padding = 4

    --- Space between the text and the sign at the right of it.
    self.signGap = 4

    --- What the text in the box is nudged by once it has been centred on it,
    --- for a font that sits high or low in what it reports as its height.
    self.textY = 0

    --- Font it draws with, a name occ.font knows, nil for the one the style
    --- picks.
    self.font = nil

    --- Is the list meant to be down? Not the same as the popup being up - one
    --- rolling back into the box is still on screen until it has.
    self.open = false

    --- Has it been measured since the text last changed?
    self.sized = false

    --- The popup the list is on, made the first time one is wanted.
    self.popup = nil
    self.list = nil
end

--- The box, local to the dropdown. The label sits above it rather than on it,
--- so the box starts below the height of the text.
--- @return number x
--- @return number y
--- @return number w
--- @return number h
function DROPDOWN:GetBoxBounds()
    surface.SetFont(occ.font(self:GetFont()))

    local _, th = surface.GetTextSize(self.text)
    local top = th + self.labelGap

    return 0, top, self.w, self.boxHeight
end

--- Takes the height of the label and the box under it.
--- The width is left to whatever put the dropdown where it is - a stack hands
--- it the full width of the area.
function DROPDOWN:PerformLayout()
    if self.sized then return end

    local _, th = self:Measure()

    self.sized = true

    if self.h == th then return end

    self.h = th

    --> Whatever is laying the dropdown out goes by its height, and
    --> InvalidateLayout stops at a widget already waiting for a layout - which
    --> this one is, being in the middle of its own - so the parent is told from
    --> here.
    if self.parent then
        self.parent:InvalidateLayout()
    end
end

--- Measures what the dropdown needs to be.
--- @return number w
--- @return number h
function DROPDOWN:Measure()
    surface.SetFont(occ.font(self:GetFont()))

    local tw, th = surface.GetTextSize(self.text)
    local vw = surface.GetTextSize(self:GetPickedText())

    --> The label sits above the box, so it is the two heights added rather than
    --> whichever is the taller of them.
    return math.max(tw, vw) + self.padding * 2, th + self.labelGap + self.boxHeight
end

--- The sign at the right of the box, which says how many can be picked.
--- The one that takes a single pick shows a plus while its list is up its
--- sleeve and a minus while the list is down, so the sign says what pressing
--- the box does next rather than only what the box is. The many keeps its dots
--- either way - there is no one thing to add or take away.
--- @return string
function DROPDOWN:GetSign()
    if self.multiple then return "..." end

    return self:IsOpen() and "-" or "+"
end

--- Paints the label, the box and what is picked in it.
--- @param x number
--- @param y number
--- @param w number
--- @param h number
function DROPDOWN:Paint(x, y, w, h)
    local alpha = self:GetAbsoluteAlpha() / 255
    local style = occ.style.dropdown
    local line = occ.style.border.window
    local line2 = occ.style.border.base

    surface.SetFont(occ.font(self:GetFont()))

    --> The label goes above the box, so it is drawn first and the box is put
    --> under it.
    local text = self.hovered and style.texthovered or style.text

    surface.SetTextColor(text[1], text[2], text[3], text[4] * alpha)
    surface.SetTextPos(x + 3, y)
    surface.DrawText(self.text)

    local bx, by, bw, bh = self:GetBoxBounds()

    bx, by = x + bx, y + by

    local fill = self.hovered and style.hovered or style.background

    surface.SetDrawColor(fill[1], fill[2], fill[3], fill[4] * alpha)
    surface.DrawRect(bx, by, bw, bh)

    --> Shading down off the top of the box, over the fill and under the borders
    --> so the lines round it keep their bite.
    local fade = style.fade

    surface.SetDrawColor(fade[1], fade[2], fade[3], fade[4] * alpha)
    surface.SetMaterial(occ.material("gradient-down"))
    surface.DrawTexturedRect(bx, by, bw, bh)

    surface.SetDrawColor(line[1], line[2], line[3], line[4] * alpha)
    surface.DrawOutlinedRect(bx, by, bw, bh)

    --> A pixel inside the black one, so the box is edged the way the rest of
    --> the menu is.
    surface.SetDrawColor(line2[1], line2[2], line2[3], line2[4] * alpha)
    surface.DrawOutlinedRect(bx + 1, by + 1, math.max(0, bw - 2), math.max(0, bh - 2))

    local sign = self:GetSign()
    local sw, sh = surface.GetTextSize(sign)

    --> Rounded onto a pixel rather than left half way between two of them, so
    --> what is in the box sits level rather than a shade above the middle.
    surface.SetTextColor(style.sign[1], style.sign[2], style.sign[3], style.sign[4] * alpha)
    surface.SetTextPos(bx + bw - self.padding - sw, by + math.floor((bh - sh) * 0.5 + 0.5) + self.textY)
    surface.DrawText(sign)

    --> What is left of the box once the sign and the padding either side of it
    --> are taken off is what the picks have to fit in, and they are cut down to
    --> it rather than running on under the sign.
    local shown = self:GetPickedText()
    local room = bw - self.padding * 2 - sw - self.signGap
    local _, vh = surface.GetTextSize(shown)

    surface.SetTextColor(style.value[1], style.value[2], style.value[3], style.value[4] * alpha)
    surface.SetTextPos(bx + self.padding, by + math.floor((bh - vh) * 0.5 + 0.5) + self.textY)
    surface.DrawText(truncate(shown, math.max(0, room)))
end

--- Makes the popup and the list on it, the first time one is wanted.
--- @return table popup
function DROPDOWN:GetPopup()
    if self.popup then return self.popup end

    self.popup = occ.popup()

    --> Nothing fades - the list rolls down out of the box and back up into it,
    --> and the popup is only what it is drawn on.
    self.popup.fadetime = 0

    --> A click off the popup asks it to go down. The list is rolled up instead
    --> and takes the popup down at the end of that, so the two ways of closing
    --> it come out the same.
    local dropdown = self

    self.popup.holdclose = function()
        dropdown.open = false

        return false
    end

    local list = occ.create("dropdownlist", self.popup)

    list:SetPos(self.popup.padding, self.popup:GetContentTop())
    list.dropdown = self

    self.list = list

    return self.popup
end

--- Drops the list out of the box.
function DROPDOWN:OpenPopup()
    local popup = self:GetPopup()
    local x, y = self:GetAbsolutePos()
    local _, by, bw, bh = self:GetBoxBounds()

    --> As wide as the box it came out of, so the list lines up under it. How
    --> tall it is comes from the roll, which starts as soon as this is set.
    self.list:SetWide(math.max(0, bw - popup.padding * 2))

    self.open = true

    popup:Open(x, y + by + bh)
end

--- Rolls the list back up. The popup goes down at the end of the roll rather
--- than here, so the way back in is as seen as the way out.
function DROPDOWN:ClosePopup()
    self.open = false
end

--- Is the list down? One part way through rolling back up already reads as
--- closed, so pressing the box catches it and rolls it out again.
--- @return boolean
function DROPDOWN:IsOpen()
    return self.open
end

--- Drops the list out when the box is pressed.
--- Only the box - the label above it is not a button.
--- @param mx number
--- @param my number
--- @param key number
function DROPDOWN:OnMousePressed(mx, my, key)
    if key ~= MOUSE_LEFT then return end

    local x, y = self:GetAbsolutePos()
    local _, by, bw, bh = self:GetBoxBounds()

    if mx < x or mx > x + bw then return end
    if my < y + by or my > y + by + bh then return end

    if self:IsOpen() then
        self:ClosePopup()
        return
    end

    self:OpenPopup()
end

--- Adds an option to the end of the list.
--- @param text string
--- @return number index Where it landed.
function DROPDOWN:AddOption(text)
    self.options[#self.options + 1] = text

    self.sized = false

    self:InvalidateLayout()

    return #self.options
end

--- Puts a whole list of options on, dropping whatever was there.
--- @param options table
function DROPDOWN:SetOptions(options)
    self.options = {}
    self.picked = {}

    for _, text in ipairs(options or {}) do
        self:AddOption(text)
    end
end

--- Gets the options, in the order they were added.
--- @return table
function DROPDOWN:GetOptions()
    return self.options
end

--- Finds an option by its text or by its place in the list.
--- @param key string|number
--- @return number|nil index
function DROPDOWN:FindOption(key)
    if type(key) == "number" then
        return self.options[key] and key or nil
    end

    for i, option in ipairs(self.options) do
        if option == key then
            return i
        end
    end

    return nil
end

--- Sets whether more than one option can be picked at a time.
--- Coming back to the one, everything but the first pick is dropped - a box
--- that can only hold one cannot be left holding several.
--- @param multiple boolean
function DROPDOWN:SetMultiple(multiple)
    multiple = multiple and true or false

    if self.multiple == multiple then return end

    self.multiple = multiple

    if not multiple then
        local first = self:GetPicked()

        self.picked = {}

        if first then
            self.picked[first] = true
        end
    end

    self:OnChange()
end

--- Can more than one option be picked at a time?
--- @return boolean
function DROPDOWN:IsMultiple()
    return self.multiple
end

--- Picks an option, or unpicks it when it was already picked and the dropdown
--- takes more than one. The list goes back up on a pick when it only takes the
--- one, there being nothing left to pick.
--- @param key string|number Text or place in the list.
function DROPDOWN:Pick(key)
    local index = self:FindOption(key)

    if not index then return end

    if self.multiple then
        self.picked[index] = not self.picked[index] or nil

        self.sized = false

        self:InvalidateLayout()
        self:OnChange()

        return
    end

    self.picked = {[index] = true}

    self.sized = false

    self:InvalidateLayout()
    self:ClosePopup()
    self:OnChange()
end

--- Drops an option's pick.
--- @param key string|number Text or place in the list.
function DROPDOWN:Unpick(key)
    local index = self:FindOption(key)

    if not index then return end
    if not self.picked[index] then return end

    self.picked[index] = nil

    self.sized = false

    self:InvalidateLayout()
    self:OnChange()
end

--- Drops every pick.
function DROPDOWN:Clear()
    if not next(self.picked) then return end

    self.picked = {}

    self.sized = false

    self:InvalidateLayout()
    self:OnChange()
end

--- Is an option picked?
--- @param key string|number Text or place in the list.
--- @return boolean
function DROPDOWN:IsPicked(key)
    local index = self:FindOption(key)

    return index ~= nil and self.picked[index] == true
end

--- Gets the pick, which is the first of them when there are several.
--- @return number|nil index
--- @return string|nil text
function DROPDOWN:GetPicked()
    for i, option in ipairs(self.options) do
        if self.picked[i] then
            return i, option
        end
    end

    return nil
end

--- Gets every pick, in the order the options were added.
--- @return table indexes
--- @return table texts
function DROPDOWN:GetPickedAll()
    local indexes, texts = {}, {}

    for i, option in ipairs(self.options) do
        if self.picked[i] then
            indexes[#indexes + 1] = i
            texts[#texts + 1] = option
        end
    end

    return indexes, texts
end

--- What is written across the box - the pick, or the picks one after another
--- when there are several.
--- @return string
function DROPDOWN:GetPickedText()
    local _, texts = self:GetPickedAll()

    return table.concat(texts, ", ")
end

--- Sets what the dropdown does when the picks change, or does it.
--- Handed a function it takes that function on. Handed nothing it runs the one
--- it was given, which is how a pick gets there.
---     dropdown:OnChange(function(self) ... end)
--- Replacing the method outright still works and takes the place of both.
--- @param callback function|nil
function DROPDOWN:OnChange(callback)
    if type(callback) == "function" then
        self.callback = callback
        return
    end

    if self.callback then
        self.callback(self)
    end
end

--- Sets the text above the box.
--- @param text string
function DROPDOWN:SetText(text)
    if self.text == text then return end

    self.text = text
    self.sized = false

    self:InvalidateLayout()
end

--- Gets the text above the box.
--- @return string text
function DROPDOWN:GetText()
    return self.text
end

--- Sets the font the text draws with.
--- @param font string|nil Name occ.font knows, nil for the style's own.
function DROPDOWN:SetFont(font)
    if self.font == font then return end

    self.font = font
    self.sized = false

    self:InvalidateLayout()
end

--- Gets the font the text draws with.
--- @return string font
function DROPDOWN:GetFont()
    return self.font or occ.style.dropdown.font
end

--- Creates a dropdown.
--- @param text string|nil Text above the box, also used as its name.
--- @param parent table|nil Widget to parent it to, occ.root by default.
--- @param options table|nil Options to put on it right away.
--- @return table dropdown
function occ.dropdown(text, parent, options)
    local dropdown = occ.create("dropdown", parent or occ.root)

    if text then
        dropdown:SetName(text)
        dropdown:SetText(text)
    end

    if options then
        dropdown:SetOptions(options)
    end

    return dropdown
end
