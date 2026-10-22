--[[
    example.lua
    A navbar and the windows its buttons open, built with occ.

    Insert opens and closes the lot - occ.open_bind is the key, occ.root is what
    fades.
]]

--> The bar runs the whole width of the screen along the top. Every name on it
--> gets a button and a window of its own, and the windows are top level rather
--> than children of the bar, so they can be dragged anywhere.
local nav = occ.navbar({"Configurations", "Environment", "Theme", "Credits"})

local configurations = nav:GetWindow("Configurations")
local environment = nav:GetWindow("Environment")
local theme = nav:GetWindow("Theme")
local credits = nav:GetWindow("Credits")

configurations:SetSize(450, 600)
environment:SetSize(420, 320)
theme:SetSize(250, 300)
credits:SetSize(260, 150)

--> A window is dropped under the bar the first time its button is pressed, and
--> keeps wherever it was left after that. Putting each one up here and moving it
--> is what gives them somewhere of their own to go - the ones that are then put
--> back down come up in the same place when their button is pressed. Every one
--> of them is put back down, so the example starts on the bar alone.
nav:Open("Configurations")
configurations:SetPos(40, 60)
nav:Close("Configurations")

nav:Open("Environment")
environment:SetPos(580, 60)
nav:Close("Environment")

nav:Open("Theme")
theme:SetPos(580, 400)
nav:Close("Theme")

nav:Open("Credits")
credits:SetPos(850, 400)
nav:Close("Credits")

--- Puts a slider on something, set up in the one go.
--- @param parent table
--- @param name string
--- @param from number
--- @param to number
--- @param value number
--- @param decimals number|nil Places to show, whole numbers by default.
--- @return table slider
local function slider(parent, name, from, to, value, decimals)
    local made = occ.slider(name, parent)

    made:SetRange(from, to)
    made:SetStep(decimals and 0.1 or 1)
    made:SetDecimals(decimals or 0)
    made:SetValue(value)

    return made
end

--[[
    Configurations - one group filling the window, with two groups of its own on
    the page the Combat tab shows.
]]

--> The first group parented to a window takes its main content area and stays
--> with it when the window is resized.
local main = occ.group(configurations, "Combat", "Visuals", "Misc", "Settings")

--> A group parented to another one lands on the page that is showing, which is
--> Combat, the first tab added being the one that starts off active. The groups
--> on a page are dealt into columns, so these two come out side by side at half
--> the page each.
local aim = occ.group(main, "Mouse", "Angle", "Trigger", "Melee")
local fake = occ.group(main, "Control", "Replication", "Anti Aim")

--> Widgets parented to a group land on the page that is showing, and the page
--> stacks them down it. Every other page is reached by the name of its tab.
local enable = occ.checkbox("Enable", aim)

enable:SetChecked(true)
enable:SetTextColor(occ.color(255, 225, 0))

--> Long enough that it is broken over several lines, the tooltip being capped
--> at a width and taking whatever height the lines come to.
occ.tooltip("risky and silly and meow meow :3 hello hello this is a really long string that carries on well past the width of the thing it is drawn in, which is rather the point of it, so mind the prediction, mind the field of view, and mind the cat", enable)

occ.checkbox("Prediction", aim)
occ.checkbox("Silent aim", aim)

slider(aim, "Speed", 0, 10, 3.5, 1)
slider(aim, "Field of view", 0, 180, 60)

--> One pick at a time, so the box carries a dash at its right and the list goes
--> back up as soon as something is taken off it.
local target = occ.dropdown("Target", aim, {"Head", "Chest", "Stomach", "Nearest"})

target:Pick("Head")

--> As many as are wanted, so this one carries the dots instead and stays down
--> while they are taken off it, the picks written across the box one after
--> another until they run out of room.
local hitboxes = occ.dropdown("Hitboxes", aim, {"Head", "Chest", "Stomach", "Arms", "Legs"})

hitboxes:SetMultiple(true)
hitboxes:Pick("Head")
hitboxes:Pick("Chest")

local angle = aim:GetPage("Angle")

occ.checkbox("Fake lag", angle)
occ.checkbox("Desync", angle)

slider(angle, "Yaw offset", -180, 180, 0)

local trigger = aim:GetPage("Trigger")

occ.checkbox("Enable", trigger)
occ.checkbox("Scoped only", trigger)

slider(trigger, "Delay", 0, 500, 120)

local melee = aim:GetPage("Melee")

occ.checkbox("Auto backstab", melee)

slider(melee, "Range", 0, 128, 64)

occ.checkbox("Enable", fake)
occ.checkbox("Pitch down", fake)

slider(fake, "Strength", 0, 100, 65)

local replication = fake:GetPage("Replication")

occ.checkbox("Fake duck", replication)
occ.checkbox("Slow walk", replication)

slider(replication, "Choke", 0, 14, 12)

local antiaim = fake:GetPage("Anti Aim")

occ.checkbox("Jitter", antiaim)
occ.checkbox("Spin", antiaim)

slider(antiaim, "Spin speed", 0, 360, 180)

--> A page with no groups on it stacks what it does have instead, so the rest of
--> the tabs carry their widgets straight on the page.
local visuals = main:GetPage("Visuals")

occ.checkbox("Boxes", visuals)
occ.checkbox("Names", visuals)
occ.checkbox("Health", visuals)
occ.checkbox("Skeletons", visuals)

slider(visuals, "Box thickness", 1, 5, 1)
slider(visuals, "Draw distance", 0, 4096, 2048)

local misc = main:GetPage("Misc")

occ.checkbox("Bunny hop", misc)
occ.checkbox("Auto strafe", misc)
occ.checkbox("Third person", misc)

slider(misc, "Hit chance", 0, 100, 70)
slider(misc, "Camera distance", 0, 200, 120)

local settings = main:GetPage("Settings")

occ.checkbox("Watermark", settings)
occ.checkbox("Notifications", settings)
occ.checkbox("Streamproof", settings)

slider(settings, "Menu scale", 50, 150, 100)

--> A modal is a window that holds the rest of the screen off while it is up,
--> behind a dark sheet. It starts down, and comes up in the middle of the
--> screen the first time it is opened.
local confirm = occ.modal("Reset settings")

confirm:SetSize(240, 130)

--> The sheet is left on occ.style.modal.overlay, so it follows the style and
--> whatever the Theme window does to it. SetOverlayColor would give this one a
--> colour of its own that the style no longer reaches.
--> A click on the sheet takes it down as well as the button on it does.
confirm:SetDismissable(true)

--> Anything can be parented to it. With no group on it, it stacks what it holds
--> down its main content area the way a window does.
occ.label("Put every setting back to how it was?", confirm)

local yes = occ.button("Reset", confirm)
local no = occ.button("Cancel", confirm)

yes:OnClick(function()
    occ.notification("Settings reset", 2)
    confirm:Close()
end)

no:OnClick(function()
    confirm:Close()
end)

occ.button("Reset settings", settings):OnClick(function()
    confirm:Open()
end)

--[[
    Environment - one group, a tab for each thing the menu knows about.
]]

local world = occ.group(environment, "Players", "Teams", "Groups", "Roles", "Npcs", "Entities")

--> A table panel on the Players page. The page has no groups on it, so it
--> stacks what it does have - the table takes the full width of the page and
--> grows down to whatever ends up in its rows.
local players = occ.tablepanel(world:GetPage("Players"), "Name", "Status")

local MOUSE_RIGHT = MOUSE_RIGHT or 108

--> One menu for the whole table, pointed at whichever row was right clicked.
local rowmenu = occ.popup()
local printname = occ.button("Print name", rowmenu)
local remove = occ.button("Remove", rowmenu)

--- A cell out of the row the menu was opened on. A cell is told which row it
--- ended up in as rows come and go, so this still points at the right one after
--- a row above it has been removed.
local clicked = nil

printname:SizeToContents()
remove:SizeToContents()

--> The pair are held at the width of the wider one, so the menu reads as a list
--> rather than two buttons of different lengths.
local wide = math.max(printname.w, remove.w)

printname:SetSize(wide, printname.h)
remove:SetSize(wide, remove.h)

--> Started under the accent bar rather than at the padding, so the first
--> button is not sat up against it.
printname:SetPos(rowmenu.padding, rowmenu:GetContentTop())
remove:SetPos(rowmenu.padding, rowmenu:GetContentTop() + printname.h + 3)

printname:OnClick(function()
    if clicked then
        lje.con_printf(tostring(players:GetCellText(clicked.row, "Name")))
    end

    rowmenu:Close()
end)

remove:OnClick(function()
    if clicked then
        players:RemoveRow(clicked.row)
        clicked = nil
    end

    rowmenu:Close()
end)

--- Opens the menu on the row a cell is in.
--- A right click goes to the deepest widget under the cursor - the label in the
--- cell when it lands on the text, the cell itself when it lands beside it - so
--- both are handed this.
--- @param cell table
--- @param widget table
local function rightclickable(cell, widget)
    function widget:OnMousePressed(mx, my, key)
        if key ~= MOUSE_RIGHT then return end

        clicked = cell

        rowmenu:Open(mx, my)
    end
end

for i = 1, 20 do
    local online = math.random() < 0.5

    --> The names and the statuses go in as text, which is a label in the cell.
    --> SetCell hands the label back, so the status can be coloured by what it
    --> says.
    local row = players:AddRow(string.format("Bot%02d", i))
    local status = players:SetCell(row, "Status", online and "online" or "offline")

    status:SetTextColor(online and occ.color(120, 220, 120) or occ.color(220, 120, 120))

    for _, column in ipairs({"Name", "Status"}) do
        local cell = players:GetCell(row, column)

        rightclickable(cell, cell)

        for _, child in ipairs(cell.children) do
            rightclickable(cell, child)
        end
    end
end

--[[
    Theme - every colour in occ.style, a list per group, editable where it sits.
]]

local style = occ.group(theme, "Style")

--- Is a value one of occ.color's, as against a table holding some?
--- @param value any
--- @return boolean
local function iscolour(value)
    return type(value) == "table" and type(value[1]) == "number"
end

--- The keys of a table in a settled order.
--- pairs hands them back in whatever order it likes, so the lists would come out
--- shuffled about differently on every reload.
--- @param t table
--- @return table keys
local function sorted(t)
    local keys = {}

    for key in pairs(t) do
        keys[#keys + 1] = key
    end

    table.sort(keys)

    return keys
end

--- Puts a picker on something that edits a colour where it sits.
--- @param parent table
--- @param name string
--- @param colour table The one out of occ.style to write back to.
local function editor(parent, name, colour)
    local picker = occ.colorpicker(name, parent)

    --> Set before the callback goes on, so putting the picker where the colour
    --> already is does not read as a change.
    picker:SetColor(colour)

    picker:OnChange(function(self, picked)
        --> The widgets read occ.style as they paint and this is the very table
        --> they read, so writing the numbers back into it changes the look there
        --> and then. Handing over a new table would leave them on the old one.
        for i = 1, 4 do
            colour[i] = picked[i]
        end
    end)
end

--- Puts a slider on something that edits a number where it sits.
--- @param parent table
--- @param name string
--- @param holder table The table out of occ.style it lives in.
--- @param key string
local function tweak(parent, name, holder, key)
    local value = holder[key]
    local made = occ.slider(name, parent)

    --> Anything named as a time is a run of seconds, and ten of them is far
    --> longer than any of these wants to be.
    if name:find("time", 1, true) then
        made:SetRange(0, 10)
        made:SetStep(0.05)
        made:SetDecimals(2)
        made:SetUnit("s")
    else
        --> The rest are not times and must not be capped as though they were -
        --> the scroll speed is 16, and a ten second cap would quietly halve it
        --> the moment this window was built. The range is put well clear of
        --> wherever the value already is.
        made:SetRange(0, math.max(100, value * 2))
        made:SetStep(1)
    end

    made:SetValue(value)

    made:OnChange(function(self, picked)
        holder[key] = picked
    end)
end

--> One menu, moved to whichever list was right clicked, rather than one of them
--> per list. It is top level, so it comes up over the window it is opened from.
local menu = occ.popup()
local randomise = occ.button("Randomise", menu)

--- The list the menu was opened on, and so the one the button works on.
local opened = nil

randomise:SizeToContents()
randomise:SetPos(menu.padding, menu:GetContentTop())

randomise:OnClick(function()
    if not opened then return end

    for _, child in ipairs(opened:GetChildren()) do
        if occ.isa(child, "colorpicker") then
            --> Hue anywhere, but not so dark that the thing it colours cannot be
            --> made out any more. The alpha is left where it was - rolling that
            --> as well would have borders disappearing.
            child:SetHSV(math.random() * 360, 0.3 + math.random() * 0.7, 0.35 + math.random() * 0.65)
        end
    end

    menu:Close()
end)

for _, name in ipairs(sorted(occ.style)) do
    local value = occ.style[name]

    if iscolour(value) then
        --> A colour sitting at the top of occ.style rather than in a group of
        --> its own, which is what the accent is.
        editor(style, name, value)
    elseif type(value) == "table" then
        local list = occ.expandable(name, style)

        --> Right clicking the row brings the menu up under the cursor, pointed
        --> at that list.
        list:OnRightClick(function(self, mx, my)
            opened = self

            menu:Open(mx, my)
        end)

        for _, key in ipairs(sorted(value)) do
            local entry = value[key]

            --> Fonts live in these tables too, and are neither of these.
            if iscolour(entry) then
                editor(list, key, entry)
            elseif type(entry) == "number" then
                tweak(list, key, value, key)
            end
        end
    end
end

--[[
    Credits.
]]

--> No group on it, so the window stacks what it holds straight down its main
--> content area.
local bx = occ.label("OCC - UI library for garry's mod", credits)
bx:SetTextColor(occ.color(126,69,162))
occ.label("ft. surface - i hated making the scroll", credits)
occ.label("Proving that a 2006 source game", credits)
occ.label("Is full of mad darkrp admins", credits)
occ.label("-- Developers --", credits)
occ.label("Pngmeow - This whole fuckass ui lib", credits)
occ.label("Claude - fixing my retarded errors (also making the layout)", credits)
occ.label("-- Contributors --", credits)
occ.label("bitchbot.cc - for the pretty ui", credits)
occ.label("-- Special(s)", credits)
occ.label("shiba - thanks for the pictures of bbot!", credits)
occ.label("exon - 'It looks bad'", credits)


occ.label("", credits)

--[[
    Welcome - a modal that comes up as the example loads, types a greeting out
    a letter at a time, and fades itself away once it has been read.
]]

local SysTime = SysTime or lje.secure.pull("SysTime", lje.state.menu)

local welcome = occ.modal("Welcome")

welcome:SetSize(260, 110)

welcome:SetResizable(false)

--> A click on the sheet puts it away early, for anyone who has seen it before.
welcome:SetDismissable(true)

local greeting = occ.label("Welcome to occ!", welcome)

--> Taller than the text, so the letters have room to hop without being cut off
--> by the window's clip.
greeting:SetAutoSize(false)
greeting:SetTall(30)

local tagline = occ.label(occ.sentences[math.random(#occ.sentences)], welcome)

tagline:SetAlign("center")
tagline:SetTextColor(occ.color(150, 150, 150))
tagline:SetAlpha(0)

--- Letters typed a second.
local speed = 14

--- Seconds a letter takes to drop into place once it is typed.
local drop = 0.3

--- Seconds the whole thing stays up once the last letter is in.
local hold = 2.5

local started = SysTime()
local typed = #greeting:GetText() / speed

--> The label is given a Paint of its own here rather than label.lua being
--> touched - every letter is drawn on its own, so each can hop and change
--> colour apart from the ones beside it.
function greeting:Paint(x, y, w, h)
    local alpha = self:GetAbsoluteAlpha() / 255
    local text = self:GetText()
    local now = SysTime() - started

    surface.SetFont(occ.font(self:GetFont()))

    --> Centred on the whole line rather than on what has been typed so far, so
    --> the letters already down do not slide over as more come in.
    local tw, th = surface.GetTextSize(text)
    local at = x + math.floor((w - tw) * 0.5 + 0.5)
    local base = y + math.floor((h - th) * 0.5 + 0.5)

    for i = 1, #text do
        local letter = text:sub(i, i)
        local lw = surface.GetTextSize(letter)

        --> How long ago this letter was typed, below nothing when it is still
        --> to come.
        local age = now - (i - 1) / speed

        if age > 0 then
            --> Drops in from above and settles, and after that bobs along in a
            --> wave that runs down the line.
            local settle = math.min(age / drop, 1)
            local fall = (1 - settle) ^ 2 * -10
            local bob = math.sin(now * 5 - i * 0.6) * 2 * settle

            local colour = occ.hsv(now * 90 + i * 18, 0.45, 1)

            surface.SetTextColor(colour[1], colour[2], colour[3], 255 * settle * alpha)
            surface.SetTextPos(at, base + math.floor(fall + bob + 0.5))
            surface.DrawText(letter)
        end

        at = at + lw
    end
end

local closing = false

--> Drives the rest of it off the same clock - the line under the greeting
--> fades in once the last letter is down, and the modal goes a while after.
function greeting:Think()
    local now = SysTime() - started

    tagline:SetAlpha(math.max(0, math.min((now - typed) / 0.5, 1)) * 255)

    if not closing and now > typed + hold then
        closing = true

        welcome:Close()
    end
end

welcome:Open()

--> Notifications go on occ.notifications rather than occ.root, so they are seen
--> whether the menu is open or not.
occ.notification("This is a example", 2)
occ.notification("Welcome to occ!", 2)
