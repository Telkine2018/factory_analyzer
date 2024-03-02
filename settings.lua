

local commons = require("scripts.commons")

local prefix = commons.prefix

data:extend(
    {
		{
			type = "int-setting",
			name = prefix .. "-solver_iteration",
			setting_type = "runtime-global",
			default_value = 10,
			minimum_value = 3,
			maximum_value = 30,
			order = "aa"
		}
})
