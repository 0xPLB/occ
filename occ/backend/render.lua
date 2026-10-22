local menusurface = lje.secure.pull("surface", lje.state.menu)
local Material = lje.secure.pull("Material", lje.state.menu)
local shouldrender = false
--> Named apart from the render function below, which would otherwise shadow it.
local renderlib = render or lje.secure.pull("render", lje.state.menu)

--> Not every universe has one to hand. Without it the tree draws the way it
--> always did, just unclipped, rather than falling over.
local scissor = renderlib and renderlib.SetScissorRect

--- Clip rects in force, innermost last, as {x1, y1, x2, y2}.
local clips = {}

--- Narrows the clip to a rect and pushes it on.
--- SetScissorRect does not nest, so a widget that clips takes the intersection
--- of what it asks for with whatever is already clipping it.
--- @param x number
--- @param y number
--- @param w number
--- @param h number
local function pushclip(x, y, w, h)
    local x1, y1, x2, y2 = x, y, x + w, y + h
    local top = clips[#clips]

    if top then
        x1, y1 = math.max(x1, top[1]), math.max(y1, top[2])
        x2, y2 = math.min(x2, top[3]), math.min(y2, top[4])
    end

    --> Two rects that miss each other come out inside out, which is an empty
    --> clip rather than a wrapped one.
    x2, y2 = math.max(x1, x2), math.max(y1, y2)

    clips[#clips + 1] = {x1, y1, x2, y2}

    if scissor then
        scissor(x1, y1, x2, y2, true)
    end
end

--- Drops the innermost clip, going back to the one around it.
local function popclip()
    clips[#clips] = nil

    if not scissor then return end

    local top = clips[#clips]

    if top then
        scissor(top[1], top[2], top[3], top[4], true)
    else
        scissor(0, 0, 0, 0, false)
    end
end

--- Root of the hierarchy, every widget hangs off of it.
local tween = lje.include("backend/tween.lua")

local SysTime = SysTime or lje.secure.pull("SysTime", lje.state.menu)

local ScrW = ScrW or lje.secure.pull("ScrW", lje.state.menu)
local ScrH = ScrH or lje.secure.pull("ScrH", lje.state.menu)

--> occ.opentime overrides how long the overlay takes to fade, nil for the one
--> the style picks and 0 for no fade at all. It is left alone here rather than
--> given a value, so one set before a reload survives it.

--- Seconds the overlay takes to fade in or out.
--- @return number
function occ.getopentime()
    return occ.opentime or occ.style.overlay.opentime
end

--- Is the overlay open? It fades out when it is not.
--> Kept across a reload, so hitting the bind and then reloading does not bring
--> the tree back up on its own.
if occ.opened == nil then
    occ.opened = true
end

--- The fade the overlay is part way through, nil once it has settled.
--> Kept on occ rather than in a local. boot.lua and main.lua each run this
--> file, and the second run swaps occ.open out for its own - so with a local,
--> the fade occ.open starts and the one render steps on can be two different
--> ones. After a disconnect only the menu's render is left, and a fade started
--> by the client's occ.open would never move. Cleared here because the tree is
--> new and already sits at the alpha it would have been fading to.
occ.fade = nil

local lastthink = SysTime()

occ.root = occ.create("base")
occ.root:SetName("root")

--> The tree is built fresh on every reload, so it comes back at whatever the
--> overlay was left at rather than always at full.
occ.root:SetAlpha(occ.opened and 255 or 0)

--- Root of its own for anything that has to carry on with the overlay shut.
--- The fade is put on occ.root and runs down everything under it, so a widget
--- that is not meant to go with it cannot hang off that.
occ.notifications = occ.create("base")
occ.notifications:SetName("notifications")

--- Takes everything a script put on the screen back off it.
--- A hot reload re-runs a script's main.lua but not necessarily occ's, so the
--- tree survives it and a menu built again lands next to the old one. Call this
--- before building the menu so the reload replaces it instead.
--- @param script string|nil Script name, the calling script by default.
function occ.clear(script)
    script = script or lje.env.current_script()

    --> With no script to go by, clearing would mean clearing everyone's.
    if not script then return end

    for _, root in ipairs({occ.root, occ.notifications}) do
        local children = root:GetChildren()

        for i = #children, 1, -1 do
            local child = children[i]

            if child.script == script then
                --> Notifications keep a list of their own outside the tree.
                if child.Remove then
                    child:Remove()
                else
                    child:SetParent(nil)
                end
            end
        end
    end
end

--- Opens or closes the whole overlay.
--- occ.root is the top of the tree and GetAbsoluteAlpha runs all the way down
--- it, so fading the root takes every widget on it along.
--- @param open boolean
function occ.open(open)
    open = open and true or false

    if occ.opened == open then return end

    occ.opened = open

    --> The wheel is read off a running total and nothing consumes it while the
    --> overlay is shut, so whatever piled up is dropped here rather than
    --> arriving as one long scroll on the way back in.
    if open then
        occ.mousewheel()
    end

    local time = occ.getopentime()

    if time <= 0 then
        occ.fade = nil

        occ.root:SetAlpha(open and 255 or 0)
        return
    end

    --> Carries on from whatever alpha it is at, so hitting the bind twice in
    --> quick succession picks up rather than starting over.
    occ.fade = tween.new(time, occ.root, {alpha = open and 255 or 0}, "outQuad")
end

--- Opens the overlay if it is shut, shuts it if it is open.
function occ.toggle()
    occ.open(not occ.opened)
end

--- Is the overlay open?
--- @return boolean
function occ.isopen()
    return occ.opened
end

--- Paints a widget and its children, lowest z-index first.
--- Children stay sorted by SortChildren, so array order is draw order.
--- @param widget table
local function paint(widget)
    widget:Think()

    if not widget.visible then return end

    local children = widget.children
    local x, y = widget:GetAbsolutePos()

    widget:Paint(x, y, widget.w, widget.h)

    --> The widget's own Paint is never clipped, only what it holds - a group
    --> draws its frame and then keeps its pages inside it.
    local cx, cy, cw, ch = widget:GetClipBounds()
    local clipping = cx ~= nil

    if clipping then
        pushclip(cx, cy, cw, ch)
    end

    --> A widget can drop itself out of the tree from its own Think, which
    --> shifts every sibling after it one index to the left. Staying on the
    --> index when that happens keeps the rest of them from being skipped.
    local i = 1

    while i <= #children do
        local child = children[i]

        paint(child)

        if children[i] == child then
            i = i + 1
        end
    end

    if clipping then
        popclip()
    end
end

local function render()
    --> preinit points the surface global at the client once a game has been
    --> loaded, so with no client alive the tree has to draw with the menu's own.
    if not lje.state.client then
        surface = menusurface
    end

    local now = SysTime()

    --> Capped the way the widgets cap their own, so a long gap between frames
    --> does not throw the fade straight to the end.
    local dt = math.min(now - lastthink, 0.25)

    lastthink = now

    if occ.bindpressed() then
        occ.toggle()
    end

    if occ.fade and occ.fade:update(dt) then
        occ.fade = nil
    end

    --> Before the overlay is skipped below, so animated colours keep reaching
    --> whoever uses them with it shut.
    if occ.tickpickers then
        occ.tickpickers()
    end

    --> The roots are the screen, so anything meant to span it has something to
    --> take its width from.
    local sw, sh = ScrW(), ScrH()

    if occ.root.w ~= sw or occ.root.h ~= sh then
        occ.root:SetSize(sw, sh)
        occ.notifications:SetSize(sw, sh)
    end

    --> Shut and faded out, so there is nothing left of the overlay to draw and
    --> nothing that should be taking the cursor either. The notifications are
    --> not part of it and go up either way.
    if occ.opened or occ.root:GetAlpha() > 0 then
        --> An overlay on its way out is still on screen but has stopped
        --> listening, so a click during the fade does not land on something
        --> that is going.
        if occ.opened then
            occ.root:ProcessInputInternal()
        end

        occ.root:PerformLayoutInternal()

        paint(occ.root)
    end

    --> Last, so they sit over the overlay rather than under it.
    occ.notifications:PerformLayoutInternal()

    paint(occ.notifications)

    --> A widget that errors out of its Paint never gets to drop its clip, and
    --> a scissor rect left on would take the rest of the frame down with it -
    --> everything the game draws after this, not just the tree.
    for i = #clips, 1, -1 do
        clips[i] = nil
    end

    if scissor then
        scissor(0, 0, 0, 0, false)
    end
end

--> boot.lua and main.lua each run this file, and each run's render draws with
--> its own state's SysTime, ScrW, surface and so on. The client's are dead
--> once it disconnects, so each is kept and the one for the live state is used.
if lje.state.client then
    occ.clientrender = render
else
    occ.menurender = render
end

--- Draws the whole tree - input, layout, fades and paint - for one frame.
--- occ hooks nothing itself; the script using it calls this once a frame.
function occ.render()
    if lje.state.client and occ.clientrender then
        occ.clientrender()
    elseif occ.menurender then
        occ.menurender()
    end
end
