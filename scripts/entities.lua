local tools = require("scripts.tools")
local commons = require("scripts.commons")

local debug = tools.debug
local prefix = commons.prefix

Entities = {}


local craft_per_time_format = "%.2f"

local function apply_format(value)
    local format
    if value < 2 then 
        format =  "%.2f"
    elseif value < 100 then
        format = "%.1f"
    else
        format = "%.0f"
    end
    return string.format(format, value)
end

---@param factory Factory
function Entities.update(factory)

    for _, machine in pairs(factory.machine_map) do
        local entity = machine.entity
        if entity.valid and machine.produced_craft_s then

            local text
            if factory.itempers then
                local craft_s
                local products
                local theorical_craft_s
                local coef

                if machine.product_infos and #machine.product_infos > 0 then
                    products = machine.product_infos
                    theorical_craft_s = machine.produced_craft_s
                    coef = 1
                elseif machine.ingredients_info and #machine.ingredients_info >
                    0 then
                    products = machine.ingredients_info
                    theorical_craft_s = machine.theorical_craft_s
                    coef = machine.theorical_craft_s / machine.produced_craft_s
                end

                if products then
                    if factory.onlytheoric then
                        if factory.solver then
                            craft_s = machine.usage * theorical_craft_s
                        else
                            craft_s = theorical_craft_s
                        end
                    else
                        craft_s = machine.craft_per_s * coef
                    end
                    if craft_s then
                        if #products > 1 then
                            text = {""}
                            local start = true
                            for index, product in pairs(products) do
                                if not start then   
                                    table.insert(text, " ")
                                else
                                    start = false
                                end
                                local value = craft_s * product.amount * factory.unit_coef
                                table.insert(text, apply_format(value))
                            end
                            table.insert(text, factory.unit_label)
                        else
                            text = apply_format(craft_s * products[1].amount * factory.unit_coef) .. factory.unit_label
                        end
                    end
                end
            else
                local usage
                if factory.onlytheoric then
                    if factory.solver then
                        usage = machine.usage
                        text = string.format("%.1f", usage * 100) .. " %"
                    end
                else
                    usage = machine.craft_per_s / machine.produced_craft_s
                    if factory.solver and machine.usage > 0 then
                        usage = usage / machine.usage
                    end
                    text = string.format("%.1f", usage * 100) .. " %"
                end
            end

            if text then
                if not machine.text_id then
                    local proto = entity.prototype
                    machine.text_id = rendering.draw_text {
                        text = text,
                        surface = entity.surface,
                        target = entity,
                        target_offset = {
                            proto.tile_width / 2, -proto.tile_height / 2
                        },
                        color = {0, 1, 0},
                        alignment = "right",
                        vertical_alignment = "top",
                        only_in_alt_mode = true,
                        use_rich_text = true
                    }
                else
                    rendering.set_text(machine.text_id, text)
                end
            elseif machine.text_id then
                rendering.destroy(machine.text_id)
                machine.text_id = nil
            end
        end
    end
end

---@param factory Factory
function Entities.clear(factory)

    for _, machine in pairs(factory.machine_map) do
        if machine.entity.valid then
            if machine.text_id then
                rendering.destroy(machine.text_id)
                machine.text_id = nil
            end
        end
    end
end

return Entities
