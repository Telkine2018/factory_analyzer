local tools = require("scripts.tools")
local commons = require("scripts.commons")
local Production = require("scripts.production")

local debug = tools.debug
local prefix = commons.prefix

local name_w = commons.name_w
local value_w = commons.value_w
local status_w = commons.status_w
local usage_w = 80
local button_with = commons.button_with

local get_product_name = commons.get_product_name

local Summary = {}

---@param factory Factory
---@param inner_frame LuaGuiElement
function Summary.create(factory, inner_frame)

    local solver = factory.solver
    local onlytheoric = factory.onlytheoric
    inner_frame.clear()

    ---@type LuaGuiElement
    local element

    ---@type LuaGuiElement
    local info_table = inner_frame.add {
        type = "table",
        direction = "vertical",
        column_count = 4,
        name = "title_table"
    }

    inner_frame.tags = {mode = "global"}

    if not (onlytheoric) or solver then
        element = info_table.add {type = "label"}
        element.style.minimal_width = 30

        element = info_table.add {type = "label", caption = {prefix .. ".rate"}}
        element.style.horizontal_align = "center"
        element.style.minimal_width = 3 * value_w
    end

    local summary_table = inner_frame.add {
        type = "table",
        direction = "vertical",
        column_count = 3 + ((solver or not onlytheoric) and 1 or 0),
        name = "summary_table"
    }
    summary_table.vertical_centering = false
    summary_table.draw_horizontal_line_after_headers = true

    -- Headers
    local element = summary_table.add {type = "label"}

    ---@param name string
    ---@param w integer?
    local function add_label(name, w)

        if not w then w = value_w end
        local element = summary_table.add {
            type = "label",
            caption = {prefix .. "." .. name}
        }

        element.style.minimal_width = w
        element.style.horizontal_align = "center"
    end

    add_label("produced_rate")
    add_label("consumed_rate")
    if not (onlytheoric) or solver then add_label("usage", usage_w) end

    local function add_empty_slot(name)
        local flow = summary_table.add {
            type = "flow",
            name = name,
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
        if onlytheoric then
            label.style.horizontal_align = "center"
            label.style.minimal_width = value_w
        else
            label.style.horizontal_align = "left"
            label.style.minimal_width = (value_w - 5) / 2
        end
        return flow
    end

    ---@param p {product:string, label:string}
    local function add_slot(p)

        local label = ""
        local flow = summary_table.add {type = "flow", direction = "horizontal"}

        local button = flow.add {
            type = "sprite-button",
            sprite = p.product,
            name = prefix .. ".product",
            tooltip = p.label,
            style = prefix .. "_button_default"
        }
        button.tags = {product = p.product}
        button.style.left_margin = 10
        flow.add {
            type="sprite",
            sprite=prefix .. "-unlink",
            name = "sprite.unlink",
            visible = (factory.free_products and factory.free_products[p.product]) or false
        }

        add_empty_slot(p.product .. "/produced")
        add_empty_slot(p.product .. "/consumed")
        if not (onlytheoric) or solver then
            local label = summary_table.add {
                type = "label",
                name = p.product .. "/usage"
            }
            label.style.minimal_width = usage_w
            label.style.horizontal_align = "center"
        end
    end

    local function add_to_list(list, product)
        local label, signal  = get_product_name(product)
        local proto
        local order
        if signal.type == "item" then
            proto = game.item_prototypes[signal.name]
        else
            proto = game.fluid_prototypes[signal.name]
        end
        order = proto.group.order .. "  " ..  proto.subgroup.order .. "  " .. proto.order
        table.insert(list, {
            product=product,
            order=order,
            label=label
        })
    end
    
    local produced = {}
    local intermediates = {}
    local consumed = {}

    for name, _ in pairs(factory.theorical_product_map) do
        if not factory.theorical_ingredient_map[name] then 
            add_to_list(produced, name)
        else
            add_to_list(intermediates, name)
        end
    end

    for name, _ in pairs(factory.theorical_ingredient_map) do
        if not factory.theorical_product_map[name] then 
            add_to_list(consumed, name) 
        end
    end

    local function product_compare(p1, p2)
        return p1.order < p2.order
    end

    table.sort(produced, product_compare)
    table.sort(intermediates, product_compare)
    table.sort(consumed, product_compare)

    local function table_inject(list)
        for _,p in pairs(list) do
            add_slot(p)
        end
    end
    
    table_inject(produced)
    table_inject(intermediates)
    table_inject(consumed)
end

---@param frame LuaGuiElement
---@param factory Factory
function Summary.update(frame, factory)
    local summary_table = tools.get_child(frame, "summary_table")
    if not summary_table then return end

    local solver = factory.solver
    local function set_label_rate(field_name, real, theorical)
        local element = summary_table[field_name]
        if not element then return end

        commons.set_element_values(element, real, theorical)
        return element
    end

    local function set_product(name)
        local t_consume, t_produce, t_net, r_consume, r_produce

        t_consume = factory.unit_coef *
                        (factory.theorical_ingredient_map[name] or 0)
        t_produce = factory.unit_coef *
                        (factory.theorical_product_map[name] or 0)

        r_consume = factory.unit_coef * (factory.real_ingredient_map[name] or 0)
        r_produce = factory.unit_coef * (factory.real_product_map[name] or 0)

        set_label_rate(name .. "/consumed", r_consume, t_consume)
        set_label_rate(name .. "/produced", r_produce, t_produce)
        if not (factory.onlytheoric) or solver then

            ---@type LuaGuiElement
            local label = summary_table[name .. "/usage"]
            if label then

                local usage
                if factory.onlytheoric then
                    if factory.usage_map then
                        usage = factory.usage_map[name]
                    end
                elseif t_produce > 0 then
                    usage = r_produce / t_produce
                end
                if usage then
                    label.caption = string.format("%.1f", usage * 100) .. " %"
                    if usage >= 0.98 then
                        label.style.font_color = {1, 1, 0}
                    else
                        label.style.font_color = {1, 1, 1}
                    end
                else
                    label.caption = ""
                end
            end
        end
    end

    for name, _ in pairs(factory.theorical_ingredient_map) do
        set_product(name)
    end

    for name, _ in pairs(factory.theorical_product_map) do
        if not factory.theorical_ingredient_map[name] then
            set_product(name)
        end
    end
end

return Summary
