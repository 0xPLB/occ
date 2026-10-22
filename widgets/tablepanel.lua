--[[
    tablepanel.lua
    A panel that is a table and nothing else - named columns across the top,
    rows under them, and a cell where each row meets each column. Anything can
    be put in a cell, a label or a button as readily as a picker, and the cell
    lays out whatever it is handed.

    Two classes live here. The cell is a piece of the table, and is no use on its
    own, so it is kept with the table that makes it rather than given a file of
    its own.

    Example:
    root (base)
    |_window
     |_group
      |_page (base)
       |_tablepanel
         |_tablecell
           |_button

    Widgets can be parented to the table itself - they land in the first cell
    with nothing in it, filling a row across before the next one is started, so
    a run of them fills the table the way it reads.
]]

local TABLE = occ.register("tablepanel", "base")
local CELL = occ.register("tablecell", "base")

--[[
    The cell - one crossing of a row and a column, and what is in it.
]]

--- Initializes the cell.
function CELL:Init()
    self.name = "tablecell"

    self.w = 0
    self.h = 0

    --- Space between what is in the cell and the sides of it.
    self.padding = 3

    --- Space between one widget in the cell and the next.
    self.spacing = 3

    --- Does what is in it sit in the middle of the cell, or at the top?
    self.center = true

    --- The table this belongs to, and where in it the cell sits. The row is
    --- kept up to date as rows come and go, so a button in a cell can always
    --- ask which row it ended up in.
    self.tablepanel = nil
    self.row = 0
    self.column = 0
end

--- How tall what is in the cell comes out, with nothing round it.
--- The table asks every cell in a row this and takes the tallest, so a row is
--- as deep as whatever was put in it needs.
--- @return number
function CELL:GetContentHeight()
    local h = 0
    local count = 0

    for _, child in ipairs(self.children) do
        if child:IsVisible() then
            h = h + child.h
            count = count + 1
        end
    end

    if count == 0 then return 0 end

    return h + self.spacing * (count - 1)
end

--- Holds what is in the cell inside it.
--- A widget wider than its column is cut off at the column's edge rather than
--- being drawn across the one beside it.
--- @return number x
--- @return number y
--- @return number w
--- @return number h
function CELL:GetClipBounds()
    local x, y = self:GetAbsolutePos()

    return x, y, self.w, self.h
end

--- Stacks what is in the cell down it.
function CELL:PerformLayout()
    local w = math.max(0, self.w - self.padding * 2)
    local content = self:GetContentHeight()

    local y = self.padding

    --> Sat in the middle of the cell when there is room to spare, so a button
    --> in a row made deep by something taller beside it is not left hanging off
    --> the top of it.
    if self.center and content < self.h - self.padding * 2 then
        y = math.floor((self.h - content) * 0.5 + 0.5)
    end

    occ.stack(self, self.padding, y, w, self.spacing)
end

--[[
    The table - the header strip, the rows and the grid over them.
]]

--- Initializes the table.
function TABLE:Init()
    self.name = "tablepanel"

    self.w = 200
    self.h = 100

    --- Height of the strip the column names are written across.
    self.headerHeight = 18

    --- Are the names shown at all? A table of two columns and no headings is
    --- still a table, so the strip can be taken off it.
    self.headers = true

    --- Shortest a row is allowed to be. One holding something taller than this
    --- takes the height of what is in it instead.
    self.rowHeight = 20

    --- Space either side of a column name.
    self.padding = 4

    --- How far a column name is nudged from where it lands on its own.
    self.textY = 0

    --- Height of the tick drawn between one column and the next, a short mark
    --- in the middle of every row rather than a line the whole way down. It is
    --- never drawn taller than the row it is in.
    self.tickHeight = 10

    --- How the text sits across a column - "left", "center" or "right". The
    --- headings and the text written into the cells are laid the same way, so
    --- a name lines up with what is under it.
    self.align = "center"

    --- Space the grid is held off the edge of the panel by, leaving the outline
    --- round it clear of the cells.
    self.border = 1

    --- Does the table take the height of its rows?
    self.autosize = true

    --- Columns in the order they were added, as
    --- {name = string, fixed = number|nil, x = number, w = number}. fixed is a
    --- width asked for, x and w are where the column came out.
    self.columns = {}

    --- Rows in the order they were added, as {h = number, cells = {}}.
    self.rows = {}

    --- Font the column names draw with, a name occ.font knows, nil for the one
    --- the style picks.
    self.font = nil
end

--- The area the rows sit in, local to the table.
--- @return number x
--- @return number y
--- @return number w
--- @return number h
function TABLE:GetBodyBounds()
    local b = self.border
    local y = b + (self.headers and self.headerHeight or 0)

    return b, y, math.max(0, self.w - b * 2), math.max(0, self.h - y - b)
end

--- Holds the rows inside the panel.
--- The table's own Paint is left alone, so the outline round it is drawn before
--- this bites.
--- @return number x
--- @return number y
--- @return number w
--- @return number h
function TABLE:GetClipBounds()
    local x, y = self:GetAbsolutePos()

    return x, y, self.w, self.h
end

--- Works out where every column starts and how wide it comes out.
--- A column given a width of its own keeps it and the rest share what is left
--- of the table evenly between them.
function TABLE:LayoutColumns()
    local _, _, bw = self:GetBodyBounds()

    local fixed, sharing = 0, 0

    for _, column in ipairs(self.columns) do
        if column.fixed then
            fixed = fixed + column.fixed
        else
            sharing = sharing + 1
        end
    end

    local each = sharing > 0 and math.max(0, bw - fixed) / sharing or 0
    local at = 0

    for _, column in ipairs(self.columns) do
        local wide = column.fixed or each

        --> Rounded off the far edge rather than the width, so columns that do
        --> not divide evenly still tile the table exactly instead of leaving a
        --> seam a pixel wide between two of them.
        local left = math.floor(at + 0.5)

        column.x = left
        column.w = math.floor(at + wide + 0.5) - left

        at = at + wide
    end
end

--- Lays the cells out, a row at a time, and takes the height of the lot.
function TABLE:PerformLayout()
    self:LayoutColumns()

    local bx, by = self:GetBodyBounds()
    local at = by

    for _, row in ipairs(self.rows) do
        local tall = self.rowHeight

        --> The row is as deep as the deepest thing in it, so a cell holding a
        --> stack of widgets pushes the whole row down rather than being cut off
        --> at the bottom of it.
        for _, cell in ipairs(row.cells) do
            local content = cell:GetContentHeight()

            if content > 0 then
                tall = math.max(tall, content + cell.padding * 2)
            end
        end

        row.h = tall

        for i, cell in ipairs(row.cells) do
            local column = self.columns[i]

            if column then
                local x = bx + column.x

                --> Only moved when it is not already there - a cell that is
                --> given a position or a size asks for a layout of its own, and
                --> that comes back up to this table, so setting them every pass
                --> would have the pair of them laying out forever.
                if cell.x ~= x or cell.y ~= at then
                    cell:SetPos(x, at)
                end

                if cell.w ~= column.w or cell.h ~= tall then
                    cell:SetSize(column.w, tall)
                end
            end
        end

        at = at + tall
    end

    if not self.autosize then return end

    local h = at + self.border

    if self.h == h then return end

    self.h = h

    --> Whatever is laying the table out goes by its height, and
    --> InvalidateLayout stops at a widget already waiting for a layout - which
    --> this one is, being in the middle of its own - so the parent is told from
    --> here.
    if self.parent then
        self.parent:InvalidateLayout()
    end
end

--- Paints the header strip, and the ticks between the columns under it.
--- The strip is the one piece of the table with a colour of its own - the rows
--- are left on the panel's own background, so the heading is what stands out
--- rather than the table being banded all the way down.
--- @param x number
--- @param y number
--- @param w number
--- @param h number
function TABLE:Paint(x, y, w, h)
    local alpha = self:GetAbsoluteAlpha() / 255
    local style = occ.style.tablepanel
    local line = occ.style.border.window

    local bx, by, bw = self:GetBodyBounds()

    surface.SetDrawColor(style.background[1], style.background[2], style.background[3], style.background[4] * alpha)
    surface.DrawRect(x, y, w, h)

    --> A tick between one column and the next rather than a line the whole way
    --> down, one per row, so the columns are told apart without the rows being
    --> ruled off from each other.
    local grid = style.grid
    local at = y + by

    surface.SetDrawColor(grid[1], grid[2], grid[3], grid[4] * alpha)

    for _, row in ipairs(self.rows) do
        local tall = math.min(self.tickHeight, row.h)
        local ty = at + math.floor((row.h - tall) * 0.5 + 0.5)

        for i = 2, #self.columns do
            surface.DrawRect(x + bx + self.columns[i].x, ty, 1, tall)
        end

        at = at + row.h
    end

    if self.headers and self.headerHeight > 0 then
        local strip = style.header
        local fade = style.headerfade
        local text = style.headertext

        surface.SetDrawColor(strip[1], strip[2], strip[3], strip[4] * alpha)
        surface.DrawRect(x + bx, y + self.border, bw, self.headerHeight)

        --> Shading down off the strip, the way the rest of the menu shades its
        --> bars, so the heading reads as a lid on the rows rather than a band
        --> of flat colour.
        surface.SetDrawColor(fade[1], fade[2], fade[3], fade[4] * alpha)
        surface.SetMaterial(occ.material("gradient-down"))
        surface.DrawTexturedRect(x + bx, y + self.border, bw, self.headerHeight)

        --> The cut between the strip and the rows, drawn in the black the rest
        --> of the menu is edged with rather than in the colour of the ticks -
        --> the heading sits on the rows rather than beside them.
        surface.SetDrawColor(line[1], line[2], line[3], line[4] * alpha)
        surface.DrawRect(x + bx, y + by - 1, bw, 1)

        surface.SetFont(occ.font(self:GetFont()))
        surface.SetTextColor(text[1], text[2], text[3], text[4] * alpha)

        for _, column in ipairs(self.columns) do
            --> Cut down to the column it belongs to rather than running on over
            --> the name of the one beside it.
            local room = column.w - self.padding * 2
            local name = occ.truncate(column.name, room)
            local tw, th = surface.GetTextSize(name)

            --> Sat the way the cells under it are, so a name lines up with the
            --> column it is naming rather than only starting in the same place.
            local tx = self.padding

            if self.align == "center" then
                tx = math.floor((column.w - tw) * 0.5 + 0.5)
            elseif self.align == "right" then
                tx = column.w - self.padding - tw
            end

            surface.SetTextPos(
                x + bx + column.x + tx,
                y + self.border + math.floor((self.headerHeight - th) * 0.5 + 0.5) + self.textY)

            surface.DrawText(name)
        end
    end

    surface.SetDrawColor(line[1], line[2], line[3], line[4] * alpha)
    surface.DrawOutlinedRect(x, y, w, h)
end

--[[
    Columns.
]]

--- Adds a column, and a cell in it to every row already on the table.
--- @param name string|nil Name written at the top of it, blank for none.
--- @param width number|nil Width to hold it at, nil to share what is going.
--- @return number index
function TABLE:AddColumn(name, width)
    table.insert(self.columns, {
        name = name or "",
        fixed = width,

        --- Where the column came out, filled in by the layout.
        x = 0,
        w = 0
    })

    local index = #self.columns

    --> A column added to a table that already has rows leaves every one of them
    --> a cell short, so each is given the one it is missing.
    for i, row in ipairs(self.rows) do
        row.cells[index] = self:MakeCell(i, index)
    end

    self:InvalidateLayout()

    return index
end

--- Finds a column by its name or by its index.
--- @param key string|number
--- @return number|nil index
function TABLE:FindColumn(key)
    if type(key) == "number" then
        return self.columns[key] and key or nil
    end

    for i, column in ipairs(self.columns) do
        if column.name == key then
            return i
        end
    end

    return nil
end

--- Removes a column and the cells under it.
--- @param key string|number Name or index of the column.
function TABLE:RemoveColumn(key)
    local index = self:FindColumn(key)

    if not index then return end

    table.remove(self.columns, index)

    for _, row in ipairs(self.rows) do
        local cell = table.remove(row.cells, index)

        if cell then
            cell:SetParent(nil)
        end

        --> Every cell after the one that went moves a column to the left, and a
        --> cell carries which column it is in, so they are told where they
        --> ended up.
        for i = index, #row.cells do
            row.cells[i].column = i
        end
    end

    self:InvalidateLayout()
end

--- Names a column, or renames one.
--- @param key string|number Name or index of the column.
--- @param name string
function TABLE:SetHeader(key, name)
    local index = self:FindColumn(key)

    if not index then return end

    self.columns[index].name = name
end

--- Gets the name of a column.
--- @param key string|number Name or index of the column.
--- @return string|nil name
function TABLE:GetHeader(key)
    local index = self:FindColumn(key)

    return index and self.columns[index].name or nil
end

--- Holds a column at a width, or hands it back to the sharing.
--- @param key string|number Name or index of the column.
--- @param width number|nil Width to hold it at, nil to share what is going.
function TABLE:SetColumnWidth(key, width)
    local index = self:FindColumn(key)

    if not index then return end

    self.columns[index].fixed = width

    self:InvalidateLayout()
end

--- Gets the width a column came out at.
--- @param key string|number Name or index of the column.
--- @return number|nil width
function TABLE:GetColumnWidth(key)
    local index = self:FindColumn(key)

    return index and self.columns[index].w or nil
end

--- Gets how many columns the table has.
--- @return number count
function TABLE:GetColumnCount()
    return #self.columns
end

--- Shows or hides the strip the column names are written across.
--- @param visible boolean
function TABLE:SetHeadersVisible(visible)
    visible = visible and true or false

    if self.headers == visible then return end

    self.headers = visible

    self:InvalidateLayout()
end

--- Is the strip of column names showing?
--- @return boolean visible
function TABLE:IsHeadersVisible()
    return self.headers
end

--[[
    Rows and cells.
]]

--- Makes a cell of the table's own, parented past the routing that puts a
--- widget handed to the table into a cell.
--- @param row number Row it sits in.
--- @param column number Column it sits in.
--- @return table cell
function TABLE:MakeCell(row, column)
    local cell = occ.create("tablecell")

    cell.tablepanel = self
    cell.row = row
    cell.column = column

    --> Straight to the base, past the table's own AddChild - a cell is the
    --> table's own furniture, not something being put in one.
    TABLE.BaseClass.AddChild(self, cell)

    return cell
end

--- Adds a row, one cell per column.
--- Anything handed to it is written into the cells across the row, left to
--- right, as labels - the same as calling SetCell on each of them.
--- @param ... string|number|nil What to write in the cells, one per column.
--- @return number index
function TABLE:AddRow(...)
    --> A table with no columns has nowhere to put a row, so the first one
    --> brings a column with it.
    if #self.columns == 0 then
        self:AddColumn()
    end

    local row = {h = self.rowHeight, cells = {}}

    table.insert(self.rows, row)

    local index = #self.rows

    for i = 1, #self.columns do
        row.cells[i] = self:MakeCell(index, i)
    end

    --> select rather than a table of them, so a nil left in the middle of the
    --> list skips that cell rather than cutting the rest of the row off.
    for i = 1, select("#", ...) do
        local value = select(i, ...)

        if value ~= nil then
            self:SetCell(index, i, tostring(value))
        end
    end

    self:InvalidateLayout()

    return index
end

--- Removes a row and everything in it.
--- @param index number
function TABLE:RemoveRow(index)
    local row = table.remove(self.rows, index)

    if not row then return end

    for _, cell in ipairs(row.cells) do
        cell:SetParent(nil)
    end

    --> Every row under the one that went moves up, and a cell carries the row
    --> it is in, so they are told where they ended up - a button in a cell can
    --> then still say which row it is sitting in.
    for i = index, #self.rows do
        for _, cell in ipairs(self.rows[i].cells) do
            cell.row = i
        end
    end

    self:InvalidateLayout()
end

--- Takes every row off the table, leaving the columns as they are.
function TABLE:Clear()
    for i = #self.rows, 1, -1 do
        self:RemoveRow(i)
    end
end

--- Gets how many rows the table has.
--- @return number count
function TABLE:GetRowCount()
    return #self.rows
end

--- Gets the cell where a row meets a column, which is what widgets are parented
--- to.
--- @param row number
--- @param column string|number Name or index of the column.
--- @return table|nil cell
function TABLE:GetCell(row, column)
    local at = self.rows[row]

    if not at then return nil end

    local index = self:FindColumn(column)

    return index and at.cells[index] or nil
end

--- Writes a line of text into a cell.
--- @param row number
--- @param column string|number Name or index of the column.
--- @param text string
--- @return table|nil label The label holding it.
function TABLE:SetCell(row, column, text)
    local cell = self:GetCell(row, column)

    if not cell then return nil end

    --> The label already in the cell is written over rather than another one
    --> being put under it, so writing to the same cell twice leaves one line of
    --> text rather than two.
    for _, child in ipairs(cell.children) do
        if occ.isa(child, "label") then
            child:SetText(text)

            return child
        end
    end

    local label = occ.label(text, cell)

    --> Laid the way the heading over it is - the cell hands the label its full
    --> width, so the text has the column to sit across.
    label:SetAlign(self.align)

    return label
end

--- Gets the text written in a cell.
--- @param row number
--- @param column string|number Name or index of the column.
--- @return string|nil text Nothing when the cell holds no text of its own.
function TABLE:GetCellText(row, column)
    local cell = self:GetCell(row, column)

    if not cell then return nil end

    for _, child in ipairs(cell.children) do
        if occ.isa(child, "label") then
            return child:GetText()
        end
    end

    return nil
end

--- Is a widget one of the table's own cells?
--- @param widget table
--- @return boolean
function TABLE:IsCell(widget)
    return occ.isa(widget, "tablecell") and widget.tablepanel == self
end

--- The first cell with nothing in it, adding a row when they are all taken.
--- @return table cell
function TABLE:NextFreeCell()
    if #self.columns == 0 then
        self:AddColumn()
    end

    --> A row at a time and left to right within it, so widgets handed to the
    --> table fill it the way it reads.
    for _, row in ipairs(self.rows) do
        for _, cell in ipairs(row.cells) do
            if #cell.children == 0 then
                return cell
            end
        end
    end

    local index = self:AddRow()

    return self.rows[index].cells[1]
end

--- Adds a child.
--- Anything that is not one of the table's own cells goes into the first free
--- cell, so a widget can be parented to the table itself and still land
--- somewhere the table lays out.
--- @param widget table
function TABLE:AddChild(widget)
    if widget and widget ~= self and not self:IsCell(widget) then
        widget:SetParent(self:NextFreeCell())
        return
    end

    TABLE.BaseClass.AddChild(self, widget)
end

--- Sets how the headings and the text in the cells sit across their columns.
--- @param align string "left", "center" or "right".
function TABLE:SetAlign(align)
    align = align or "left"

    if self.align == align then return end

    self.align = align

    --> The text already written into the cells is laid again, so the table does
    --> not come out half one way and half the other.
    for _, row in ipairs(self.rows) do
        for _, cell in ipairs(row.cells) do
            for _, child in ipairs(cell.children) do
                if occ.isa(child, "label") then
                    child:SetAlign(align)
                end
            end
        end
    end
end

--- Gets how the headings and the text in the cells sit across their columns.
--- @return string align
function TABLE:GetAlign()
    return self.align
end

--- Sets whether the table takes the height of its rows.
--- @param autosize boolean
function TABLE:SetAutoSize(autosize)
    self.autosize = autosize

    self:InvalidateLayout()
end

--- Does the table take the height of its rows?
--- @return boolean autosize
function TABLE:GetAutoSize()
    return self.autosize
end

--- Sets the font the column names draw with.
--- @param font string|nil Name occ.font knows, nil for the style's own.
function TABLE:SetFont(font)
    self.font = font
end

--- Gets the font the column names draw with.
--- @return string font
function TABLE:GetFont()
    return self.font or occ.style.tablepanel.font
end

--- Creates a table panel.
--- @param parent table|nil Widget to parent it to, occ.root by default.
--- @param ... string Names of columns to add right away.
--- @return table tablepanel
function occ.tablepanel(parent, ...)
    local made = occ.create("tablepanel", parent or occ.root)

    for _, name in ipairs({...}) do
        made:AddColumn(name)
    end

    return made
end
