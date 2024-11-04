local commons = require("scripts.commons")

local prefix = commons.prefix
local png = commons.png

local selection_tool = {

    type = "selection-tool",
    name = prefix .. "-selection_tool",
    icon = png("icons/selection-tool"),
    icon_size = 32,


    select = {
        border_color = { r=0, g=0, b=1 },
        cursor_box_type = "entity",
        mode = {"same-force", "any-entity" },
        entity_type_filters = {"assembling-machine", "furnace", "mining-drill"}
    },
    
    alt_select = {
        border_color = { r=0, g=0, b=1 },
        cursor_box_type = "entity",
        mode = {"same-force", "any-entity" },
        alt_entity_type_filters = {"assembling-machine", "furnace", "mining-drill"}
    },
    
    flags = { "not-stackable", "only-in-cursor", "spawnable"},
    subgroup = "other",
    stack_size = 1,
    stackable = false
}

local shortcut = {
    type = "shortcut",
    name = prefix .. "-tool",
    order = "-aaa",
    action = "lua",
    icon = png("icons/tool-x32"),
    icon_size = 32,
    small_icon  = png("icons/tool-x24"),
    small_icon_size = 24
}

local global_icon = {
    type = "sprite",
    name = prefix .. "-global-icon",
    filename = png("icons/global-icon"),
    priority = "low",
    width = 32,
    height = 32
}

local failure_icon = {
    type = "sprite",
    name = prefix .. "-failure",
    filename = png("icons/failure"),
    priority = "low",
    width = 16,
    height = 16
}

local unlink_icon = {
    type = "sprite",
    name = prefix .. "-unlink",
    filename = png("icons/unlink"),
    priority = "low",
    width = 16,
    height = 16
}

local green_arrow = {
    type = "sprite",
    name = prefix .. "-green_arrow",
    filename = png("icons/green-arrow"),
    width = 64,
    height = 64
}

local graph_icon = {
    type = "sprite",
    name = prefix .. "-graph",
    filename = png("icons/graph"),
    width = 40,
    height = 40
}

data:extend{selection_tool, shortcut, global_icon, failure_icon, unlink_icon, green_arrow, graph_icon}

local styles = data.raw["gui-style"].default


styles[prefix .. "_button_default"] = {
    parent = "flib_slot_button_default",
    type = "button_style",
    size = 28
}

styles[prefix .. "_button_missing"] = {
    parent = "flib_selected_slot_button_default",
    type = "button_style",
    size = 28
}

styles[prefix .. "_button_free"] = {
    parent = "flib_slot_button_yellow",
    type = "button_style",
    size = 28
}


data:extend
{
    {
        type = "custom-input",
        name = commons.shift_button1_event,
        key_sequence = "SHIFT + mouse-button-1",
        consuming = "none"
    },
    {
        type = "custom-input",
        name = commons.shift_button2_event,
        key_sequence = "SHIFT + mouse-button-2",
        consuming = "none"
    }
}

