-- another silly copy of tnt_arrow because of i'm not able to use function written in other lua files

numCircles = 4
sinSixty=  math.sin(math.pi/3.0)
numArrowsPerCircle = {1, 4, 6, 8}
--angley={ math.sin(math.pi/2), math.sin(math.rad(75)), math.sin(math.pi/3), math.sin(math.pi/4) }
cluster_directions_factor={
	{ {} --[[{x=0,y=1,z=0}]] },
	{ {} --[[{x=1,y=sinSixty,z=0}, {x=0,y=sinSixty,z=1}, {x=-1,y=sinSixty,z=0}, {x=0,y=sinSixty,z=-1} ]]},
	{ {} --[[{x=1,y=0.5,z=0}, {x=sinSixty,y=0.5,z=0.5}, {x=sinSixty,y=0.5,z=-0.5}, {x=-1,y=0.5,z=0}
		, {x=-sinSixty,y=0.5,z=0.5}, {x=-sinSixty,y=0.5,z=-0.5} ]] },
	{ {} }
}

cc =0, ii, nn, angr
ii=1
while(ii <= numCircles) do


	nn= numArrowsPerCircle[ii]
	if(nn==nil) then minetest.log("DIO PORCO nn null") end

	angr= math.sin( (math.pi/2) - (ii*math.pi/12) ) -- 15° per circle--angley[ii]

	cc=0
	while( cc< nn ) do
		cluster_directions_factor[ii][cc+1] = { x= math.sin( cc*2*math.pi/nn) , y= angr, z = math.cos( cc*2*math.pi/nn) }
		cc=cc+1
	end
	ii=ii+1
end
-- ____________________________TNT______________________________-

-- Default to enabled when in singleplayer
local enable_tnt = minetest.setting_getbool("enable_tnt")
if enable_tnt == nil then
	enable_tnt = minetest.is_singleplayer()
end

-- loss probabilities array (one in X will be lost)
local loss_prob = {}

loss_prob["default:cobble"] = 3
loss_prob["default:dirt"] = 4

local tnt_radius = tonumber(minetest.setting_get("tnt_radius") or 3)

-- Fill a list with data for content IDs, after all nodes are registered
local cid_data = {}
minetest.after(0, function()
	for name, def in pairs(minetest.registered_nodes) do
		cid_data[minetest.get_content_id(name)] = {
			name = name,
			drops = def.drops,
			flammable = def.groups.flammable,
			on_blast = def.on_blast,
		}
	end
end)

local function rand_pos(center, pos, radius)
	local def
	local reg_nodes = minetest.registered_nodes
	local i = 0
	repeat
		-- Give up and use the center if this takes too long
		if i > 4 then
			pos.x, pos.z = center.x, center.z
		else
			pos.x = center.x + math.random(-radius, radius)
			pos.z = center.z + math.random(-radius, radius)
			def = reg_nodes[minetest.get_node(pos).name]
			i = i + 1
		end
	until def and not def.walkable and i < 5
end

local function eject_drops(drops, pos, radius)
	local drop_pos = vector.new(pos)
	for _, item in pairs(drops) do
		local count = math.min(item:get_count(), item:get_stack_max())
		while count > 0 do
			local take = math.max(1,math.min(radius * radius,
					count,
					item:get_stack_max()))
			rand_pos(pos, drop_pos, radius)
			local dropitem = ItemStack(item)
			dropitem:set_count(take)
			local obj = minetest.add_item(drop_pos, dropitem)
			if obj then
				obj:get_luaentity().collect = true
				obj:setacceleration({x = 0, y = -10, z = 0})
				obj:setvelocity({x = math.random(-3, 3),
						y = math.random(0, 10),
						z = math.random(-3, 3)})
			end
			count = count - take
		end
	end
end

local function add_drop(drops, item)
	item = ItemStack(item)
	local name = item:get_name()
	if loss_prob[name] ~= nil and math.random(1, loss_prob[name]) == 1 then
		return
	end

	local drop = drops[name]
	if drop == nil then
		drops[name] = item
	else
		drop:set_count(drop:get_count() + item:get_count())
	end
end

local function destroy(drops, npos, cid, c_air, c_fire, on_blast_queue, ignore_protection, ignore_on_blast)
	--minetest.log("arrow_ destroying-first line")
	if not ignore_protection and minetest.is_protected(npos, "") then
		return cid
	end

	local def = cid_data[cid]
	--minetest.log("arrow_ destroying")
		
	if not def then
		return c_air
	elseif not ignore_on_blast and def.on_blast then
	--	minetest.log("....tnt_arrow : destroying parte strana")
		on_blast_queue[#on_blast_queue + 1] = {pos = vector.new(npos), on_blast = def.on_blast}
		return cid
	elseif def.flammable then
		return c_fire
	else
		local node_drops = minetest.get_node_drops(def.name, "")
		--minetest.log("....tnt_arrow : destroying parte normale, finalmente")
		for _, item in pairs(node_drops) do
			add_drop(drops, item)
		end
		return c_air
	end
end


-- [[
local function calc_velocity(pos1, pos2, old_vel, power)
	-- Avoid errors caused by a vector of zero length
	if vector.equals(pos1, pos2) then
		return old_vel
	end

	local vel = vector.direction(pos1, pos2)
	vel = vector.normalize(vel)
	vel = vector.multiply(vel, power)

	-- Divide by distance
	local dist = vector.distance(pos1, pos2)
	dist = math.max(dist, 1)
	vel = vector.divide(vel, dist)

	-- Add old velocity
	vel = vector.add(vel, old_vel)

	-- randomize it a bit
	vel = vector.add(vel, {
		x = math.random() - 0.5,
		y = math.random() - 0.5,
		z = math.random() - 0.5,
	})

	-- Limit to terminal velocity
	dist = vector.length(vel)
	if dist > 250 then
		vel = vector.divide(vel, dist / 250)
	end
	return vel
end

local function entity_physics(pos, radius, drops)
	local objs = minetest.get_objects_inside_radius(pos, radius)
	for _, obj in pairs(objs) do
		local obj_pos = obj:getpos()
		local dist = math.max(1, vector.distance(pos, obj_pos))

		local damage = (4 / dist) * radius
		if obj:is_player() then
			-- currently the engine has no method to set
			-- player velocity. See #2960
			-- instead, we knock the player back 1.0 node, and slightly upwards
			local dir = vector.normalize(vector.subtract(obj_pos, pos))
			local moveoff = vector.multiply(dir, dist + 1.0)
			local newpos = vector.add(pos, moveoff)
			newpos = vector.add(newpos, {x = 0, y = 0.2, z = 0})
			obj:setpos(newpos)

			obj:set_hp(obj:get_hp() - damage)
		else
			local do_damage = true
			local do_knockback = true
			local entity_drops = {}
			local luaobj = obj:get_luaentity()
			local objdef = minetest.registered_entities[luaobj.name]

			if objdef and objdef.on_blast then
				do_damage, do_knockback, entity_drops = objdef.on_blast(luaobj, damage)
			end

			if do_knockback then
				local obj_vel = obj:getvelocity()
				obj:setvelocity(calc_velocity(pos, obj_pos,
						obj_vel, radius * 10))
			end
			if do_damage then
				if not obj:get_armor_groups().immortal then
					obj:punch(obj, 1.0, {
						full_punch_interval = 1.0,
						damage_groups = {fleshy = damage},
					}, nil)
				end
			end
			for _, item in pairs(entity_drops) do
				add_drop(drops, item)
			end
		end
	end
end

local function add_effects(pos, radius, drops)
	minetest.add_particle({
		pos = pos,
		velocity = vector.new(),
		acceleration = vector.new(),
		expirationtime = 0.4,
		size = radius * 10,
		collisiondetection = false,
		vertical = false,
		texture = "tnt_boom.png",
	})
	minetest.add_particlespawner({
		amount = 64,
		time = 0.5,
		minpos = vector.subtract(pos, radius / 2),
		maxpos = vector.add(pos, radius / 2),
		minvel = {x = -10, y = -10, z = -10},
		maxvel = {x = 10, y = 10, z = 10},
		minacc = vector.new(),
		maxacc = vector.new(),
		minexptime = 1,
		maxexptime = 2.5,
		minsize = radius * 3,
		maxsize = radius * 5,
		texture = "tnt_smoke.png",
	})

	-- we just dropped some items. Look at the items entities and pick
	-- one of them to use as texture
	local texture = "tnt_blast.png" --fallback texture
	local most = 0
	for name, stack in pairs(drops) do
		local count = stack:get_count()
		if count > most then
			most = count
			local def = minetest.registered_nodes[name]
			if def and def.tiles and def.tiles[1] then
				texture = def.tiles[1]
			end
		end
	end

	minetest.add_particlespawner({
		amount = 64,
		time = 0.1,
		minpos = vector.subtract(pos, radius / 2),
		maxpos = vector.add(pos, radius / 2),
		minvel = {x = -3, y = 0, z = -3},
		maxvel = {x = 3, y = 5,  z = 3},
		minacc = {x = 0, y = -10, z = 0},
		maxacc = {x = 0, y = -10, z = 0},
		minexptime = 0.8,
		maxexptime = 2.0,
		minsize = radius * 0.66,
		maxsize = radius * 2,
		texture = texture,
		collisiondetection = true,
	})
end


function burn(pos, nodename)
	local name = nodename or minetest.get_node(pos).name
	local group = minetest.get_item_group(name, "tnt")
	if group > 0 then
		minetest.sound_play("tnt_ignite", {pos = pos})
		minetest.set_node(pos, {name = name .. "_burning"})
		minetest.get_node_timer(pos):start(1)
	elseif name == "tnt:gunpowder" then
		minetest.set_node(pos, {name = "tnt:gunpowder_burning"})
	end
end
-- ]]

local function tnt_explode(pos, radius, ignore_protection, ignore_on_blast)
	pos = vector.round(pos)
	-- scan for adjacent TNT nodes first, and enlarge the explosion
	local vm1 = VoxelManip()
	local p1 = vector.subtract(pos, 2)
	local p2 = vector.add(pos, 2)
	local minp, maxp = vm1:read_from_map(p1, p2)
	local a = VoxelArea:new({MinEdge = minp, MaxEdge = maxp})
	local data = vm1:get_data()
	local count = 1
	local c_tnt = minetest.get_content_id("tnt:tnt")
	local c_tnt_burning = minetest.get_content_id("tnt:tnt_burning")
	local c_tnt_boom = minetest.get_content_id("tnt:boom")
	local c_air = minetest.get_content_id("air")

	--minetest.log("tnt_arrow : explode 2")

	for z = pos.z - 2, pos.z + 2 do
	for y = pos.y - 2, pos.y + 2 do
		local vi = a:index(pos.x - 2, y, z)
		for x = pos.x - 2, pos.x + 2 do
			local cid = data[vi]
			if cid == c_tnt or cid == c_tnt_boom or cid == c_tnt_burning then
				--local poss = vector.new(x,y,z)
				count = count + 1
				--
				--burn(poss, minetest.get_node(poss):get_name() )
				--
				data[vi] = c_air
			end
			vi = vi + 1
		end
	end
	end

	vm1:set_data(data)
	vm1:write_to_map()

	-- recalculate new radius
	radius = math.floor(radius * math.pow(count, 1/3))

	-- perform the explosion
	local vm = VoxelManip()
	local pr = PseudoRandom(os.time())
	p1 = vector.subtract(pos, radius)
	p2 = vector.add(pos, radius)
	minp, maxp = vm:read_from_map(p1, p2)
	a = VoxelArea:new({MinEdge = minp, MaxEdge = maxp})
	data = vm:get_data()

	local drops = {}
	local on_blast_queue = {}

	local c_fire = minetest.get_content_id("fire:basic_flame")
	for z = -radius, radius do
		for y = -radius, radius do
			local vi = a:index(pos.x + (-radius), pos.y + y, pos.z + z)
			for x = -radius, radius do
				local r = vector.length(vector.new(x, y, z))
				if (radius * radius) / (r * r) >= (pr:next(80, 125) / 100) then
					local cid = data[vi]
					local p = {x = pos.x + x, y = pos.y + y, z = pos.z + z}
					if cid ~= c_air then
						data[vi] = destroy(drops, p, cid, c_air, c_fire,
							on_blast_queue, ignore_protection,
							ignore_on_blast)
					end
				end
				vi = vi + 1
			end
		end
	end

	vm:set_data(data)
	vm:write_to_map()
	vm:update_map()
	vm:update_liquids()

	-- call nodeupdate for everything within 1.5x blast radius
	for y = -radius * 1.5, radius * 1.5 do
	for z = -radius * 1.5, radius * 1.5 do
	for x = -radius * 1.5, radius * 1.5 do
		local rad = {x = x, y = y, z = z}
		local s = vector.add(pos, rad)
		local r = vector.length(rad)
		if r / radius < 1.4 then
			nodeupdate_single(s)
		end
	end
	end
	end

	for _, queued_data in pairs(on_blast_queue) do
		local dist = math.max(1, vector.distance(queued_data.pos, pos))
		local intensity = (radius * radius) / (dist * dist)
		local node_drops = queued_data.on_blast(queued_data.pos, intensity)
		if node_drops then
			for _, item in pairs(node_drops) do
				add_drop(drops, item)
			end
		end
	end

	return drops, radius
end


function boom(pos, def)
	minetest.sound_play("tnt_explode", {pos = pos, gain = 1.5, max_hear_distance = 2*64})
	minetest.set_node(pos, {name = "tnt:boom"})
	local drops, radius = tnt_explode(pos, def.radius, def.ignore_protection,
			def.ignore_on_blast)
	-- append entity drops
	local damage_radius = (radius / def.radius) * def.damage_radius
	entity_physics(pos, damage_radius, drops)
	if not def.disable_drops then
		eject_drops(drops, pos, radius)
	end
	add_effects(pos, radius, drops)
end


-- DAT FUCKING ARROW


minetest.register_craftitem("throwing:arrow_cluster", {
	description = "Cluster Bomb Arrow",
	inventory_image = "throwing_arrow_cluster.png",
})

minetest.register_node("throwing:arrow_cluster_box", {
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			-- Shaft
			{-6.5/17, -1.5/17, -1.5/17, 6.5/17, 1.5/17, 1.5/17},
			--Spitze
			{-4.5/17, 2.5/17, 2.5/17, -3.5/17, -2.5/17, -2.5/17},
			{-8.5/17, 0.5/17, 0.5/17, -6.5/17, -0.5/17, -0.5/17},
			--Federn
			{6.5/17, 1.5/17, 1.5/17, 7.5/17, 2.5/17, 2.5/17},
			{7.5/17, -2.5/17, 2.5/17, 6.5/17, -1.5/17, 1.5/17},
			{7.5/17, 2.5/17, -2.5/17, 6.5/17, 1.5/17, -1.5/17},
			{6.5/17, -1.5/17, -1.5/17, 7.5/17, -2.5/17, -2.5/17},
			
			{7.5/17, 2.5/17, 2.5/17, 8.5/17, 3.5/17, 3.5/17},
			{8.5/17, -3.5/17, 3.5/17, 7.5/17, -2.5/17, 2.5/17},
			{8.5/17, 3.5/17, -3.5/17, 7.5/17, 2.5/17, -2.5/17},
			{7.5/17, -2.5/17, -2.5/17, 8.5/17, -3.5/17, -3.5/17},
		}
	},
	tiles = {"throwing_arrow_cluster.png", "throwing_arrow_cluster.png", "throwing_arrow_tnt_back.png", "throwing_arrow_cluster_front.png", "throwing_arrow_cluster_2.png", "throwing_arrow_cluster.png"},
	groups = {not_in_creative_inventory=1},
})

function tos(a)
	if a == nil then return "null" else return a end
end

local THROWING_ARROW_ENTITY={
	physical = false,
	timer=0,
	visual = "wielditem",
	visual_size = {x=0.1, y=0.1},
	textures = {"throwing:arrow_cluster_box"},
	lastpos={},
	collisionbox = {0,0,0,0,0,0},
}

THROWING_ARROW_ENTITY.on_step = function(self, dtime)
	self.timer=self.timer+dtime
	local pos = self.object:getpos()
	local node = minetest.env:get_node(pos)

	if self.timer>0.2 then
		local objs = minetest.env:get_objects_inside_radius({x=pos.x,y=pos.y,z=pos.z}, 2)
		for k, obj in pairs(objs) do
			if obj:get_luaentity() ~= nil then
				if obj:get_luaentity().name ~= "throwing:arrow_cluster_entity" and obj:get_luaentity().name ~= "__builtin:item" then
					local damage = 5
					obj:punch(self.object, 1.0, {
						full_punch_interval=1.0,
						damage_groups={fleshy=damage},
					}, nil)
					self.object:remove()
				end
			else
				local damage = 5
				obj:punch(self.object, 1.0, {
					full_punch_interval=1.0,
					damage_groups={fleshy=damage},
				}, nil)
				self.object:remove()
			end
		end
	end

	if self.lastpos.x~=nil then
		if node.name ~= "air" and node.name ~= "throwing:light" then
			
			-- DO EXPLOSION !
			tnt_explode(pos, 4, nil, nil)

			local playerpos =  self.object:getpos() --player:getpos()

			local objj = nil
			local c, k, numCicles;
			local arrayDelta
			local delta

			c=0
			while( c < numCircles) do

				numCicles = numArrowsPerCircle[c+1]
				k=0

				arrayDelta = cluster_directions_factor[c+1]

				while( k < numCicles) do

					delta= arrayDelta[k+1]

					objj= minetest.env:add_entity(
						{x=playerpos.x,y=playerpos.y+1.5,z=playerpos.z}, 
						"throwing:arrow_tnt_entity")

					local dir = playerpos 

					objj:setvelocity( {x=delta.x*numCicles, y=delta.y*numCicles, z=delta.z*numCicles } )
					
					objj:setacceleration({x=delta.x*-3, y=-10, z=delta.z*-3})
					objj:setyaw( (k*2*math.pi)/ numCicles)
					
					--minetest.sound_play("throwing_sound", {pos=playerpos})
					if objj:get_luaentity().player == "" then
					--	objj:get_luaentity().player = self.object
					end
					--objj:get_luaentity().node = player:get_inventory():get_stack("main", 1):get_name()
					--]]

					k=k+1
				end
				c = c+1
			end
			--
		--pos, radius, ignore_protection, ignore_on_blast)
			self.object:remove()

		end
		if math.floor(self.lastpos.x+0.5) ~= math.floor(pos.x+0.5)
				or math.floor(self.lastpos.y+0.5) ~= math.floor(pos.y+0.5)
				or math.floor(self.lastpos.z+0.5) ~= math.floor(pos.z+0.5) then
			if minetest.env:get_node(self.lastpos).name == "throwing:light" then
				minetest.env:remove_node(self.lastpos)
			end
			if minetest.env:get_node(pos).name == "air" then
				minetest.env:set_node(pos, {name="throwing:light"})
			end
		end
	end
	self.lastpos={x=pos.x, y=pos.y, z=pos.z}
end

minetest.register_entity("throwing:arrow_cluster_entity", THROWING_ARROW_ENTITY)



minetest.register_craft({
	output = 'throwing:arrow_cluster',
	--type = "shapeless",
	recipe = {
		{'', 'tnt:boom', 'tnt:boom'},
		{'throwing:arrow_tnt', 'default:stick', 'tnt:boom'},
		{'', 'tnt:boom', 'tnt:boom'}
	},
})

minetest.register_craft({
	output = 'throwing:arrow_cluster',
	--type = "shapeless",
	recipe = {
			{'', 'throwing:arrow_tnt', 'throwing:arrow_tnt'},
		{'throwing:arrow_tnt', 'default:stick', 'throwing:arrow_tnt'},
		{'', 'throwing:arrow_tnt', 'throwing:arrow_tnt'}
	},
})