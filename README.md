# occ

Retained-mode GUI library for Garry's Mod (lje).

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


# occ widgets

How to build a menu out of occ's widgets. Every widget is made with an
`occ.<name>(...)` function and hangs off a parent. Leave the parent out and it
goes on `occ.root`, the screen.

`example.lua` uses nearly all of these, and is the place to look for a bigger
picture.

## Contents

- [The basics](#the-basics)
- [Navbar](#navbar)
- [Window](#window)
- [Group](#group)
- [Label](#label)
- [Checkbox](#checkbox)
- [Button](#button)
- [Slider](#slider)
- [Dropdown](#dropdown)
- [Color picker](#color-picker)
- [Expandable](#expandable)
- [Table panel](#table-panel)
- [Tooltip](#tooltip)
- [Popup](#popup)
- [Modal](#modal)
- [Notification](#notification)
- [The overlay](#the-overlay)
- [Helpers](#helpers)

## The basics

```lua
local window = occ.window("Settings")   -- goes on occ.root
local box = occ.checkbox("Enable", window)  -- goes on the window
```

Every widget derives `base`, so these work on all of them:

| Method | What it does |
| --- | --- |
| `SetPos(x, y)` / `GetPos()` | Position, relative to the parent. |
| `GetAbsolutePos()` | Position on screen. |
| `SetSize(w, h)` / `GetSize()` | Size. `SetWide`, `SetTall`, `GetWide` and `GetTall` do one side. |
| `SetVisible(bool)` / `IsVisible()` | Hidden widgets are not drawn and cannot be clicked. |
| `SetAlpha(0-255)` / `GetAlpha()` | Opacity, multiplied down through the children. |
| `SetParent(widget)` / `GetParent()` | Moves it to another parent. |
| `GetChildren()` / `FindChildByName(name)` | Walks the tree. |
| `SetName(name)` / `GetName()` | Name used by `FindChildByName`. |
| `MoveToFront()` / `SetZPos(z)` | Draw order among siblings. |
| `InvalidateLayout()` | Asks for the layout to be done again next frame. |

Callbacks come in two forms, depending on the widget:

- **Setter callbacks:** `button:OnClick(function(self) ... end)`. Calling the
  method with a function stores it. Button, slider, dropdown, color picker and
  expandable work this way.
- **Override:** `function box:OnChange(checked) ... end`. The checkbox works
  this way.

Positions are mostly handled for you: a window or group page stacks what it
holds from the top down, so most widgets never need `SetPos`.

## Navbar

A strip along the top of the screen with a button for each window it opens.
The left end shows `occ.tag`, one of `occ.sentences` and the clock.

```lua
local nav = occ.navbar({"Combat", "Visuals", "Misc"})

local combat = nav:GetWindow("Combat")
combat:SetSize(300, 250)

occ.checkbox("Aimbot", combat)
```

| Method | What it does |
| --- | --- |
| `AddButton(name)` | Adds a button and returns the window it opens. |
| `GetWindow(key)` / `GetButton(key)` | By name or position on the bar. |
| `Open(key)` / `Close(key)` / `Toggle(key)` | Shows or hides a window, with a fade. |
| `IsOpen(key)` | Whether the window is meant to be up. |
| `GetButtonCount()` | Number of buttons. |
| `RollSentence()` | Picks another of `occ.sentences`. |

The sentence is picked once, when the navbar is made, so set `occ.sentences`
**before** creating it. A window is placed under the bar the first time it is
opened, and keeps wherever it is dragged to after that. To give one a starting
position, open it, `SetPos` it, and close it again:

```lua
nav:Open("Combat")
combat:SetPos(40, 60)
nav:Close("Combat")
```

## Window

A draggable, resizable frame with a title bar.

```lua
local window = occ.window("Settings")

window:SetSize(300, 200)
window:SetPos(100, 100)
```

| Method | What it does |
| --- | --- |
| `SetTitle(text)` / `GetTitle()` | Title bar text. |
| `SetDraggable(bool)` | Dragging by the title bar, on by default. |
| `SetResizable(bool)` | Resizing by the bottom right corner, on by default. |
| `SetMainContent(widget)` | Makes a widget fill the content area. |
| `Close()` | Hides it and takes it off its parent. |

How a window lays out what it holds:

- **No groups:** widgets are stacked from the top down, and the window scrolls
  when they don't fit.
- **One group:** it fills the content area.
- **More groups:** they share the area in columns (`window.columns`, 2 by
  default).

## Group

A box with a strip along the top holding either tabs or a line of text (see
[Text instead of tabs](#text-instead-of-tabs)). Pass the tab names when making
it; each tab has a page, and widgets parented to the group land on the page
that is showing (the first tab, to begin with).

```lua
local main = occ.group(window, "General", "Visuals")

occ.checkbox("Enable", main)           -- on "General"

local visuals = main:GetPage("Visuals")
occ.checkbox("Boxes", visuals)         -- on "Visuals"
```

Groups inside a group's page are laid out in columns, side by side:

```lua
local left = occ.group(main, "Aim")
local right = occ.group(main, "Movement")
```

| Method | What it does |
| --- | --- |
| `AddTab(name)` | Adds a tab. |
| `RemoveTab(key)` | Removes a tab and its page. |
| `GetPage(key)` | The page for a tab, by name or index. Parent widgets to this. |
| `SetActiveTab(key)` / `GetActiveTab()` / `GetActivePage()` | The tab that is showing. |
| `GetTabCount()` | Number of tabs. |
| `SetColumns(n)` / `GetColumns()` | Columns for groups on its pages. |
| `SetText(title, subtitle)` / `GetText()` | Writes `title - subtitle` across the strip in place of the tabs. Returns the group. |

### Text instead of tabs

A group doesn't need tabs. `SetText(title, subtitle)` writes
`title - subtitle` across the strip where the tabs would be, and the group
shows one page under it:

```lua
local info = occ.group(window):SetText("tab1", "welcome to the world!")

occ.checkbox("Element 1", info)
occ.checkbox("Element 2", info)
```

Draws as:

```
tab1 - welcome to the world!
[Element 1]
[Element 2]
```

- **Page:** a group with no tabs yet gets one, named after the title, so
  `occ.group(parent):SetText(...)` is all it takes and widgets parented to the
  group land on it. `GetPage(title)` returns that page.
- **Return value:** `SetText` returns the group, so it chains off `occ.group`.
- **Subtitle:** optional. Leave it out or pass `""` and only the title shows.
- **Colours:** the title uses `occ.style.group.textactive` and the subtitle
  (with its ` - `) uses `occ.style.group.text`, in `occ.style.group.font`.
  There are no new style keys.
- **Tabs:** while text is set, no tabs are drawn, the strip can't be hovered
  or clicked, and there is no black line under the strip, so the text and the
  page read as one piece, like an active tab and its page. Only the active
  page shows; tabs added with `AddTab` still exist and can be switched with
  `SetActiveTab` from code.
- **Layout:** unchanged. The strip is the same height as the tab strip, so the
  page sits in the same place and stacking, columns of nested groups and
  scrolling all work as they do with tabs.
- **Fitting:** text is fitted in `PerformLayout`, re-run on every resize. The
  subtitle is cut short with `...` first, and dropped if there is no room for
  it; then the title is cut. It never draws past the border.
- **Back to tabs:** `SetText(nil)` brings the tabs back. Pages made while text
  was set become normal tabs, so a group can start as text and turn into tabs
  later:

```lua
local group = occ.group(page):SetText("Chams", "Draws players in a flat colour")

-- later, a second item joins the group
group:SetText(nil)
group:AddTab("ESP")    -- strip now shows [Chams] [ESP]
```

The code is in `widgets/group.lua`: `GROUP:SetText`, `GROUP:GetText`, the
`self.title` branch in `PerformLayout` and `Paint`, and the early return in
`GROUP:TabAt`.

## Label

A line of text.

```lua
local label = occ.label("Hello", window)

label:SetTextColor(occ.color(255, 200, 0))
label:SetAlign("center")
```

| Method | What it does |
| --- | --- |
| `SetText(text)` / `GetText()` | The text. |
| `SetTextColor(color)` | Colour, from `occ.color`. |
| `SetAlign(align)` | `"left"`, `"center"` or `"right"`. |
| `SetFont(font)` | Font name. |
| `SetAutoSize(bool)` | Whether it takes the height of its text, on by default. |
| `SizeToContents()` | Sizes it to its text. |

## Checkbox

```lua
local enable = occ.checkbox("Enable", window)

enable:SetChecked(true)

function enable:OnChange(checked)
    print("enable is now", checked)
end
```

| Method | What it does |
| --- | --- |
| `SetChecked(bool)` / `GetChecked()` / `Toggle()` | The ticked state. |
| `OnChange(checked)` | **Override it.** Runs on every change, including `SetChecked`. |
| `SetText(text)` / `SetTextColor(color)` / `SetFont(font)` | The label beside the box. |

## Button

```lua
occ.button("Unload", window):OnClick(function(self)
    occ.notification("Unloaded", 2)
end)
```

| Method | What it does |
| --- | --- |
| `OnClick(function(self) end)` | What a click does. |
| `SetText(text)` / `SetFont(font)` | The text on it. |
| `SetAutoSize(bool)` | Whether it sizes itself to its text. |
| `SizeToContents()` | Sizes it to its text. |
| `IsPressed()` | Whether it is being held down. |

## Slider

```lua
local fov = occ.slider("Field of view", window)

fov:SetRange(0, 180)
fov:SetValue(90)
fov:SetUnit("°")

fov:OnChange(function(self, value)
    print("fov", value)
end)
```

| Method | What it does |
| --- | --- |
| `SetRange(min, max)` / `GetRange()` | Range of values. |
| `SetValue(n)` / `GetValue()` | The value. |
| `SetStep(n)` | What the value snaps to, `1` for whole numbers. |
| `SetDecimals(n)` | Decimal places shown. |
| `SetUnit(text)` | Text after the number, such as `"s"` or `"%"`. |
| `OnChange(function(self, value) end)` | Runs when the value changes. |

For decimals, set both: `SetStep(0.1)` and `SetDecimals(1)`.

## Dropdown

```lua
local target = occ.dropdown("Target", window, {"Head", "Chest", "Nearest"})

target:Pick("Head")

target:OnChange(function(self)
    local index, text = self:GetPicked()
    print("target", text)
end)
```

To allow several picks at once:

```lua
local hitboxes = occ.dropdown("Hitboxes", window, {"Head", "Chest", "Legs"})

hitboxes:SetMultiple(true)
hitboxes:Pick("Head")
hitboxes:Pick("Chest")

local indexes, texts = hitboxes:GetPickedAll()
```

| Method | What it does |
| --- | --- |
| `AddOption(text)` / `SetOptions(list)` / `GetOptions()` | The options. |
| `Pick(key)` / `Unpick(key)` / `Clear()` | Changes the picks, by text or index. |
| `IsPicked(key)` | Whether an option is picked. |
| `GetPicked()` | Index and text of the first pick. |
| `GetPickedAll()` | Tables of every picked index and text. |
| `GetPickedText()` | The picks joined with `", "`. |
| `SetMultiple(bool)` / `IsMultiple()` | Several picks or one. |
| `OnChange(function(self) end)` | Runs when the picks change. |

## Color picker

A swatch that opens a picker for hue, saturation, value and alpha.

```lua
local boxcolor = occ.colorpicker("Box color", window)

boxcolor:SetColor(occ.color(255, 0, 255))

boxcolor:OnChange(function(self, color)
    print(color[1], color[2], color[3], color[4])
end)
```

| Method | What it does |
| --- | --- |
| `SetColor(color)` / `GetColor()` | The colour, as `{r, g, b, a}`. |
| `SetHSV(h, s, v)` / `GetHSV()` | The colour as hue (0-360), saturation and value (0-1). |
| `SetColorAlpha(0-255)` / `GetColorAlpha()` | Just the alpha. |
| `SetAnimation(name)` | `"none"`, `"rainbow"` or `"pulse"`. |
| `SetRate(n)` | How quickly the animation runs. |
| `OnChange(function(self, color) end)` | Runs when the colour changes. |
| `OpenPopup()` / `ClosePopup()` / `IsOpen()` | The picker itself. |

## Expandable

A row that opens to show the widgets parented to it, for tucking settings
away.

```lua
local advanced = occ.expandable("Advanced", window)

occ.checkbox("Debug", advanced)
occ.slider("Rate", advanced)

advanced:OnToggle(function(self, open)
    print("advanced is", open and "open" or "shut")
end)
```

| Method | What it does |
| --- | --- |
| `SetOpen(bool)` / `IsOpen()` / `Toggle()` | Whether it is open. |
| `OnToggle(function(self, open) end)` | Runs when it opens or shuts. |
| `OnRightClick(function(self, mx, my) end)` | Runs on a right click on the row. |
| `SetText(text)` / `SetFont(font)` | The row's text. |

## Table panel

Rows and columns of cells. Pass the column names when making it.

```lua
local players = occ.tablepanel(window, "Name", "Status")

local row = players:AddRow("Bot01", "online")
local status = players:SetCell(row, "Status", "offline")

status:SetTextColor(occ.color(220, 120, 120))
```

| Method | What it does |
| --- | --- |
| `AddColumn(name, width)` | Adds a column. Leave `width` out to share the space. |
| `RemoveColumn(key)` / `GetColumnCount()` | Columns, by name or index. |
| `SetHeader(key, name)` / `SetHeadersVisible(bool)` | The header row. |
| `SetColumnWidth(key, width)` | Fixes a column's width. |
| `AddRow(...)` | Adds a row with the given text, one per column. Returns its index. |
| `RemoveRow(index)` / `Clear()` / `GetRowCount()` | Rows. |
| `GetCell(row, column)` | The cell widget, for parenting other widgets to. |
| `SetCell(row, column, text)` | Writes text in a cell. Returns the label. |
| `GetCellText(row, column)` | Text in a cell. |
| `SetAlign(align)` / `SetFont(font)` | For the text in every cell. |

## Tooltip

Text that appears when the mouse rests on a widget. The second argument is the
widget it belongs to.

```lua
local silent = occ.checkbox("Silent aim", window)

occ.tooltip("Doesn't move your view", silent)
```

| Method | What it does |
| --- | --- |
| `SetText(text)` | The text. Long text wraps. |
| `SetMaxWidth(width)` | Width before it wraps. |
| `SetOwner(widget)` | The widget it belongs to. |

## Popup

A small box that opens at a point, such as a right click menu. It closes when
you click outside it. Widgets on it are not laid out for you, so position them
yourself.

```lua
local menu = occ.popup()
local copy = occ.button("Copy", menu)

copy:SizeToContents()
copy:SetPos(menu.padding, menu:GetContentTop())

copy:OnClick(function()
    menu:Close()
end)

-- later, from a right click:
menu:Open(mx, my)
```

| Method | What it does |
| --- | --- |
| `Open(x, y)` | Opens it at a point on screen. |
| `Close(force)` / `Toggle(x, y)` / `IsOpen()` | Closing it. |
| `GetContentTop()` | Where to start placing widgets, under its accent bar. |

## Modal

A window that blocks the rest of the menu, behind a dark sheet, until it is
closed. It opens in the middle of the screen.

```lua
local confirm = occ.modal("Reset settings")

confirm:SetSize(240, 130)
confirm:SetDismissable(true)   -- clicking the sheet closes it

occ.label("Reset everything?", confirm)

occ.button("Reset", confirm):OnClick(function()
    confirm:Close()
end)

confirm:Open()
```

It is a window, so the window methods work on it too.

| Method | What it does |
| --- | --- |
| `Open(x, y)` / `Close()` / `Toggle()` / `IsOpen()` | Showing it. Without `x, y` it is centred the first time, then stays where it was left. |
| `Center()` | Moves it to the middle of the screen. |
| `OnClose(function(self) end)` | Runs when it closes. |
| `SetDismissable(bool)` | Whether a click on the sheet closes it. |
| `SetOverlay(bool)` | Shows or hides the dark sheet. |
| `SetOverlayColor(color)` / `SetOverlayAlpha(0-255)` | The sheet's colour. |

## Notification

A message on screen. It shows even when the menu is closed.

```lua
occ.notification("Config saved", 3)   -- 3 seconds, 5 by default
```

| Method | What it does |
| --- | --- |
| `SetText(text)` | The text. |
| `SetTimeout(seconds)` | How long it stays up. |
| `Remove()` | Takes it down early. |

## The overlay

Insert (`occ.open_bind`) opens and closes the whole menu.

| Function | What it does |
| --- | --- |
| `occ.open(bool)` / `occ.toggle()` / `occ.isopen()` | Opens or closes the menu from code. |
| `occ.opentime` | Seconds the fade takes, `0` for none. |
| `occ.tag` | Text at the left of the navbar. |
| `occ.sentences` | Lines the navbar picks one of. |
| `occ.render()` | Draws the menu for one frame. occ doesn't hook anything, so your script must call this every frame - see `README.md`. |
| `occ.clear(script)` | Removes every top-level widget a script created, the calling script by default. Call it before building your menu so a hot reload replaces the menu instead of adding a second one. |

## Helpers

| Function | What it does |
| --- | --- |
| `occ.color(r, g, b, a)` | A colour, `a` is 255 by default. |
| `occ.hsv(h, s, v, a)` / `occ.tohsv(color)` | Converts between HSV and colours. |
| `occ.shcolor(percent, color)` | A colour taken down to a percentage of itself. |
| `occ.isa(widget, name)` | Whether a widget is, or derives, a kind of widget. |
| `occ.style` | Every colour and size the widgets draw with. Changing a value changes the look right away. |

```lua
occ.style.accent = occ.color(255, 0, 255)
```
