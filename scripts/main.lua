local tools = require("scripts.tools")
local commons = require("scripts.commons")
local Production = require("scripts.production")
local Summary = require("scripts.summary")
local ProductPanel = require("scripts.product_panel")
local Autolib = require("scripts.autolib")
local Entities = require("scripts.entities")

local debug = tools.debug
local prefix = commons.prefix

local name_w = commons.name_w
local value_w = commons.value_w
local status_w = commons.status_w
local button_with = commons.button_with
local frame_name = commons.frame_name

local get_product_name = commons.get_product_name
local get_consumed_numbers = commons.get_consumed_numbers
local get_produced_numbers = commons.get_produced_numbers

local Analyzer = {}

local frame_name = prefix .. "-frame"
local unselected_button_style = "flib_selected_slot_blue"
local selected_button_style = "flib_selected_slot_grey"

local unit_coefs = { 1, 60, 3600 }

local unit_labels = { "/s", "/m", "/h" }

local function change_selection(vars, new_selected)
    if vars.selected and vars.selected.valid then
        vars.selected.style = unselected_button_style
        vars.selected = nil
    end

    if new_selected then
        new_selected.style = selected_button_style
        vars.selected = new_selected
    end
end

---@param player any
---@return LuaGuiElement
local function get_frame(player) return player.gui.screen[frame_name] end

---@param player LuaPlayer
---@param factory Factory
---@return LuaGuiElement
function Analyzer.create_frame(player, factory)
    local vars = tools.get_vars(player)
    local frame = get_frame(player)
    if frame then
        local inner_frame = tools.get_child(frame, "inner_frame")
        ---@cast inner_frame -nil
        inner_frame.clear()
        Summary.create(factory, inner_frame)
        return frame
    end

    frame = player.gui.screen.add {
        type = "frame",
        direction = 'vertical',
        name = frame_name
    }

    local titleflow = frame.add { type = "flow" }
    titleflow.add {
        type = "label",
        caption = { prefix .. ".frame_title" },
        style = "frame_title",
        ignored_by_interaction = true
    }
    local drag = titleflow.add {
        type = "empty-widget",
        style = "flib_titlebar_drag_handle"
    }
    drag.drag_target = frame
    titleflow.drag_target = frame
    titleflow.add {
        type = "sprite-button",
        name = prefix .. "-frame_close",
        tooltip = { prefix .. ".close_tooltip" },
        style = "frame_action_button",
        mouse_button_filter = { "left" },
        sprite = "utility/close",
        hovered_sprite = "utility/close_black"
    }

    -- #region Command frame
    local command_frame = frame.add {
        type = "frame",
        name = "command_frame",
        style = "inside_shallow_frame_with_padding",
        direction = "vertical"
    }

    local command_flow = command_frame.add {
        type = "flow",
        direction = "horizontal"
    }
    command_flow.add { type = "label", caption = { prefix .. ".period" } }
    local period_items = {
        { prefix .. ".period2s" }, { prefix .. ".period5s" },
        { prefix .. ".period10s" }, { prefix .. ".period30s" },
        { prefix .. ".period1min" }, { prefix .. ".all" }
    }
    local period_index = vars.period_index or 1
    command_flow.add {
        type = "drop-down",
        name = prefix .. ".period",
        items = period_items,
        selected_index = period_index
    }

    local progress = command_flow.add {
        type = "progressbar",
        value = 0,
        name = "progress",
        direction = "vertical"
    }
    progress.style.color = { 0, 1, 0, 1 }
    progress.style.font_color = { 0, 0, 0, 1 }
    progress.style.width = 50
    progress.style.bar_width = 21
    vars.progress = progress

    local label = command_flow.add {
        type = "label",
        caption = { prefix .. ".unit" }
    }
    label.style.left_margin = 10
    local unit_items = {
        { prefix .. ".unit_per_sec" }, { prefix .. ".unit_per_min" },
        { prefix .. ".unit_per_hour" }
    }
    local unit_index = vars.unit_index or 1
    command_flow.add {
        type = "drop-down",
        name = prefix .. ".unit",
        items = unit_items,
        selected_index = unit_index
    }

    local command_flow2 = command_frame.add {
        type = "flow",
        direction = "horizontal"
    }
    command_flow2.style.top_margin = 5

    if vars.auto_add == nil then vars.auto_add = true end
    local cb = command_flow2.add {
        type = "checkbox",
        name = prefix .. "_autoadd",
        caption = { prefix .. ".autoadd_caption" },
        tooltip = { prefix .. ".autoadd_tooltip" },
        state = vars.auto_add
    }
    cb.style.left_margin = 10

    cb = command_flow2.add {
        type = "checkbox",
        name = prefix .. "_onlytheoric",
        caption = { prefix .. ".onlytheoric_caption" },
        tooltip = { prefix .. ".onlytheoric_tooltip" },
        state = factory.onlytheoric or false
    }
    cb.style.left_margin = 10

    cb = command_flow2.add {
        type = "checkbox",
        name = prefix .. "_solver",
        caption = { prefix .. ".solver_caption" },
        tooltip = { prefix .. ".solver_tooltip" },
        state = vars.solver or false
    }
    cb.style.left_margin = 10

    local solver_failure_sprite = command_flow2.add {
        type = "sprite",
        sprite = prefix .. "-failure",
        name = "solver-failure",
        tooltip = { prefix .. ".solver_failure_tooltip" }
    }
    solver_failure_sprite.visible = factory.solver_failure

    cb = command_flow2.add {
        type = "checkbox",
        name = prefix .. "_itempers",
        caption = { prefix .. ".itempers_caption" },
        tooltip = { prefix .. ".itempers_tooltip" },
        state = vars.itempers or false
    }
    cb.style.left_margin = 10

    local bgraph = command_flow2.add {
        type = "sprite-button",
        sprite = prefix .. "-graph"
    }
    bgraph.style.size = 28
    tools.set_name_handler(bgraph, prefix .. ".bgraph");

    -- ]]

    -- #endregion

    -- #region Select frame

    local select_frame = frame.add {
        type = "frame",
        name = "select_frame",
        style = "inside_shallow_frame_with_padding",
        direction = "horizontal"
    }

    local b = select_frame.add {
        type = "sprite-button",
        sprite = prefix .. "-global-icon",
        name = prefix .. ".global_button",
        style = selected_button_style
    }
    vars.selected = b

    -- #endregion

    frame.force_auto_center()

    local content_scroll = frame.add {
        type = "scroll-pane",
        vertical_scroll_policy = "never"
    }
    content_scroll.style.maximal_width = 800

    local content_scroll = frame.add {
        type = "scroll-pane",
        horizontal_scroll_policy = "never"
    }

    content_scroll.style.minimal_width = 400
    content_scroll.style.minimal_height = 30
    content_scroll.style.maximal_height = 500

    local inner_frame = content_scroll.add {
        type = "frame",
        name = "inner_frame",
        style = "inside_shallow_frame_with_padding",
        direction = "vertical"
    }

    Summary.create(factory, inner_frame)
    return frame
end

tools.on_event(defines.events.on_gui_checked_state_changed,
    ---@param e EventData.on_gui_checked_state_changed
    function(e)
        if (e.element.name == prefix .. "_autoadd") then
            local player = game.players[e.player_index]
            local vars = tools.get_vars(player)
            vars.auto_add = e.element.state
        elseif (e.element.name == prefix .. "_onlytheoric") then
            local player = game.players[e.player_index]
            local vars = tools.get_vars(player)
            vars.onlytheoric = e.element.state
            ---@type Factory
            local factory = vars.factory
            if factory then
                factory.structure_change = true
                factory.onlytheoric = e.element.state
            end
        elseif (e.element.name == prefix .. "_solver") then
            local player = game.players[e.player_index]
            local vars = tools.get_vars(player)
            vars.solver = e.element.state
            ---@type Factory
            local factory = vars.factory
            if factory then
                factory.structure_change = true
                factory.solver = e.element.state
            end
        elseif (e.element.name == prefix .. "_itempers") then
            local player = game.players[e.player_index]
            local vars = tools.get_vars(player)
            vars.itempers = e.element.state
            ---@type Factory
            local factory = vars.factory
            if factory then
                factory.structure_change = true
                factory.itempers = e.element.state
            end
        end
    end)

---@param player LuaPlayer
function Analyzer.clear_buttons(player)
    local frame = get_frame(player)
    local inner_frame = tools.get_child(frame, "inner_frame")
    local select_frame = tools.get_child(frame, "select_frame")
    if not select_frame or not inner_frame then return end

    select_frame.clear()
    local b = select_frame.add {
        type = "sprite-button",
        sprite = prefix .. "-global-icon",
        name = prefix .. ".global_button",
        style = selected_button_style
    }
    tools.get_vars(player).selected = b
    inner_frame.tags.mode = "global"
end

---@param player LuaPlayer
---@param keepdata boolean?
function Analyzer.close(player, keepdata)
    Analyzer.clear_selected_machine(player)
    local vars = tools.get_vars(player)

    local frame = get_frame(player)
    if frame then frame.destroy() end

    if not keepdata then
        if vars.factory then
            Entities.clear(vars.factory)
            vars.factory = nil
        end
    end
end

tools.on_gui_click(prefix .. "-frame_close", ---@param e EventData.on_gui_click
    function(e)
        local player = game.players[e.player_index]
        Analyzer.close(player, e.shift)
    end)

tools.on_event(defines.events.on_player_changed_surface,
    ---@param e EventData.on_player_changed_surface
    function(e)
        local player = game.players[e.player_index]
        Analyzer.close(player)
    end)

---@param e EventData.on_gui_click
local function process_product_button(e)
    local player = game.players[e.player_index]
    local vars = tools.get_vars(player)
    local factory = vars.factory
    if not factory then return end

    local product = e.element.tags.product --[[@as string]]
    if not product then return end

    local frame = player.gui.screen[frame_name]
    if not frame then return end

    if not e.control then
        local inner_frame = tools.get_child(frame, "inner_frame")
        ---@cast inner_frame -nil

        ProductPanel.create(inner_frame, factory, product)
        factory.structure_change = true

        local select_frame = tools.get_child(frame, "select_frame")
        if select_frame then
            local name = "b." .. product
            local b = select_frame[name]
            local lname = get_product_name(product)
            if not b then
                b = select_frame.add {
                    type = "sprite-button",
                    name = name,
                    sprite = commons.get_sprite_name(product),
                    tooltip = lname
                }
                b.tags = { product = product }
            end
            change_selection(vars, b)
        end
    else
        local is_free = factory.free_products[product] or false
        is_free = not is_free
        factory.free_products[product] = is_free
        local sprite = e.element.parent["sprite.unlink"]
        if sprite then sprite.visible = is_free end
        factory.structure_change = true
    end
end

-- tools.on_gui_click(prefix .. ".product", process_product_button)

tools.on_event(defines.events.on_gui_click, ---@param e EventData.on_gui_click
    function(e)
        if e.element.valid and e.element.tags and e.element.tags.product then
            process_product_button(e)
        end
    end)

tools.on_gui_click(prefix .. ".global_button",
    ---@param e EventData.on_gui_click
    function(e)
        local player = game.players[e.player_index]
        local vars = tools.get_vars(player)
        local factory = vars.factory
        if not factory then return end

        local frame = player.gui.screen[frame_name]
        if not frame then return end

        local inner_frame = tools.get_child(frame, "inner_frame")
        if not inner_frame then return end

        factory.structure_change = true
        change_selection(vars, e.element)
        Summary.create(factory, inner_frame)
    end)

function Analyzer.clear_arrow(vars)
    if vars.selected_arrow then
        vars.selected_arrow.destroy()
        vars.selected_arrow = nil
        vars.selected_entity = nil
    end
end

function Analyzer.clear_selected_machine(player)
    local vars = tools.get_vars(player)
    if vars.selected_machine then
        vars.selected_machine.destroy()
        vars.selected_machine = nil
        vars.selected_id = nil
        Analyzer.clear_arrow(vars)
    end
end

function Analyzer.show_arrow(player)
    local vars = tools.get_vars(player)
    local entity = vars.selected_entity
    if not entity then return end

    if not entity.valid or entity.surface ~= player.surface then
        Analyzer.clear_selected_machine(player)
        return
    end

    local p1 = player.position
    local p2 = entity.position

    local unit = { x = p2.x - p1.x, y = p2.y - p1.y }
    local dist = math.sqrt(unit.x * unit.x + unit.y * unit.y)
    if dist < 5 then
        Analyzer.clear_arrow(vars)
        return
    end

    unit = { x = unit.x / dist, y = unit.y / dist }
    local len = 5

    local sprite_pos = { x = p1.x + len * unit.x, y = p1.y + len * unit.y }

    if vars.selected_arrow then
        vars.selected_arrow.target = sprite_pos
    else
        vars.selected_arrow = rendering.draw_sprite {
            sprite = prefix .. "-green_arrow",
            target = sprite_pos,
            orientation_target = p2,
            surface = player.surface,
            players = { player }
        }
    end
end

function Analyzer.show_selected_machine(player, entity)
    local vars = tools.get_vars(player)
    local w = entity.prototype.tile_width
    local h = entity.prototype.tile_height

    vars.selected_id = entity.unit_number
    vars.selected_machine = rendering.draw_rectangle {
        surface = entity.surface,
        left_top = { entity = entity, offset = { -w / 2, -h / 2 } },
        right_bottom = { entity = entity, offset = { w / 2, h / 2 } },
        width = 3,
        color = { 0, 1, 0, 1 }
    }
    vars.selected_entity = entity
    Analyzer.show_arrow(player)
end

tools.on_event(defines.events.on_player_changed_position,
    ---@param e EventData.on_player_changed_position
    function(e)
        local player = game.players[e.player_index]
        Analyzer.show_arrow(player)
    end)

tools.on_gui_click(prefix .. "_machine", ---@param e EventData.on_gui_click
    function(e)
        local player = game.players[e.player_index]
        local vars = tools.get_vars(player)
        ---@type Factory
        local factory = vars.factory
        if not factory then return end

        local id = e.element.tags.id

        ---@type Machine
        local machine = factory.machine_map[id]
        if not machine then return end

        if e.control then
            if machine.text_id then machine.text_id.destroy() end
            factory.machine_map[id] = nil
            factory.structure_change = true
            return
        end

        ---@type LuaEntity
        local entity = machine.entity
        if not entity.valid then return end

        if vars.selected_id == entity.unit_number then
            Analyzer.clear_selected_machine(player)
            return
        end

        Analyzer.clear_selected_machine(player)
        Analyzer.show_selected_machine(player, entity)
    end)

tools.on_event(defines.events.on_gui_selection_state_changed,
    ---@param e EventData.on_gui_selection_state_changed
    function(e)
        local player = game.players[e.player_index]
        if (e.element.name == prefix .. ".period") then
            local vars = tools.get_vars(player)
            vars.period_index = e.element.selected_index
        elseif (e.element.name == prefix .. ".unit") then
            local vars = tools.get_vars(player)
            vars.unit_index = e.element.selected_index
            ---@type Factory
            local factory = vars.factory
            if factory then
                factory.structure_change = true
                factory.unit_coef = unit_coefs[e.element.selected_index]
                factory.unit_label = unit_labels[e.element.selected_index]
            end
        end
    end)

---@param player LuaPlayer
---@param factory Factory
function Analyzer.update_inner_panel(player, factory)
    if factory.solver_failure then
        local changed = false
        if (factory.prev_var_values) then
            for name, _ in pairs(factory.var_values) do
                if factory.prev_var_values[name] ~= factory.var_values[name] then
                    changed = true
                    break
                end
            end
        else
            changed = true
        end

        local msg = { "", { prefix .. ".failing_recipes" } }
        if changed then
            local first = true
            local count = 0
            for name, value in pairs(factory.var_values) do
                if value < 0 or value > 1 then
                    if not first then
                        table.insert(msg, ",")
                    else
                        first = false
                    end
                    local recipe = prototypes.recipe[name]
                    if recipe then
                        table.insert(msg, prototypes.recipe[name].localised_name)
                    end
                    count = count + 1
                    if count >= 8 then break end
                end
            end
            player.print(msg)
        end
        factory.prev_var_values = factory.var_values
    else
        factory.prev_var_values = nil
    end

    local frame = player.gui.screen[frame_name]
    local inner_frame = tools.get_child(frame, "inner_frame")
    if not inner_frame then return end

    if inner_frame.tags.mode == "global" then
        if factory.structure_change then
            Summary.create(factory, inner_frame)
            factory.structure_change = false
        end
        Summary.update(frame, factory)
    elseif inner_frame.tags.mode == "product" then
        if factory.structure_change then
            local product = inner_frame.tags.product --[[@as string]]
            ProductPanel.create(inner_frame, factory, product)
            factory.structure_change = false
        end
        ProductPanel.update(inner_frame, factory)
    end

    local solver_failure_sprite = tools.get_child(frame, "solver-failure")
    solver_failure_sprite.visible = factory.solver_failure

    Entities.update(factory)
end

function Analyzer.create(vars, entities)
    local factory = Production.new_factory()
    factory.solver = vars.solver
    factory.onlytheoric = vars.onlytheoric
    factory.itempers = vars.itempers
    factory.unit_coef = unit_coefs[vars.unit_index or 1]
    factory.unit_label = unit_labels[vars.unit_index or 1]

    Production.replace_selection(factory, entities)
    vars.factory = factory

    return factory
end

---@param event EventData.on_player_selected_area
local function on_player_selected_area(event)
    local player = game.players[event.player_index]

    if event.item ~= prefix .. "-selection_tool" then return end

    local vars = tools.get_vars(player)
    if vars.factory then Entities.clear(vars.factory) end

    local factory = Analyzer.create(vars, event.entities)
    local frame = Analyzer.create_frame(player, factory)
    Summary.update(frame, factory)
    Analyzer.clear_buttons(player)
end

---@param event EventData.on_player_selected_area
local function on_player_alt_selected_area(event)
    local player = game.players[event.player_index]

    if event.item ~= prefix .. "-selection_tool" then return end

    local vars = tools.get_vars(player)
    local factory = vars.factory
    if not factory then
        factory = Analyzer.create(vars, event.entities)
    else
        Production.add_to_selection(factory, event.entities)
    end

    local frame = Analyzer.create_frame(player, factory)
    Summary.update(frame, factory)
    Analyzer.clear_buttons(player)
end

tools.on_event(defines.events.on_player_selected_area, on_player_selected_area)

tools.on_event(defines.events.on_player_alt_selected_area,
    on_player_alt_selected_area)

tools.on_nth_tick(10, function()
    for _, player in pairs(game.players) do
        local vars = tools.get_vars(player)
        ---@type Factory
        local factory = vars.factory
        if factory then
            factory.unit_coef = factory.unit_coef or 1
            factory.unit_label = factory.unit_label or "/s"

            local frame = player.gui.screen[frame_name]
            local period_index = vars.period_index or 1
            local period = commons.period_values[period_index]
            local tick = game.tick
            local delay = period

            if frame and frame.valid then
                if factory.structure_change then
                    Production.compute_production(factory, period == 0)
                    Analyzer.update_inner_panel(player, factory)
                end

                if delay == 0 then delay = 120 end
                local progress = vars.progress
                if not factory.last_compute or
                    (factory.last_compute + delay <= tick) then
                    Production.compute_production(factory, period == 0)
                    Analyzer.update_inner_panel(player, factory)
                    if progress then progress.caption = "" end
                elseif factory.tick then
                    if progress then
                        local time = tick - factory.last_compute
                        progress.value = 1.0 * time / delay
                        local duration = (tick - factory.tick) / 60.0
                        if duration < 5 then
                            progress.caption =
                                string.format("%.1f", duration) .. " s"
                        else
                            progress.caption = math.floor(duration) .. " s"
                        end
                    end
                end
            else
                if factory.structure_change or not factory.last_compute or
                    (factory.last_compute + delay <= tick) then
                    Production.compute_production(factory, period == 0)
                    Entities.update(factory)
                end
            end
        end
    end
end)

---@param e (EventData.on_built_entity | EventData.script_raised_built)
local function on_build(e)
    local entity = e.entity
    local player_index = e.player_index

    if not entity.valid then
        return
    end

    local type = entity.type
    if type ~= "assembling-machine" and type ~= "furnace" and type ~=
        "mining-drill" then
        return
    end

    ---@type LuaPlayer
    local player
    if player_index then
        player = game.players[player_index]

        local vars = tools.get_vars(player)
        if vars.auto_add and player.surface == entity.surface then
            local factory = vars.factory
            if factory then
                Production.add_machine(factory, entity)
            end
        end
        return
    end
    for _, player in pairs(game.players) do
        if entity.force_index == player.force_index then
            local vars = tools.get_vars(player)
            if vars.auto_add and player.surface == entity.surface then
                local factory = vars.factory
                if factory then
                    Production.add_machine(factory, entity)
                end
            end
        end
    end
end

tools.on_event(defines.events.on_built_entity, on_build)
tools.on_event(defines.events.on_robot_built_entity, on_build)
tools.on_event(defines.events.script_raised_built, on_build)
tools.on_event(defines.events.script_raised_revive, on_build)


---@param evt EventData.on_pre_player_mined_item|EventData.on_entity_died|EventData.script_raised_destroy
local function on_destroyed(evt)
    for _, player in pairs(game.players) do
        if evt.entity and evt.entity.force_index == player.force_index then
            local vars = tools.get_vars(player)
            local factory = vars.factory
            if factory then
                factory.structure_change = true
            end
        end
    end
end

local entity_destroyed_filter = {
    { filter = 'type', type = "assembling-machine" },
    { filter = 'type', type = "furnace" },
    { filter = 'type', type = "mining-drill" },
}

tools.on_event(defines.events.on_pre_player_mined_item, on_destroyed, entity_destroyed_filter)
tools.on_event(defines.events.on_robot_pre_mined, on_destroyed, entity_destroyed_filter)


tools.on_event(defines.events.on_gui_hover, ---@param e EventData.on_gui_hover
    function(e)
        local player = game.players[e.player_index]

        local tags = e.element.tags
        local type = tags.recipe_element_type --[[@as string]]
        local product = tags.product --[[@as string]]
        local machine_id = tags.machine --[[@as integer]]
        if not (tags and product and machine_id) then return end
        local vars = tools.get_vars(player)

        local factory = vars.factory
        if not factory then return end

        local machine = factory.machine_map[machine_id]
        if not machine then return end

        local label, signal = get_product_name(product)

        local format
        if factory.onlytheoric then
            format = prefix .. ".tooltip_format_onlytheoric"
        else
            format = prefix .. ".tooltip_format"
        end

        local real, theorical
        if type == "consumed" then
            real, theorical = get_consumed_numbers(machine, product)
        else
            real, theorical = get_produced_numbers(machine, product)
        end
        theorical = theorical * machine.usage

        local tooltip = {
            format, string.format("%.2f", real), string.format("%.2f", theorical),
            "[" .. signal.type .. "=" .. commons.get_sprite_name(signal.name) .. "]", label
        }
        e.element.tooltip = tooltip
    end)

tools.on_event(defines.events.on_lua_shortcut, function(e)
    if (e.prototype_name ~= prefix .. "-tool") then return end

    ---@type LuaPlayer
    local player = game.players[e.player_index]
    local vars = tools.get_vars(player)

    player.cursor_stack.clear()
    player.cursor_stack.set_stack(prefix .. "-selection_tool")

    local frame = get_frame(player)
    if vars.factory and not frame then
        Analyzer.create_frame(player, vars.factory)
    end
end)

tools.on_named_event(prefix .. ".bgraph", defines.events.on_gui_click,
    ---@param e EventData.on_gui_click
    function(e)
        ---@type LuaPlayer
        local player = game.players[e.player_index]
        local vars = tools.get_vars(player)

        ---@type Factory
        local factory = vars.factory

        if not factory.machines then
            return
        end

        ---@type RemoteConfig
        local config = {}
        local recipes = {}
        for _, machine in pairs(factory.machines) do
            local name = machine.recipe_name
            local recipe = { name = name }
            recipes[name] = recipe
        end
        config.recipes = recipes

        if (remote.interfaces["factory_graph"]) then
            remote.call("factory_graph", "add_recipes", e.player_index, config)
        else
            player.print("Mod Factory graph not present")
        end
    end)

remote.add_interface("factory_analyzer", {

    ---@param player_index integer      -- train id
    ---@return table<string, number>?
    get_ingredients = function(player_index)
        ---@type LuaPlayer
        local player = game.players[player_index]
        local vars = tools.get_vars(player)

        ---@type Factory
        local factory = vars.factory
        if not factory then return nil end

        if not factory.theorical_ingredient_map then return nil end

        local result = {}
        for name, amount in pairs(factory.theorical_ingredient_map) do
            if not factory.theorical_product_map[name] then
                result[name] = amount
            end
        end
        return result
    end
})

tools.on_configuration_changed(function(data)
    for _, player in pairs(game.players) do
        Analyzer.close(player)
    end
end
)
