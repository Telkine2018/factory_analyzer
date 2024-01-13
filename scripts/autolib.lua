local tools = require("scripts.tools")
local commons = require("scripts.commons")
local Production = require("scripts.production")

local debug = tools.debug
local prefix = commons.prefix

local Autolib = {}


---@param e EventData.on_gui_click
local function on_shift_button1(e)
	local player = game.players[e.player_index]
    local entity = player.selected
    if not entity then return end
    
    local vars = tools.get_vars(player)
    if entity.type == "furnace" then
        if not entity.get_recipe() then
            local inv = entity.get_inventory(defines.inventory.furnace_source)
            if not inv then return end

            ---@type table<string, string>
            local furnace_ingredients = vars.furnace_ingredients
            if not furnace_ingredients then
                return
            end
            local ingredient = furnace_ingredients[entity.name]
            if not ingredient then return end
            inv.insert { name = ingredient, count = 1 }
        end
    end
end

---@param e EventData.on_gui_click
local function on_shift_button2(e)
	local player = game.players[e.player_index]

    local entity = player.selected
    if not entity then return end

    local vars = tools.get_vars(player)
    if entity.type == "furnace" then
        local recipe = entity.get_recipe() or entity.previous_recipe
        if recipe then
            local ingredients = recipe.ingredients
            if #ingredients >= 1 then
                local ingredient = ingredients[1]
                if ingredient.type == "item" then
                    ---@type table<string, string>
                    local furnace_ingredients = vars.furnace_ingredients
                    if not furnace_ingredients then
                        furnace_ingredients      = {}
                        vars.furnace_ingredients = furnace_ingredients
                    end
                    furnace_ingredients[entity.name] = ingredient.name
                end
            end
        end
    end
end

script.on_event(commons.shift_button1_event, on_shift_button1)
script.on_event(commons.shift_button2_event, on_shift_button2)

return Autolib
