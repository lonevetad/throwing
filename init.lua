arrows = {
	{"throwing:arrow", "throwing:arrow_entity"},
	{"throwing:arrow_fire", "throwing:arrow_fire_entity"},
	{"throwing:arrow_teleport", "throwing:arrow_teleport_entity"},
	{"throwing:arrow_dig", "throwing:arrow_dig_entity"},
	{"throwing:arrow_build", "throwing:arrow_build_entity"},
	{"throwing:arrow_tnt", "throwing:arrow_tnt_entity"},
	{"throwing:arrow_cluster", "throwing:arrow_cluster_entity"},
	{"throwing:arrow_stone", "throwing:arrow_stone_entity"}
}

local throwing_shoot_arrow = function(itemstack, player)
	for _,arrow in ipairs(arrows) do
		if player:get_inventory():get_stack("main", player:get_wield_index()+1):get_name() == arrow[1] then
			if not minetest.setting_getbool("creative_mode") then
				player:get_inventory():remove_item("main", arrow[1])
			end
			local playerpos = player:getpos()
			local obj = minetest.env:add_entity({x=playerpos.x,y=playerpos.y+1.5,z=playerpos.z}, arrow[2])
			local dir = player:get_look_dir()
			obj:setvelocity({x=dir.x*19, y=dir.y*19, z=dir.z*19})
			obj:setacceleration({x=dir.x*-3, y=-10, z=dir.z*-3})
			obj:setyaw(player:get_look_yaw()+math.pi)
			minetest.sound_play("throwing_sound", {pos=playerpos})
			if obj:get_luaentity().player == "" then
				obj:get_luaentity().player = player
			end
			obj:get_luaentity().node = player:get_inventory():get_stack("main", 1):get_name()
			return true
		end
	end
	return false
end


--funzione inventata da me
local throwing_shoot_crossbow_otty = function(itemstack, player)
	local theArrow = arrows[1]
	local found = nil
	local prevItem = player:get_inventory():get_stack("main", player:get_wield_index()+1)

	for _,arrow in ipairs(arrows) do
		if prevItem:get_name() == arrow[1] then
			theArrow = arrow
			found = arrow
			break
		end
	end

	local playerpos = player:getpos()
	local obj = minetest.env:add_entity({x=playerpos.x,y=playerpos.y+1.5,z=playerpos.z}, --[[ arrows[1] ]] theArrow[2])
	local dir = player:get_look_dir()

	-- minetest.env:add_entity({x=playerpos.x,y=playerpos.y+1.5,z=playerpos.z}, "farming:bread")
	
	obj:setvelocity({x=dir.x*19, y=dir.y*19, z=dir.z*19})
	obj:setacceleration({x=dir.x*-3, y=-10, z=dir.z*-3})
	obj:setyaw(player:get_look_yaw()+math.pi)
	--minetest.sound_play("throwing_sound", {pos=playerpos})
	if obj:get_luaentity().player == "" then
		obj:get_luaentity().player = player
	end
	obj:get_luaentity().node = player:get_inventory():get_stack("main", 1):get_name()

	if not minetest.setting_getbool("creative_mode")
		and theArrow[1] ~= arrows[2][1] --throwing:arrow_fire 
		and found ~= nil
		and prevItem:get_count() > 1
		then

			player:get_inventory():remove_item("main", 
				--theArrow[1]
				prevItem:get_name()
				--player:get_wield_index()+1
			)
		end

	return true
end

minetest.register_tool("throwing:bow_wood", {
	description = "Wood Bow",
	inventory_image = "throwing_bow_wood.png",
    stack_max = 1,
	on_use = function(itemstack, user, pointed_thing)
		if throwing_shoot_arrow(itemstack, user, pointed_thing) then
			if not minetest.setting_getbool("creative_mode") then
				itemstack:add_wear(65535/50)
			end
		end
		return itemstack
	end,
})

minetest.register_craft({
	output = 'throwing:bow_wood',
	recipe = {
		{'farming:string', 'default:wood', ''},
		{'farming:string', '', 'default:wood'},
		{'farming:string', 'default:wood', ''},
	}
})

minetest.register_tool("throwing:bow_stone", {
	description = "Stone Bow",
	inventory_image = "throwing_bow_stone.png",
    stack_max = 1,
	on_use = function(itemstack, user, pointed_thing)
		if throwing_shoot_arrow(item, user, pointed_thing) then
			if not minetest.setting_getbool("creative_mode") then
				itemstack:add_wear(65535/100)
			end
		end
		return itemstack
	end,
})

minetest.register_craft({
	output = 'throwing:bow_stone',
	recipe = {
		{'farming:string', 'default:cobble', ''},
		{'farming:string', '', 'default:cobble'},
		{'farming:string', 'default:cobble', ''},
	}
})

minetest.register_tool("throwing:bow_steel", {
	description = "Steel Bow",
	inventory_image = "throwing_bow_steel.png",
    stack_max = 1,
	on_use = function(itemstack, user, pointed_thing)
		if throwing_shoot_arrow(item, user, pointed_thing) then
			if not minetest.setting_getbool("creative_mode") then
				itemstack:add_wear(65535/200)
			end
		end
		return itemstack
	end,
})

minetest.register_craft({
	output = 'throwing:bow_steel',
	recipe = {
		{'farming:string', 'default:steel_ingot', ''},
		{'farming:string', '', 'default:steel_ingot'},
		{'farming:string', 'default:steel_ingot', ''},
	}
})

dofile(minetest.get_modpath("throwing").."/arrow.lua")
dofile(minetest.get_modpath("throwing").."/fire_arrow.lua")
dofile(minetest.get_modpath("throwing").."/teleport_arrow.lua")
dofile(minetest.get_modpath("throwing").."/dig_arrow.lua")
dofile(minetest.get_modpath("throwing").."/build_arrow.lua")
--
dofile(minetest.get_modpath("throwing").."/tnt_arrow.lua")
dofile(minetest.get_modpath("throwing").."/stone_arrow.lua")
dofile(minetest.get_modpath("throwing").."/cluster_arrow.lua")

if minetest.setting_get("log_mods") then
	minetest.log("action", "throwing loaded")
end



-- mio


minetest.register_tool("throwing:crossbow_otty", {
	description = "CrossBow Otty",
	inventory_image = "crossbow_otty.png",
    stack_max = 1,
	on_use = function(itemstack, user, pointed_thing)
		throwing_shoot_crossbow_otty(itemstack, user, pointed_thing)
		return itemstack
	end,
})

minetest.register_craft({
	output = 'throwing:crossbow_otty',
	recipe = {
		{'default:stone', 'default:stick', 'default:stick'},
		{'default:stick', 'default:wood', ''},
		{'default:stick', '', 'default:wood'},
	}
})

