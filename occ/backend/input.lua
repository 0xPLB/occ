local occ = occ

--> The menu universe has no globals of its own in the secure state, preinit
--> only pulls the client ones in - so they get pulled out of the menu instead.
local gui = gui or lje.secure.pull("gui", lje.state.menu)
local input = input or lje.secure.pull("input", lje.state.menu)

--> Not a global in the menu either.
local MOUSE_LEFT = MOUSE_LEFT or 107
local MOUSE_RIGHT = MOUSE_RIGHT or 108

local __clicked = false

function occ.didclick()
    return __clicked
end

function occ.mousedown()
    return input.IsMouseDown(MOUSE_LEFT)
end

--- Is the right button held?
--- @return boolean
function occ.mouserightdown()
    return input.IsMouseDown(MOUSE_RIGHT)
end

function occ.mousepos()
    return gui.MouseX(), gui.MouseY()
end

--> Not a global in the menu either.
local ANALOG_MOUSE_WHEEL = ANALOG_MOUSE_WHEEL or 3

--> input.GetAnalogValue hands back a running total for the wheel - it starts at
--> zero and counts a unit per notch either way - rather than what the wheel did
--> this frame, so the movement is the change in it since it was last read.
local __wheel = input.GetAnalogValue(ANALOG_MOUSE_WHEEL)

--- How far the wheel has moved since the last time this was asked.
--- Reading it takes the movement, so it belongs to the input pass and nothing
--- else should be calling it.
--- @return number delta Positive scrolling up, negative scrolling down.
function occ.mousewheel()
    local at = input.GetAnalogValue(ANALOG_MOUSE_WHEEL)
    local delta = at - __wheel

    __wheel = at

    return delta
end

--> Whether the open bind was down last frame, so holding it is told apart from
--> pressing it - otherwise the overlay would flap open and shut for as long as
--> the key was held.
local __bind = false

--- Was the key that opens the overlay pressed this frame, as against held down
--- from the frame before?
--- Reading it takes the press, so it belongs to the render pass and nothing
--- else should be calling it.
--- @return boolean pressed
function occ.bindpressed()
    local down = input.IsKeyDown(occ.open_bind)
    local pressed = down and not __bind

    __bind = down

    return pressed
end

function occ.ishovered(x, y, width, height)
    local mx, my = occ.mousepos()
    return (mx >= x and mx <= x + width) and (my >= y and my <= y + height)
end

--> StartCommand is a client hook, and the hook library itself does not exist
--> in the menu - the menu tracks its clicks off the mouse state instead.
if lje.state.client then
    hook.pre("StartCommand", "ooc_input", function()
        __clicked = input.WasMousePressed(MOUSE_LEFT) or input.WasMouseDoublePressed(MOUSE_LEFT)
    end)
end

local __captured = nil

function occ.__setcapture(widget)
    __captured = widget
end

function occ.__releasecapture(widget)
    if (widget == nil) or (__captured == widget) then
        __captured = nil
    end
end

function occ.__getcapture()
    return __captured
end

function occ.__hascapture(widget)
    return __captured == widget
end