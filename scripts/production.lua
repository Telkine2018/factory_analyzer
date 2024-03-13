local tools = require("scripts.tools")
local commons = require("scripts.commons")

local Production = {}

local production_update_rate = 120

---@param factory Factory
---@param entity LuaEntity
---@return Machine
function Production.add_machine(factory, entity)
    local machine = {
        entity = entity,
        type = entity.type,
        name = entity.name,
        id = entity.unit_number,
        products = {},
        productivity = 1,
        reqenergy = 0,
        ingredients = {},
        recipe_name = ''
    }
    factory.machine_map[entity.unit_number] = machine
    factory.structure_change = true
    return machine
end

local transport_drone_prefix = "transport-drones"

local black_list_subgroups = { ["transport-drones"] = true }

---@param factory Factory
---@param entities LuaEntity[]?
function Production.load_structure(factory, entities)
    local ingredient_map = {}
    local product_map = {}
    local machine_map = factory.machine_map
    local machines = {}

    factory.unit_coef = factory.unit_coef or 1
    factory.unit_label = factory.unit_label or "/s"

    factory.machines = machines
    factory.machine_map = machine_map

    if entities == nil then
        entities = {}
        ---@type Machine[]
        local to_remove = {}
        for _, m in pairs(machine_map) do
            if m.entity.valid then
                table.insert(entities, m.entity)
            else
                table.insert(to_remove, m)
                factory.structure_change = true
            end
        end
        for _, m in pairs(to_remove) do
            machine_map[m.id] = nil
        end
    end

    for _, entity in pairs(entities) do
        if entity.valid and
            not black_list_subgroups[entity.prototype.subgroup.name] then
            ---@type Machine
            local machine = machine_map[entity.unit_number]
            if not machine then
                machine = Production.add_machine(factory, entity)
            end
            table.insert(machines, machine)
            machine.usage = 1

            local previous_recipe = machine.recipe_name
            machine.recipe_name = nil
            if machine.type == "assembling-machine" or machine.type == "furnace" then
                local recipe = entity.get_recipe() or
                    (entity.type == "furnace" and
                        entity.previous_recipe)
                machine.theorical_craft_s = 0
                if recipe then
                    machine.theorical_craft_s =
                        ((120 / recipe.energy) * entity.crafting_speed) / 120
                    machine.recipe_name = recipe.name
                    machine.on_limit60 = machine.theorical_craft_s > 60

                    local productivity_bonus = entity.productivity_bonus
                    machine.productivity = productivity_bonus + 1

                    local limited_craft_s = math.min(60,
                        machine.theorical_craft_s)
                    machine.produced_craft_s =
                        limited_craft_s + productivity_bonus *
                        machine.theorical_craft_s

                    local ingredients = {}
                    machine.ingredients_info = {}
                    for _, ingredient in ipairs(recipe.ingredients) do
                        local amount = ingredient.amount
                        local product_name =
                            ingredient.type .. "/" .. ingredient.name

                        ingredients[product_name] = amount
                        table.insert(machine.ingredients_info, {
                            name = ingredient.name,
                            type = ingredient.type,
                            amount = amount
                        })

                        local old_count = ingredient_map[product_name] or 0
                        ingredient_map[product_name] =
                            old_count + amount * machine.theorical_craft_s
                    end
                    machine.ingredients = ingredients

                    local products = {}
                    machine.product_infos = {}
                    for _, product in ipairs(recipe.products) do
                        local probability = (product.probability or 1)

                        local amount = product.amount or
                            ((product.amount_max +
                                product.amount_min) / 2)

                        local catalyst_amount = product.catalyst_amount or 0
                        local total
                        if catalyst_amount > 0 then
                            total = (amount * limited_craft_s +
                                math.max(0, amount - catalyst_amount) * productivity_bonus * machine.theorical_craft_s
                            ) * probability
                        else
                            total = (amount * limited_craft_s + amount *
                                productivity_bonus * machine.theorical_craft_s) * probability
                        end
                        amount = total / machine.produced_craft_s

                        local product_name = product.type .. "/" .. product.name
                        products[product_name] = amount
                        table.insert(machine.product_infos, {
                            name = product.name,
                            type = product.type,
                            amount = amount
                        })

                        local old_count = product_map[product_name] or 0
                        product_map[product_name] = old_count +
                            machine.produced_craft_s *
                            amount
                    end
                    if #recipe.products <= 1 then
                        machine.first_product_name = nil
                    end
                    machine.products = products
                end
                machine.energy_usage = entity.prototype.energy_usage
                machine.reqenergy = machine.energy_usage *
                    (1 + entity.consumption_bonus)
            elseif machine.type == "mining-drill" then
                local prototype = entity.prototype
                local productivity_bonus = entity.productivity_bonus
                local speed_bonus = entity.speed_bonus

                local position = entity.position
                local radius = prototype.mining_drill_radius + 0.01
                local resource_entities =
                    entity.surface.find_entities_filtered {
                        area = {
                            left_top = {
                                x = position.x - radius,
                                y = position.y - radius
                            },
                            right_bottom = {
                                x = position.x + radius,
                                y = position.y + radius
                            }
                        },
                        type = "resource"
                    }

                local resources = {}
                local num_resource_entities = 0
                machine.theorical_craft_s = 0
                machine.craft_per_s = 0
                machine.product_infos = {}
                machine.ingredients_info = {}
                for i = 1, #resource_entities do
                    local resource = resource_entities[i]
                    local resource_name = resource.name
                    local res = resources[resource_name]

                    if not res then
                        local resource_prototype = resource.prototype
                        local is_minable =
                            prototype.resource_categories[resource_prototype.resource_category]
                        if is_minable then
                            local mineable_properties =
                                resource_prototype.mineable_properties

                            resources[resource_name] = {
                                occurrences = 1,
                                products = mineable_properties.products,
                                mining_time = mineable_properties.mining_time
                            }
                            res = resources[resource_name]
                            num_resource_entities = num_resource_entities + 1
                            if resource_prototype.infinite_resource then
                                res.mining_time = (res.mining_time /
                                    (resource.amount /
                                        resource_prototype.normal_resource_amount))
                                if not machine.recipe_name then
                                    machine.recipe_name = resource_name
                                end
                            end
                        end
                    else
                        res.occurrences = res.occurrences + 1
                        num_resource_entities = num_resource_entities + 1
                    end
                end

                machine.productivity = (productivity_bonus + 1)
                if num_resource_entities > 0 then
                    local drill_multiplier =
                        (prototype.mining_speed * (speed_bonus + 1))

                    for _, resource_data in pairs(resources) do
                        local resource_multiplier =
                            ((drill_multiplier / resource_data.mining_time) *
                                (resource_data.occurrences /
                                    num_resource_entities))

                        for _, product in pairs(resource_data.products) do
                            local product_per_second
                            local amount = product.amount
                            if not amount then
                                amount =
                                    (product.amount_max + product.amount_min) /
                                    2
                            end

                            product_per_second = amount * resource_multiplier
                            local name = product.type .. "/" .. product.name
                            machine.theorical_craft_s = product_per_second
                            machine.products[name] = 1

                            table.insert(machine.product_infos, {
                                name = product.name,
                                type = product.type,
                                amount = amount
                            })

                            local old_count = product_map[name] or 0
                            product_map[name] =
                                old_count + product_per_second *
                                machine.productivity
                        end
                    end
                end

                if (machine.product_infos and #machine.product_infos > 0) then
                    machine.recipe_name =
                        machine.product_infos[1].type .. "/" ..
                        machine.product_infos[1].name
                end

                machine.energy_usage = entity.prototype.energy_usage
                machine.reqenergy = machine.energy_usage *
                    (1 + entity.consumption_bonus)
                machine.produced_craft_s =
                    machine.theorical_craft_s * (machine.productivity or 1)
                machine.first_product_count = 1
            end
            if previous_recipe ~= machine.recipe_name then
                factory.structure_change = true
            end
        else
            factory.structure_change = true
        end
    end

    factory.machines = machines
    factory.theorical_product_map = product_map
    factory.theorical_ingredient_map = ingredient_map
    if factory.solver then Production.solve(factory) end
    return factory
end

---@param factory Factory
function Production.update_production(factory)
    if not factory.machines then return end

    Production.load_structure(factory, nil)
end

---@param factory Factory
---@param new_entities LuaEntity[]
function Production.add_to_selection(factory, new_entities)
    local entities = {}
    local map = {}
    for _, machine in pairs(factory.machines) do
        local entity = machine.entity
        if entity.valid then
            table.insert(entities, entity)
            map[entity.unit_number] = entity
        else
            factory.machine_map[machine.id] = nil
            factory.structure_change = true
        end
    end

    for _, e in pairs(new_entities) do
        if e.valid and not map[e.unit_number] then
            table.insert(entities, e)
            map[e.unit_number] = e
        end
    end

    Production.load_structure(factory, entities)
end

---@param factory Factory
---@param new_entities LuaEntity[]
function Production.replace_selection(factory, new_entities)
    Production.load_structure(factory, new_entities)
end

---@return Factory
function Production.new_factory()
    return {
        machines = {},
        machine_map = {},
        theorical_product_map = {},
        theorical_ingredient_map = {},
        real_ingredient_map = {},
        real_product_map = {},
        tick = nil,
        free_products = {}
    }
end

---@param factory Factory
---@param full boolean?
function Production.compute_production(factory, full)
    local machines = factory.machines
    if not machines then return end

    local previous_tick = factory.tick
    local current_tick = game.tick

    -- already done
    if not factory.last_update or factory.structure_change or
        ((current_tick - factory.last_update) > production_update_rate) then
        Production.load_structure(factory)
        if not factory then return end

        factory.last_update = current_tick
        machines = factory.machines
        factory.tick = previous_tick
    end

    if not factory.last_update then factory.last_update = current_tick end

    local real_product_map, real_ingredient_map
    real_product_map = {}
    real_ingredient_map = {}
    factory.real_product_map = real_product_map
    factory.real_ingredient_map = real_ingredient_map

    local saved = not full or not previous_tick
    for i = #machines, 1, -1 do
        local machine = machines[i]
        ---@type LuaEntity
        local entity = machine.entity

        if not entity.valid then
            table.remove(machines, i)
            factory.structure_change = true
            factory.machine_map[machine.id] = nil
        elseif machine.recipe_name then
            local craft_per_s = 0
            if machine.type == "assembling-machine" or machine.type == "furnace" then
                local products_finished = entity.products_finished
                local crafting_progress = entity.crafting_progress
                local bonus_progress = entity.bonus_progress
                local prev_bonus_progress = machine.bonus_progress or 0
                if previous_tick then
                    if machine.products_finished then
                        craft_per_s = (crafting_progress - machine.crafting_progress + (bonus_progress - prev_bonus_progress) +
                            (products_finished - machine.products_finished))
                        craft_per_s = 60.0 * craft_per_s / (current_tick - previous_tick)
                    end
                end
                local status = entity.status
                machine.missing_product = nil
                machine.full_output_product = nil
                if status == defines.entity_status.item_ingredient_shortage or status == defines.entity_status.no_ingredients then
                    local recipe = entity.get_recipe() or (entity.type == "furnace" and entity.previous_recipe)
                    if recipe then
                        local ingredients = recipe.ingredients
                        local inv = entity.get_inventory(defines.inventory
                            .assembling_machine_input)
                        ---@cast inv -nil
                        local index = 1
                        for _, ingredient in pairs(ingredients) do
                            if ingredient.type == "item" then
                                if inv[index].count < ingredient.amount then
                                    machine.missing_product = "item/" ..
                                        ingredient.name
                                    break
                                end
                                index = index + 1
                            end
                        end
                    end
                elseif status == defines.entity_status.no_input_fluid or status == defines.entity_status.fluid_ingredient_shortage then
                    local recipe = entity.get_recipe() or (entity.type == "furnace" and entity.previous_recipe)
                    if recipe then
                        local ingredients = recipe.ingredients
                        local index = 1
                        local fluidbox = entity.fluidbox
                        for _, ingredient in pairs(ingredients) do
                            if ingredient.type == "fluid" then
                                local fb = fluidbox[index]
                                if not fb or fb.amount < ingredient.amount then
                                    machine.missing_product = "fluid/" ..
                                        ingredient.name
                                    break
                                end
                                index = index + 1
                            end
                        end
                    end
                elseif status == defines.entity_status.full_output then
                    local recipe = entity.get_recipe() or
                        (entity.type == "furnace" and
                            entity.previous_recipe)
                    if recipe then
                        local output_inv = entity.get_output_inventory()
                        ---@cast output_inv -nil
                        local products = recipe.products
                        local fluidbox = nil
                        local fluid_index = 1
                        local item_index = 1
                        for _, product in pairs(products) do
                            if product.type == "item" then
                                local count = output_inv[item_index].count
                                local amount = product.amount
                                if not amount then
                                    amount = (product.amount_min + product.amount_max) / 2
                                end
                                if count > 0 and (count >= 4 * amount or count >= game.item_prototypes[product.name].stack_size) then
                                    machine.full_output_product = "item/" .. product.name
                                    break
                                end
                                item_index = item_index + 1
                            else
                                if not fluidbox then
                                    fluidbox = entity.fluidbox
                                    for _, p in pairs(recipe.ingredients) do
                                        if p.type == "fluid" then
                                            fluid_index = fluid_index + 1
                                        end
                                    end
                                end

                                local fb = fluidbox[fluid_index]
                                if fb and fb.amount > 0 then
                                    machine.full_output_product = "fluid/" .. product.name
                                    break
                                end

                                fluid_index = fluid_index + 1
                            end
                        end
                    end
                end

                if saved then
                    machine.products_finished = products_finished
                    machine.crafting_progress = crafting_progress
                    machine.bonus_progress = bonus_progress
                end
            else -- drill
                local status = entity.status
                local energy = 0
                machine.full_output_product = nil
                if status == defines.entity_status.working or status ==
                    defines.entity_status.low_power then
                    energy = entity.energy
                elseif status ==
                    defines.entity_status.waiting_for_space_in_destination then
                    if machine.products then
                        local product, _ = next(machine.products)
                        machine.full_output_product = product
                    end
                end

                machine.reqenergy = entity.prototype.energy_usage *
                    (1 + entity.consumption_bonus)

                local usage = math.min(machine.reqenergy, energy) /
                    machine.reqenergy
                craft_per_s = machine.theorical_craft_s * machine.productivity *
                    usage
            end
            machine.craft_per_s = craft_per_s
            if machine.products then
                for name, count in pairs(machine.products) do
                    local amount = count * craft_per_s
                    real_product_map[name] =
                        (real_product_map[name] or 0) + amount
                end
            end
            if machine.ingredients then
                local ratio = machine.theorical_craft_s /
                    machine.produced_craft_s
                for name, count in pairs(machine.ingredients) do
                    local amount = count * craft_per_s * ratio
                    real_ingredient_map[name] =
                        (real_ingredient_map[name] or 0) + amount
                end
            end
        end
    end
    if saved then factory.tick = current_tick end
    factory.last_compute = current_tick
end

---@param factory Factory
---@param product string
---@return Machine[]
function Production.select_machines(factory, product)
    local machines = {}
    for _, machine in pairs(factory.machines) do
        if machine.entity.valid then
            machine.order = nil
            if machine.products[product] then
                if not machine.ingredients[product] then
                    machine.order = 1
                else
                    machine.order = 2
                end
            elseif machine.ingredients[product] then
                machine.order = 3
            end
            if machine.order then table.insert(machines, machine) end
        else
            factory.machine_map[machine.id] = nil
            factory.structure_change = true
        end
    end

    ---@param m1 Machine
    ---@param m2 Machine
    ---@return boolean
    local function compare_machine(m1, m2)
        if m1.order ~= m2.order then
            return m1.order < m2.order
        elseif m1.recipe_name ~= m2.recipe_name then
            return m1.recipe_name < m2.recipe_name
        elseif m1.name ~= m2.name then
            return m1.name < m2.name
        else
            local p1, p2 = m1.entity.position, m2.entity.position
            if p1.y ~= p2.y then
                return p1.y < p2.y
            else
                return p1.x < p2.x
            end
        end
    end

    table.sort(machines, compare_machine)
    return machines
end

---@param factory Factory
function Production.solve(factory)
    -- if true then return end
    factory.usage_map = nil

    ---@type table<string, ProductNode>
    local products = {}
    local recipes = {}

    ---@param product_name string
    ---@return ProductNode
    local function get_product(product_name)
        local product = products[product_name]
        if not product then
            product = { name = product_name, equations = {}, recipes = {} }
            products[product_name] = product
        end
        return product
    end

    for _, machine in pairs(factory.machine_map) do
        local recipe_name = machine.recipe_name
        if recipe_name then
            if not recipes[recipe_name] then
                recipes[recipe_name] = { name = recipe_name }
            end
            for ingredient_name, count in pairs(machine.ingredients) do
                local product = get_product(ingredient_name)
                product.equations[recipe_name] =
                    (product.equations[recipe_name] or 0) -
                    machine.theorical_craft_s * count
                product.input = true
            end
            for product_name, count in pairs(machine.products) do
                local product = get_product(product_name)
                product.equations[recipe_name] =
                    (product.equations[recipe_name] or 0) +
                    machine.produced_craft_s * count
                product.output = true
                product.recipes[recipe_name] = true
            end
        end
    end

    ---@type table<string, number>[]
    local equations = {}

    for _, product in pairs(products) do
        if product.output then
            if product.input then
                if table_size(product.equations) > 1 and
                    not factory.free_products[product.name] then
                    table.insert(equations, product.equations)
                end
            end
        end
    end

    local function trim(v) return math.abs(v) > 0.0001 and v or nil end

    local iter = 1
    local max_iter = settings.global[commons.prefix .. "-solver_iteration"].value
    while (true) do
        local eq_var_names = {}
        local name_map = {}
        for i = 1, #equations do
            ---@type table<string, number>
            local pivot_eq = equations[i]

            -- find pivot
            local pivot_var, pivot_value, rank_min
            for var_name, value in pairs(pivot_eq) do
                if value ~= 0 and not name_map[var_name] then
                    if not pivot_value then
                        pivot_var = var_name
                        pivot_value = value
                    elseif math.abs(value) > math.abs(pivot_value) then
                        pivot_var = var_name
                        pivot_value = value
                    end
                end
            end
            if not pivot_value then goto next_eq end

            eq_var_names[i] = pivot_var
            name_map[pivot_var] = true
            for n, v in pairs(pivot_eq) do
                pivot_eq[n] = v / pivot_value
            end

            for j = i + 1, #equations do
                local eq_line = equations[j]
                local line_pivot = eq_line[pivot_var]
                if line_pivot then
                    for n, v in pairs(pivot_eq) do
                        eq_line[n] = trim((eq_line[n] or 0) - line_pivot * v)
                    end
                end
            end

            ::next_eq::
        end

        local new_equations = {}
        local new_var_names = {}
        for i = 1, #equations do
            local eq = equations[i]
            if table_size(eq) > 1 then
                table.insert(new_equations, eq)
                table.insert(new_var_names, eq_var_names[i])
            end
        end
        equations = new_equations
        eq_var_names = new_var_names

        local var_values = {}
        local need_pass2 = false
        for i = #equations, 1, -1 do
            local eq = equations[i]

            local var = eq_var_names[i]
            local value = 0
            for n, v in pairs(eq) do
                if n ~= var then
                    local var_value = var_values[n]
                    if var_value then
                        value = value - var_value * v
                    end
                end
            end
            for n, v in pairs(eq) do
                if n ~= var then
                    local var_value = var_values[n]
                    if not var_value then
                        if v > 0 then
                            local limit = value / v
                            if limit > 1 then
                                var_value = 1
                            else
                                var_value = limit
                            end
                        else
                            var_value = 1
                        end
                        var_values[n] = var_value
                        value = value - var_value * v
                    end
                end
            end
            if value < 0 and value > -0.00001 then
                value = 0
            end
            var_values[var] = value
            if value > 1 then
                local to_change = { [var] = true }
                local need_process = true

                while need_process do
                    need_process = false
                    for j = i, #equations do
                        for name, _ in pairs(equations[j]) do
                            if not to_change[name] then
                                to_change[name] = true
                                need_process = true
                            end
                        end
                    end
                end
                for name, _ in pairs(to_change) do
                    var_values[name] = var_values[name] / value
                end
            elseif value < 0 then
                need_pass2 = true
                for k = i, #equations - 1 do
                    equations[k] = equations[k + 1]
                    eq_var_names[k] = eq_var_names[k + 1]
                end
                equations[#equations] = eq
                eq_var_names[#equations] = var
                break
            end
        end

        factory.var_values = var_values
        iter = iter + 1
        if not need_pass2 or iter > max_iter then
            local ingredient_map = {}
            local product_map = {}

            for _, machine in pairs(factory.machine_map) do
                local recipe_name = machine.recipe_name
                if recipe_name then
                    local usage = var_values[recipe_name]
                    if usage then machine.usage = usage end
                    for ingredient, count in pairs(machine.ingredients) do
                        ingredient_map[ingredient] = (ingredient_map[ingredient] or 0) + count * machine.theorical_craft_s * machine.usage
                    end
                    for product, count in pairs(machine.products) do
                        product_map[product] = (product_map[product] or 0) + count * machine.produced_craft_s * machine.usage
                    end
                end
            end

            local usage_map = {}
            for n, count in pairs(product_map) do
                local full_count = factory.theorical_product_map[n]
                if full_count and full_count > 0 then
                    usage_map[n] = count / full_count
                end
            end

            factory.theorical_ingredient_map = ingredient_map
            factory.theorical_product_map = product_map
            factory.usage_map = usage_map
            factory.solver_failure = need_pass2
            return
        end
    end
end

return Production
