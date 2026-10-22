occ = {
    style = {},
    quiet = true,
    --- Key that opens and closes the whole overlay. Insert by default - the
    --- enum is not a global in the menu state, so the number stands in for it.
    open_bind = KEY_INSERT or 72,

    meta = {
        base = nil,
        window = nil,
        modal = nil,
        group = nil,
        label = nil,
        checkbox = nil,
        button = nil,
        expandable = nil,
        popup = nil,
        colorpicker = nil,
        slider = nil,
        colorfield = nil,
        dropdown = nil,
        dropdownlist = nil,
        tooltip = nil,
        navbar = nil,
        tab = nil,
        tablepanel = nil,
        tablecell = nil,
    }
}

occ.sentences = {
    ""
}

occ.tag = "occ"

function occ.include(path)
    if occ.quiet then
        lje.include(path)
        return
    end

    local state
    
    if lje.state.client then
        state = "$#ffff00{client}"
    else
        state = "$#00ff00{menu}"
    end

    lje.con_printf(string.format("%s->including %s ", state, path))
    lje.include(path)
end

local to_include = {
    "base",
    "window",
    "modal",
    "group",
    "label",
    "checkbox",
    "button",
    "expandable",
    "popup",
    "colorpicker",
    "slider",
    "dropdown",
    "tooltip",
    "navbar",
    "notification",
    "tablepanel"
}

occ.include("backend/util.lua")
occ.include("backend/style.lua")
occ.include("backend/input.lua")

for i,v in pairs(to_include) do
    occ.include("widgets/" .. v .. ".lua")
end

occ.include("backend/render.lua")

-- uncomment this to get a example.
--occ.include("example.lua")
