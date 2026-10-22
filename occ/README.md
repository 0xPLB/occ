# occ

Retained-mode GUI library for Garry's Mod (lje). See `WIDGETS.md` for the widget API.

## Rendering the menu

occ doesn't hook into rendering on its own. It builds the widget tree and
exposes `occ.render()`, and the script using it calls that once per frame.
`occ.render()` handles everything for the frame: the open bind, input, layout,
fades, painting and notifications.

When no client state is alive, `occ.render()` switches the `surface` global to
the menu state's surface, so you can call it from the menu state as-is.

### From another script

Add occ as a dependency in your `info.toml`:

```toml
dependencies = [
    "Eyoko1.lje-util",
    "pngmeow.occ"
]
```

Then draw it from your own hooks:

```lua
-- In game (client state): draw after the game has rendered.
if lje.state.client then
    hook.pre("lje-util/postrender", "myscript_occ", function()
        occ.render()
    end)
end

-- Main menu / after a disconnect (no client state): draw on DrawOverlay.
lje.vm.add_pre_engine_call_hook(function(func, nargs, nresults, name)
    if name == "DrawOverlay" and not lje.state.client then
        occ.render()
    end
end, lje.state.menu)
```

You only need the hooks for the states you care about. For example, drop the
`DrawOverlay` one if you only want the menu in game.

### Hot reload

A hot reload re-runs your script's `main.lua`, but occ's widget tree can
survive it, so the menu you build again ends up next to the old one. Call
`occ.clear()` before building your menu:

```lua
occ.clear() -- removes every top-level widget this script created

local nav = occ.navbar({"Main"})
```

`occ.clear()` only touches widgets your own script created, so it won't remove
menus from other scripts that use occ. Pass a script name, as in
`occ.clear("myscript")`, to clear a different script's widgets.

Call `occ.render()` from **one** place per frame. Calling it twice draws the
tree twice and makes fades and input run at double speed.
