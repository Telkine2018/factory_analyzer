local tools = require("scripts.tools")
local commons = require("scripts.commons")
local Production = require("scripts.production")

local debug = tools.debug
local prefix = commons.prefix

local name_w = commons.name_w
local value_w = commons.value_w
local status_w = commons.status_w
local button_with = commons.button_with

local get_product_name = commons.get_product_name
local get_consumed_numbers = commons.get_consumed_numbers
local get_produced_numbers = commons.get_produced_numbers

local ProductPanel = {}

---@param inner_frame LuaGuiElement
---@param factory Factory
---@param product string    
function ProductPanel.create(inner_frame, factory, product)

    inner_frame.clear()
    inner_frame.tags = {mode = "product", product = product}

    local solver = factory.solver
    local onlytheoric = factory.onlytheoric

    local product_panel = inner_frame.add {
        type = "table",
        direction = "vertical",
        column_count = 4 + (onlytheoric and 0 or 1) + ((solver or not onlytheoric) and 1 or 0),
        name = "product_table"
    }
    product_panel.vertical_centering = false
    product_panel.draw_horizontal_line_after_headers = true

    ---@param name string
    local function add_label(name, w)

        if not w then w = value_w end
        local element = product_panel.add {
            type = "label",
            caption = {prefix .. "." .. name}
        }

        element.style.minimal_width = w
        element.style.horizontal_align = "center"
    end

    -- machine
    product_panel.add {type = "label"}

    add_label("recipe")
    add_label("produced_rate")
    add_label("consumed_rate")
    if not onlytheoric then add_label("machine_status") end
    if solver or not onlytheoric then
        add_label("usage")
    end

    local machines = Production.select_machines(factory, product)

    local function add_empty_slot_with_name(full_name)

        local flow = product_panel.add {
            type = "flow",
            name = full_name,
            direction = "horizontal"
        }
        flow.style.minimal_width = value_w

        local label

        if not onlytheoric then
            label = flow.add {type = "label", name = "real"}
            label.style.horizontal_align = "right"
            label.style.minimal_width = (value_w - 5) / 2
            label = flow.add {type = "label", caption = "/", name = "separator"}
        end
        label = flow.add {type = "label", name = "theorical"}
        if not onlytheoric then
            label.style.horizontal_align = "left"
            label.style.minimal_width = (value_w - 5) / 2
        else
            label.style.horizontal_align = "center"
            label.style.minimal_width = value_w
        end
        return flow
    end

    local function add_empty_slot(machine, field_name)

        local full_name = "m" .. machine.id .. "/" .. field_name
        return add_empty_slot_with_name(full_name)
    end

    local function add_usage(machine)
        local full_name = "m" .. machine.id .. "/usage" 
        local label = product_panel.add {
            type = "label",
            name = full_name
        }
        label.style.minimal_width = value_w
        label.style.horizontal_align = "center"
    end

    local recipe_flow

    local function add_button(product, type, machine)

        local button = recipe_flow.add {
            type = "sprite-button",
            sprite = product,
            style = prefix .. "_button_default",
            name = product .. "/" .. type
        }
        button.raise_hover_events = true
        button.tags = {
            product = product,
            recipe_element_type = type,
            machine = machine.id,
            name = product .. "/" .. type
        }
    end

    for _, machine in pairs(machines) do

        local proto = game.entity_prototypes[machine.name]
        local item = proto.items_to_place_this[1].name
        local label_flow = product_panel.add {
            type = "flow",
            direction = "horizontal"
        }
        local machine_button = label_flow.add {
            type = "sprite-button",
            sprite = "item/" .. item,
            tooltip = proto.localised_name,
            style = prefix .. "_button_default",
            name = prefix .. "_machine"
        }
        machine_button.tags = {id = machine.id}
        machine_button.style.right_margin = 10

        recipe_flow = product_panel.add {
            type = "flow",
            direction = "horizontal",
            name = "recipe_flow_" .. machine.id
        }
        for n, count in pairs(machine.ingredients) do
            add_button(n, "consumed", machine)
        end

        recipe_flow.add {type = "label", caption = " -> "}

        for n, count in pairs(machine.products) do
            add_button(n, "produced", machine)
        end

        add_empty_slot(machine, "produced")
        add_empty_slot(machine, "consumed")

        if not onlytheoric then
            local status_label = product_panel.add {
                type = "label",
                caption = "",
                name = "m" .. machine.id .. "/status"
            }
            status_label.style.horizontal_align = "center"
            status_label.style.minimal_width = status_w
        end

        if solver or not onlytheoric then
            add_usage(machine)            
        end
    end

    -- name
    product_panel.add {type = "label", caption = {prefix .. ".total"}}
    -- recipe
    product_panel.add {type = "empty-widget"}

    add_empty_slot_with_name("total_produced")
    add_empty_slot_with_name("total_consumed")
end

local status_names = {}
for name, value in pairs(defines.entity_status) do status_names[value] = name end

local status_colors = {
    [defines.entity_status.working] = {0, 1, 0, 1},
    [defines.entity_status.normal] = {0, 1, 0, 1},
    [defines.entity_status.no_power] = {1, 0, 0, 1},
    [defines.entity_status.low_power] = {1, 0, 0, 1},
    [defines.entity_status.no_fuel] = {1, 0, 0, 1},
    [defines.entity_status.disabled_by_script] = {1, 0, 0, 1},
    [defines.entity_status.marked_for_deconstruction] = {1, 0, 0, 1},
    [defines.entity_status.no_recipe] = {1, 1, 1, 1},
    [defines.entity_status.no_ingredients] = {1, 0.5, 0, 1},
    [defines.entity_status.no_minable_resources] = {1, 0.5, 0, 1},
    [defines.entity_status.fluid_ingredient_shortage] = {1, 0.5, 0, 1},
    [defines.entity_status.full_output] = {1, 1, 0, 1},
    [defines.entity_status.item_ingredient_shortage] = {1, 0.5, 0, 1},
    [defines.entity_status.missing_required_fluid] = {1, 0.5, 0, 1},
    [defines.entity_status.waiting_for_space_in_destination] = {1, 1, 0, 1}
}

---@param inner_frame LuaGuiElement
---@param factory Factory
function ProductPanel.update(inner_frame, factory)

    local solver = factory.solver
    local onlytheoric = factory.onlytheoric

    local product = inner_frame.tags.product --[[@as string]]
    local machines = Production.select_machines(factory, product)
    local product_table = tools.get_child(inner_frame, "product_table")
    ---@cast product_table -nil

    local function set_label_rate(machine, field_name, real, theorical)

        local full_name = "m" .. machine.id .. "/" .. field_name
        local element = product_table[full_name]
        real = real * factory.unit_coef
        theorical = theorical * factory.unit_coef
        commons.set_element_values(element, real, theorical)
        return element
    end

    local theorical_consumed = 0
    local real_consumed = 0
    local theorical_produced = 0
    local real_produced = 0

    ---@param machine Machine
    local function set_product(machine)

        local real, theorical = get_consumed_numbers(machine, product)
        theorical = theorical * machine.usage
        set_label_rate(machine, "consumed", real, theorical)
        theorical_consumed = theorical_consumed + theorical
        real_consumed = real_consumed + real

        real, theorical = get_produced_numbers(machine, product)
        theorical = theorical * machine.usage
        local t_product_base = machine.products[product]
        set_label_rate(machine, "produced", real, theorical)
        theorical_produced = theorical_produced + theorical
        real_produced = real_produced + real

        local status = machine.entity.status
        local element = product_table["m" .. machine.id .. "/status"]
        if element then
            local color = status_colors[status]
            if not color then color = {1, 1, 1, 1} end
            local status_name = status_names[status]
            element.caption = {prefix .. "_status." .. status_name}
            element.style.font_color = color
        end

        if not onlytheoric then
            if machine.missing_product then
                local recipe_flow = product_table["recipe_flow_" .. machine.id]
                local button = recipe_flow[machine.missing_product ..
                                   "/consumed"]
                if button then
                    button.style = prefix .. "_button_missing"
                end
                machine.previous_missing_product = machine.missing_product
            elseif machine.previous_missing_product then
                local recipe_flow = product_table["recipe_flow_" .. machine.id]
                local button = recipe_flow[machine.previous_missing_product ..
                                   "/consumed"]
                button.style = prefix .. "_button_default"
                machine.previous_missing_product = nil
            end

            if machine.full_output_product then
                local recipe_flow = product_table["recipe_flow_" .. machine.id]
                local button = recipe_flow[machine.full_output_product ..
                                   "/produced"]
                if button then
                    button.style = prefix .. "_button_missing"
                end
                machine.previous_full_output_product =
                    machine.full_output_product
            elseif machine.previous_full_output_product then
                local recipe_flow = product_table["recipe_flow_" .. machine.id]
                local button =
                    recipe_flow[machine.previous_full_output_product ..
                        "/produced"]
                button.style = prefix .. "_button_default"
                machine.previous_full_output_product = nil
            end
        end

        if solver or not onlytheoric then
            local field_name =  "m" .. machine.id .. "/usage" 
            local usage_label = product_table[field_name]
            if usage_label then
                local usage
                if onlytheoric then
                    usage = machine.usage
                elseif solver then
                    usage = machine.craft_per_s / machine.produced_craft_s / machine.usage
                else
                    usage = machine.craft_per_s / machine.produced_craft_s 
                end
                usage_label.caption = string.format("%.1f", usage * 100) .. " %"
            end
        end
    end
    for _, machine in pairs(machines) do set_product(machine) end

    commons.set_element_values(product_table["total_consumed"], real_consumed,
                               theorical_consumed)
    commons.set_element_values(product_table["total_produced"], real_produced,
                               theorical_produced)
end


return ProductPanel
