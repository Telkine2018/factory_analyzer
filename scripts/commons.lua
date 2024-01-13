local tools = require("scripts.tools")

local prefix = "factory_analyzer"
local modpath = "__" .. prefix .. "__"

local commons = {

    prefix = prefix,
    modpath = modpath,
    graphic_path = modpath .. '/graphics/%s.png',
    period_values = {2 * 60, 5 * 60, 10 * 60, 30 * 60, 60 * 60, 0},

    name_w = 150,
    value_w = 120,
    status_w = 120,
    button_with = 28,
    frame_name = prefix .. "-frame",
    shift_button1_event = prefix .. "_shift_button1",
    shift_button2_event = prefix .. "_shift_button2"

}

---@param name string
---@return string
function commons.png(name) return (commons.graphic_path):format(name) end

---@param product string
---@return any
---@return SignalID
function commons.get_product_name(product)
    local signal = tools.sprite_to_signal(product)
    ---@cast signal -nil

    local label = ""
    if signal.type == "item" then
        label = game.item_prototypes[signal.name].localised_name
    elseif signal.type == "fluid" then
        label = game.fluid_prototypes[signal.name].localised_name
    end
    return label, signal
end

function commons.set_element_values(element, real, theorical)
    if not element then return end

    ---@type LuaGuiElement
    local freal = element["real"]
    ---@type LuaGuiElement
    local fsep = element["separator"]
    ---@type LuaGuiElement
    local ftheorical = element["theorical"]

    if real == 0 and theorical == 0 then
        ftheorical.caption = ""
        if freal then
            freal.caption = ""
            fsep.caption = ""
        end
        return
    end

    local stheorical = string.format("%.2f", theorical)
    ftheorical.caption = stheorical

    if not freal then return end
    local sreal = string.format("%.2f", real)
    local ratio = real / theorical
    if ratio == 0 then
        freal.style.font_color = {1, 0, 0, 1}
    elseif ratio > 0.95 then
        freal.style.font_color = {0, 1, 0, 1}
    elseif ratio > 0.5 then
        freal.style.font_color = {1, 1, 1, 1}
    else
        freal.style.font_color = {1, 1, 0, 1}
    end
    freal.caption = sreal
    fsep.caption = "/"
end

---@param machine Machine
---@param product string
---@return number
---@return number
function commons.get_consumed_numbers(machine, product)
    local t_consume_base = machine.ingredients[product]
    if t_consume_base then
        local theorical = t_consume_base * machine.theorical_craft_s
        local real = t_consume_base * machine.craft_per_s /
                         machine.produced_craft_s * machine.theorical_craft_s
        return real, theorical
    else
        return 0, 0
    end
end

---@param machine Machine
---@param product string
---@return number
---@return number
function commons.get_produced_numbers(machine, product)
    local t_product_base = machine.products[product]
    if t_product_base and machine.produced_craft_s then
        local theorical = t_product_base * machine.produced_craft_s
        local real = t_product_base * machine.craft_per_s
        return real, theorical
    else
        return 0, 0
    end
end

---@param player_index integer
---@return Factory
function commons.get_factory(player_index)
    local player = game.players[player_index]
    local vars = tools.get_vars(player)
    return vars.factory --[[@as Factory]]
end

return commons
