local occ = occ

--- Style of every widget, grouped per class.
occ.style = {
    accent = occ.color(127, 72, 163),
    border = {
        --> Outline and Inline out of the theme, which every panel, frame,
        --> button and tab in it is edged with.
        base = occ.color(50, 50, 50, 255),
        window = occ.color(20, 20, 20),

        --> Darker than whatever it is drawn on, for lines that have to read as
        --> a cut rather than an edge.
        dark = occ.color(15, 15, 15)
    },
    button = {
        background = occ.color(40, 40, 40),
        hovered = occ.color(50, 50, 50),
        pressed = occ.color(30, 30, 30),

        --> What the fill shades towards along the foot of the button, whichever
        --> of the three it is wearing.
        fade = occ.color(30, 30, 30),

        text = occ.color(200, 200, 200),
        texthovered = occ.color(255, 255, 255),

        font = "small"
    },
    checkbox = {
        --> Ticked, it takes the accent - the box only has a colour of its own
        --> while it is empty.
        box = occ.color(30, 30, 30),
        boxhovered = occ.color(45, 45, 45),

        text = occ.color(200, 200, 200),
        texthovered = occ.color(255, 255, 255),

        font = "small"
    },
    group = {
        --> Seconds a page takes to fade when the tab changes, 0 for no fade.
        fadetime = 0.15,

        background = occ.color(40, 40, 40),

        --> The strip the tabs sit on, what the title bar is to a window. It is
        --> the lighter of the two, so an inactive tab showing it stands off the
        --> page rather than sinking into it.
        frame = occ.color(50, 50, 50),

        --> An inactive tab sits flat on the strip, the active one takes the
        --> background of the page it belongs to.
        tab = occ.color(50, 50, 50),
        tabhovered = occ.color(55, 55, 55),
        tabactive = occ.color(40, 40, 40),

        --> What each piece of the group shades towards. A gradient is drawn in
        --> the colour it ends on and fades out across the piece it is drawn
        --> over, so these are read as where the shading lands rather than as a
        --> fill of their own.
        framefade = occ.color(40, 40, 40),
        tabfade = occ.color(30, 30, 30),
        tabactivefade = occ.color(40, 40, 40),
        pagefade = occ.color(40, 40, 40, 240),

        text = occ.color(150, 150, 150),
        textactive = occ.color(255, 255, 255),

        font = "small"
    },
    colorpicker = {
        --> Behind the square, so a colour with little alpha on it is seen
        --> against something known.
        swatch = occ.color(25, 25, 25),

        --> The checks behind the alpha strip, the way a transparency bar is
        --> always shown - the colour fades out over them rather than over one
        --> flat shade, which would read as the colour going dark instead.
        checker = occ.color(200, 200, 200),
        checkeralt = occ.color(130, 130, 130),

        --> Size of a check, in pixels.
        checkersize = 4,

        text = occ.color(200, 200, 200),
        texthovered = occ.color(255, 255, 255),

        font = "small"
    },
    dropdown = {
        --> Seconds the list takes to roll out of the box and back into it, 0
        --> for no roll at all.
        rolltime = 0.12,

        background = occ.color(40, 40, 40),
        hovered = occ.color(50, 50, 50),

        --> What the box shades towards along its foot.
        fade = occ.color(30, 30, 30),

        --- Label above the box.
        text = occ.color(150, 150, 150),
        texthovered = occ.color(255, 255, 255),

        --- What is picked, written across the box, and the sign at the right
        --- of it saying how many can be.
        value = occ.color(200, 200, 200),
        sign = occ.color(150, 150, 150),

        --- Rows on the list that drops out of it. A picked one is drawn in the
        --- accent rather than in a colour of its own.
        rowhovered = occ.color(50, 50, 50),
        rowtext = occ.color(200, 200, 200),

        font = "small"
    },
    tablepanel = {
        --> Darker than the strip over it, so the heading is what the eye lands
        --> on rather than the rows.
        background = occ.color(28, 28, 28),

        --> The strip the column names are written across, and what it shades
        --> towards down its own height.
        header = occ.color(50, 50, 50),
        headerfade = occ.color(40, 40, 40),
        headertext = occ.color(200, 200, 200),

        --> The ticks between one column and the next. The rows have no colour
        --> of their own - they are left on the background, so the heading is
        --> the one piece of the table that stands out.
        grid = occ.color(70, 70, 70),

        font = "small"
    },
    tooltip = {
        --> Seconds the cursor has to rest on a widget before its note comes up,
        --> and seconds the note then takes to rise into place or drop back out.
        delay = 0.0,
        tweentime = 1.10,

        background = occ.color(35, 35, 35),

        text = occ.color(200, 200, 200),

        font = "small"
    },
    popup = {
        --> Seconds it takes to fade in or out, 0 for no fade.
        fadetime = 0.1,

        background = occ.color(35, 35, 35)
    },
    expandable = {
        --> Seconds the arrow takes to turn, 0 to have it snap round.
        rotatetime = 0.05,

        hovered = occ.color(45, 45, 45),
        arrow = occ.color(255,255,255),

        --> The trunk and branches drawn down to what an open list has on it.
        tree = occ.color(127,72,163),

        text = occ.color(200, 200, 200),
        texthovered = occ.color(255, 255, 255),

        font = "small"
    },
    navbar = {
        --> Seconds a window takes to fade when its button is pressed, 0 for no
        --> fade.
        fadetime = 0.15,

        background = occ.color(35, 35, 35),

        --> The tag, sentence and clock down the right of the bar.
        text = occ.color(190, 190, 190),

        font = "small"
    },
    label = {
        text = occ.color(255, 255, 255),

        font = "small"
    },
    --- The bar down anything holding more than fits, shared by everything that
    --- scrolls rather than set per widget.
    slider = {
        background = occ.color(30, 30, 30),

        --> The label over the top left of the bar, and the value across the
        --> middle of it.
        text = occ.color(200, 200, 200),
        texthovered = occ.color(255, 255, 255),
        value = occ.color(255, 255, 255),

        font = "small"
    },
    scroll = {
        bar = occ.color(25, 25, 25),
        thumb = occ.color(75, 75, 75),

        --> How quickly a scroll catches up with the wheel, per second. Higher is
        --> snappier, lower is looser. Shared by everything that scrolls.
        speed = 16
    },

    --- The overlay as a whole, rather than anything on it.
    overlay = {
        --> Seconds it takes to fade in or out on the bind, 0 for no fade.
        opentime = 0.2
    },
    notification = {
        --> Seconds it takes to slide in, and to slide back out again.
        tweentime = 0.35,

        background = occ.color(35, 35, 35),
        text = occ.color(255, 255, 255),

        font = "small"
    },
    modal = {
        --> Seconds it takes to fade in or out, 0 for no fade.
        fadetime = 0.15,

        --> The sheet laid over everything behind it. The alpha is how dark it
        --> comes out - 0 leaves the screen as it is, 255 blacks it out.
        overlay = occ.color(0, 0, 0, 160)
    },
    window = {
        background = occ.color(25, 25, 25),
        titlebar = occ.color(44, 44, 44),
        text = occ.color(255, 255, 255),

        --> Name of the font, occ.font registers it the first time it is drawn.
        font = "small"
    }
}

--- Fonts widgets draw with, fetched back by name with occ.font.
occ.font("small", {
    font = "TargetIDSmall",
    size = 13,
    antialias = false,
    outline = true
})

occ.material("gradient-up", "gui/gradient_up")
occ.material("gradient-down", "gui/gradient_down")
occ.material("colorpicker-crosshair", "vgui/minixhair")
occ.material("arrow-down", "materials/icon16/folder_wrench.png")