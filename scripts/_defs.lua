
local tools = require("scripts.tools")

---@class Machine
---@field entity LuaEntity
---@field type string
---@field name string
---@field id integer   @ unit_number
---@field ingredients table<string, number>     @ ingredients from recipe
---@field products table<string, number>        @ products from recipe
---@field productivity number                   @ full productivity
---@field energy_usage number                   @ base energy (from proto)
---@field reqenergy number                  
---@field theorical_craft_s number              @ craft / s (theorical) without productivity
---@field produced_craft_s number               @ craft / s (theorical) include productivity
---@field recipe_name string
---@field on_limit60 boolean
---@field products_finished number
---@field crafting_progress number
---@field bonus_progress number
---@field craft_per_s number                    @ craft / s (real)
---@field order integer
---@field missing_product string                @ missing product 
---@field previous_missing_product string       @ previous missing product 
---@field full_output_product string            @ full output product 
---@field previous_full_output_product string   @ full output product 
---@field usage number
---@field text_id LuaRenderObject
---@field product_infos ProductInfo[]
---@field ingredients_info ProductInfo[]
---@field first_product_name string?
---@field first_product_count integer?

---@class ProductInfo
---@field name string
---@field type string
---@field amount number
---@field temperature number

---@class Factory
---@field machines Machine[]
---@field machine_map table<integer, Machine>
---@field theorical_product_map table<string, number>
---@field theorical_ingredient_map table<string, number>
---@field real_product_map table<string, number>
---@field real_ingredient_map table<string, number>
---@field last_update number    @ Date of last update of machine analyzis
---@field tick number           @ Last tick of real production computation / period <> 0
---@field last_compute number   @ Last tick of real production computation
---@field structure_change boolean  @ structure has changed
---@field solver_failure boolean
---@field free_products table<string, boolean>
---@field usage_map table<string, number>
---@field solver boolean        @ Use solver
---@field onlytheoric boolean   @ Display theoric values
---@field itempers boolean      @ Display i/s on map
---@field unit_coef number      @ Unit coef
---@field unit_label string     @ Unit label
---@field var_values table<string, number>
---@field prev_var_values table<string, number>

---@class ProductNode
---@field name string                           @ Product name
---@field equations  table<string, number>
---@field input boolean
---@field output boolean
---@field recipes table<string,boolean>         @ recipes that productes the product


---@class Recipe
---@field name string
---@field usage number                          @ [0..1] usage percent of recipe
---@field transfert table<string, number>       @ table of product  (<0 ingredient, >0 production)

---@class ProductionConfig
---@field machine_name string
---@field machine_modules string[]
---@field beacon_name string?
---@field beacon_modules string[]?
---@field beacon_count integer?

---@class RemoteRecipe : ProductionConfig
---@field name string

---@class RemoteConfig
---@field recipes {[string]:RemoteRecipe}
