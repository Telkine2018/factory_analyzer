local commons = require("scripts.commons")

local prefix = commons.prefix
local png = commons.png

local selection_tool = {

    type = "selection-tool",
    name = prefix .. "-selection_tool",
    icon = png("icons/selection-tool"),
    icon_size = 32,
    selection_color = {r = 0, g = 0, b = 1},
    alt_selection_color = {r = 1, g = 0, b = 0},
    selection_mode = {"same-force", "any-entity"},
    alt_selection_mode = {"same-force", "any-entity"},
    selection_cursor_box_type = "entity",
    alt_selection_cursor_box_type = "entity",
    flags = {"hidden", "not-stackable", "only-in-cursor", "spawnable"},
    subgroup = "other",
    stack_size = 1,
    stackable = false,
    show_in_library = false,
    entity_type_filters = {"assembling-machine", "furnace", "mining-drill"},
    alt_entity_type_filters = {"assembling-machine", "furnace", "mining-drill"}
}

local shortcut = {
    type = "shortcut",
    name = prefix .. "-tool",
    order = "-aaa",
    action = "lua",
    icon = {
        filename = png("icons/tool-x32"),
        priority = "extra-high-no-scale",
        size = 32,
        scale = 1,
        flags = {"gui-icon"}
    },
    small_icon = {
        filename = png("icons/tool-x24"),
        priority = "extra-high-no-scale",
        size = 24,
        scale = 1,
        flags = {"gui-icon"}
    }
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


data:extend{selection_tool, shortcut, global_icon, failure_icon, unlink_icon, green_arrow}

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

