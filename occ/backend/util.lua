local occ = occ

local font = {}
local fontdata = {}

--- Universes each font id has already been handed to surface.CreateFont in.
--- A font belongs to the universe that created it, so an id drawn from both
--- the menu and the client has to be created once in each.
local created = {}

local material = {}
local materialdata = {}

local Material = lje.secure.pull("Material", lje.state.menu)

--- Widgets draw through the surface global - the menu universe has none of its
--- own in the secure state, so it gets pulled out of it.
surface = surface or lje.secure.pull("surface", lje.state.menu)

--- Registers a widget class, deriving it from another one.
--- Anything the class does not define itself falls through to its base class,
--- so a widget only has to override what it actually changes.
--- @param name string Name of the class, also its key in occ.meta.
--- @param base string|nil Class to derive from - nil for a root class.
--- @return table meta Class table to define methods on.
function occ.register(name, base)
    local meta = occ.meta[name] or {}
    local parent = base and occ.meta[base] or nil

    meta.__index = meta
    meta.__name = name

    --- Class this one derives from, used to reach an overridden method.
    meta.BaseClass = parent

    setmetatable(meta, {__index = parent})

    occ.meta[name] = meta

    return meta
end

--- Creates a widget of a registered class.
--- @param name string Name of a registered class.
--- @param parent table|nil Widget to parent the new widget to.
--- @return table|nil widget
function occ.create(name, parent)
    local meta = occ.meta[name]

    if not meta then
        lje.con_printf(string.format("$#ff0000{occ}->unknown widget class %s ", tostring(name)))
        return nil
    end

    local widget = setmetatable({}, meta)

    --- Init runs from the root of the hierarchy down to the class itself, so
    --- every class in the chain gets its defaults without the derived class
    --- having to call its parent by hand. rawget keeps an inherited Init from
    --- being run twice.
    local chain, class = {}, meta

    while class do
        local init = rawget(class, "Init")

        if init then
            table.insert(chain, 1, init)
        end

        class = rawget(class, "BaseClass")
    end

    for i = 1, #chain do
        chain[i](widget)
    end

    --> The script that made it, so occ.clear can take a script's widgets back
    --> off the screen when that script is reloaded. nil from a deferred
    --> callback, where lje has no script context.
    widget.script = lje.env.current_script()

    if parent then
        widget:SetParent(parent)
    end

    return widget
end

--- The class a widget was made from.
--- The name on a widget is a label its owner picks, so the class it came out of
--- is read off its metatable instead.
--- @param widget table|nil
--- @return string|nil name
function occ.classof(widget)
    local class = getmetatable(widget)

    return class and class.__name or nil
end

--- Cuts a word with nothing to break on down into pieces that fit a width.
--- @param word string
--- @param width number
--- @return table pieces
local function cutword(word, width)
    local pieces = {}
    local from = 1

    while from <= #word do
        local last = from
        local to = from

        --> Grown a character at a time until it no longer fits, which only
        --> happens to a word too long for a line of its own - the words that do
        --> fit never come through here.
        while to <= #word and surface.GetTextSize(word:sub(from, to)) <= width do
            last = to
            to = to + 1
        end

        pieces[#pieces + 1] = word:sub(from, last)
        from = last + 1
    end

    return pieces
end

--- Cuts a run of text down until it fits a width, with dots on the end to say
--- that it was cut.
--- The font has to be set before this is called.
--- @param text string
--- @param width number
--- @return string
function occ.truncate(text, width)
    if surface.GetTextSize(text) <= width then return text end

    local dots = "..."
    local dw = surface.GetTextSize(dots)

    --> A character at a time from the end rather than a guess at how many go -
    --> the font is not fixed width, so there is no count to work out.
    for i = #text - 1, 1, -1 do
        if surface.GetTextSize(text:sub(1, i)) + dw <= width then
            return text:sub(1, i) .. dots
        end
    end

    --> Not even the dots fit, so there is nothing worth drawing.
    return ""
end

--- Breaks a run of text into lines no wider than a width.
--- Every word is measured the once and the lines are added up out of those,
--- rather than the whole of a line being measured again for every word put on
--- it. The newlines the text carries of its own are kept, and a word too wide
--- for a line on its own is cut where it runs out rather than running off the
--- end of it.
--- The font has to be set before this is called.
--- @param text string
--- @param width number Widest a line is allowed to be.
--- @return table lines
function occ.wrap(text, width)
    local lines = {}
    local space = surface.GetTextSize(" ")
    local at = 1

    while true do
        local stop = text:find("\n", at, true)
        local paragraph = text:sub(at, (stop or #text + 1) - 1)

        local line, lw = nil, 0

        for word in paragraph:gmatch("%S+") do
            local ww = surface.GetTextSize(word)

            if ww > width then
                --> Nothing to break it on, so whatever is on the line goes down
                --> as it is and the word is cut into lines of its own. The last
                --> piece carries on being filled by the words after it.
                if line then
                    lines[#lines + 1] = line
                end

                local pieces = cutword(word, width)

                for i = 1, #pieces - 1 do
                    lines[#lines + 1] = pieces[i]
                end

                line = pieces[#pieces]
                lw = line and surface.GetTextSize(line) or 0
            elseif not line then
                line, lw = word, ww
            elseif lw + space + ww <= width then
                line = line .. " " .. word
                lw = lw + space + ww
            else
                lines[#lines + 1] = line
                line, lw = word, ww
            end
        end

        lines[#lines + 1] = line or ""

        if not stop then break end

        at = stop + 1
    end

    return lines
end

--- Checks whether a widget is of a class, or of one deriving from it.
--- The name of a widget is a label its owner picks, so the class it was created
--- from is what gets walked here.
--- @param widget table|nil
--- @param name string Name of a registered class.
--- @return boolean
function occ.isa(widget, name)
    local class = getmetatable(widget)

    while class do
        if class.__name == name then
            return true
        end

        class = rawget(class, "BaseClass")
    end

    return false
end

local characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
local charactercount = #characters

local random = math.random
local sub = string.sub
local concat = table.concat

--- Pre-allocated table for occ.randomstring()
local stringtable = {}

--- Generates a random string, lje-util is not around in the menu to do it.
--- @param length integer? Default is 25
--- @return string
function occ.randomstring(length)
    length = length or 25

    for i = 1, length do
        local at = random(1, charactercount)
        stringtable[i] = sub(characters, at, at)
    end

    return concat(stringtable, "", 1, length)
end

--- Creates a new color
--- @param r integer
--- @param g integer
--- @param b integer
--- @param a integer
--- @return color
function occ.color(r,g,b,a)
    return {
        r, g, b, a or 255
    }
end

--- Makes a shade of a colour, a percentage of the brightness it has now.
--- 100 hands the colour back as it was, 80 takes it to four fifths of itself
--- and 120 lifts it by a fifth. A channel that runs out tops out rather than
--- wrapping round, and the alpha is carried over, so a shade covers whatever
--- the colour it came from did.
--- @param percent number Percentage of the colour's brightness, 100 being it.
--- @param colour color
--- @return color
function occ.shcolor(percent, colour)
    local scale = percent / 100
    local shade = {}

    for i = 1, 3 do
        shade[i] = math.max(0, math.min(255, math.floor(colour[i] * scale + 0.5)))
    end

    shade[4] = colour[4] or 255

    return shade
end


--- Makes a colour from hue, saturation and value.
--- @param h number Degrees, 0 to 360, wrapping round.
--- @param s number 0 to 1.
--- @param v number 0 to 1.
--- @param a integer? 0 to 255, opaque by default.
--- @return color
function occ.hsv(h, s, v, a)
    h = h % 360

    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b = c, 0, x

    local at = math.floor(h / 60)

    if at == 0 then
        r, g, b = c, x, 0
    elseif at == 1 then
        r, g, b = x, c, 0
    elseif at == 2 then
        r, g, b = 0, c, x
    elseif at == 3 then
        r, g, b = 0, x, c
    elseif at == 4 then
        r, g, b = x, 0, c
    end

    return occ.color(
        math.floor((r + m) * 255 + 0.5),
        math.floor((g + m) * 255 + 0.5),
        math.floor((b + m) * 255 + 0.5),
        a or 255)
end

--- Takes a colour apart into hue, saturation and value.
--- The other way round from occ.hsv, for reading a colour that was not picked.
--- @param colour table From occ.color.
--- @return number hue Degrees, 0 to 360.
--- @return number saturation 0 to 1.
--- @return number value 0 to 1.
function occ.tohsv(colour)
    local r, g, b = colour[1] / 255, colour[2] / 255, colour[3] / 255

    local high = math.max(r, g, b)
    local low = math.min(r, g, b)
    local range = high - low

    local hue = 0

    --> Grey has no hue to speak of, and working one out would be dividing by
    --> nothing.
    if range > 0 then
        if high == r then
            hue = ((g - b) / range) % 6
        elseif high == g then
            hue = (b - r) / range + 2
        else
            hue = (r - g) / range + 4
        end

        hue = hue * 60
    end

    return hue, high > 0 and range / high or 0, high
end

--- Universe the secure state is drawing for right now. The menu tree only
--- paints while no client state is alive, which is the same split render.lua
--- picks its surface on.
--- @return string
local function universe()
    return lje.state.client and "client" or "menu"
end

--- Do two font definitions describe the same font? Shallow is enough, the
--- data surface.CreateFont takes is flat.
--- @param a table|nil
--- @param b table
--- @return boolean
local function samefont(a, b)
    if (not a) then
        return false
    end

    for k, v in pairs(a) do
        if (b[k] ~= v) then
            return false
        end
    end

    for k, v in pairs(b) do
        if (a[k] ~= v) then
            return false
        end
    end

    return true
end

--- Creates a new font, if cached returns the cached result.
--- Passing data defines the font and hands back its id, passing just a name
--- fetches that id again.
--- @param name string
--- @param data table|nil
--- @return string|nil
function occ.font(name, data)
    if (data) then
        local id = font[name]

        --> boot.lua and main.lua both run style.lua, and main.lua runs again
        --> on every map change, disconnect and hot reload. Minting a fresh id
        --> for a definition that has not changed would orphan the one the
        --> menu tree is still drawing with, so hand the same one back.
        if (id and samefont(fontdata[id], data)) then
            --> The client state - and every font in it - is destroyed between
            --> those runs, so nothing it created can be assumed to still be
            --> there. Let both universes define the id again on next draw.
            created[id] = nil

            return id
        end

        id = occ.randomstring()

        font[name] = id
        fontdata[id] = data

        return id
    end

    local id = font[name]

    if (not id) then
        return nil
    end

    local done = created[id]

    if (not done) then
        done = {}
        created[id] = done
    end

    --> Defined lazily on first draw, and once per universe - the menu and the
    --> client keep their own fonts, so an id created in one does not exist in
    --> the other and surface.SetFont there would reject it.
    local at = universe()

    if (not done[at]) then
        surface.CreateFont(id, fontdata[id])
        done[at] = true
    end

    return id
end

--- Returns a fontdata for id
--- @param id string
function occ.fontdata(id)
    return fontdata[id]
end

--- Creates a material and caches it under a uid, fetched back by name.
--- @param name string
--- @param path string|nil
--- @return IMaterial|nil
function occ.material(name, path)
    local uid = material[name]

    if (uid) then
        return materialdata[uid]
    end

    if (not path) then
        return nil
    end

    uid = occ.randomstring()

    material[name] = uid
    materialdata[uid] = Material(path)

    return materialdata[uid]
end
