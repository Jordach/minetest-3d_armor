local time = 0
local update_time = tonumber(minetest.setting_get("3d_armor_update_time"))
if not update_time then
	update_time = 1
	minetest.setting_set("3d_armor_update_time", tostring(update_time))
end

armor = {
	player_hp = {},
}

armor.set_player_armor = function(self, player)
	if not player then
		return
	end
	local name = player:get_player_name()
	local player_inv = player:get_inventory()
	local armor_level = 0
	local armor_texture = uniskins.default_texture
	local shield_texture = uniskins.default_texture
	local textures = {}
	for _,v in ipairs({"head", "torso", "legs"}) do
		local stack = player_inv:get_stack("armor_"..v, 1)
		local level = stack:get_definition().groups["armor_"..v]
		if level then
			local item = stack:get_name()
			table.insert(textures, item:gsub("%:", "_")..".png")
			armor_level = armor_level + level
		end			
	end
	if table.getn(textures) > 0 then
		armor_texture = table.concat(textures, "^")
	end
	local stack = player_inv:get_stack("armor_shield", 1)
	local level = stack:get_definition().groups["armor_shield"]
	if level then
		local item = stack:get_name()
		shield_texture = minetest.registered_items[item].inventory_image
		armor_level = armor_level + level
	end
	local armor_groups = {fleshy=100}
	if armor_level > 0 then
		armor_groups.level = math.floor(armor_level / 20)
		armor_groups.fleshy = 100 - armor_level
	end
	player:set_armor_groups(armor_groups)
	uniskins.armor[name] = armor_texture
	uniskins.shield[name] = shield_texture
	uniskins:update_player_visuals(player)
end

armor.update_armor = function(self, player)
	if not player then
		return
	end
	local name = player:get_player_name()
	local hp = player:get_hp()
	if hp == nil or hp == 0 or hp == self.player_hp[name] then
		return
	end
	if self.player_hp[name] > hp then
		local player_inv = player:get_inventory()
		local armor_inv = minetest.get_inventory({type="detached", name=name.."_outfit"})
		if armor_inv == nil then
			return
		end
		local heal_max = 0
		for _,v in ipairs({"head", "torso", "legs", "shield"}) do
			local stack = armor_inv:get_stack("armor_"..v, 1)
			if stack:get_count() > 0 then
				local use = stack:get_definition().groups["armor_use"] or 0
				local heal = stack:get_definition().groups["armor_heal"] or 0
				local item = stack:get_name()
				stack:add_wear(use)
				armor_inv:set_stack("armor_"..v, 1, stack)
				player_inv:set_stack("armor_"..v, 1, stack)
				if stack:get_count() == 0 then
					local desc = minetest.registered_items[item].description
					if desc then
						minetest.chat_send_player(name, "Your "..desc.." got destroyed!")
					end				
					self:set_player_armor(player)
				end
				heal_max = heal_max + heal
			end
		end
		if heal_max > math.random(100) then
			player:set_hp(self.player_hp[name])
			return
		end		
	end
	self.player_hp[name] = hp
end

-- Register Callbacks

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local name = player:get_player_name()
	if fields.outfit then
		inventory_plus.set_inventory_formspec(player, "size[8,7.5]"
		.."button[0,0;2,0.5;main;Back]"
		.."list[current_player;main;0,3.5;8,4;]"
		.."list[detached:"..name.."_outfit;armor_head;3,0;1,1;]"
		.."list[detached:"..name.."_outfit;armor_torso;3,1;1,1;]"
		.."list[detached:"..name.."_outfit;armor_legs;3,2;1,1;]"
		.."list[detached:"..name.."_outfit;armor_shield;4,1;1,1;]")
		return
	end
	for field, _ in pairs(fields) do
		if string.sub(field,0,string.len("skins_set_")) == "skins_set_" then
			minetest.after(0, function(player)
				uniskins.skin[name] = skins.skins[name]..".png"
				uniskins:update_player_visuals(player)
			end, player)
		end
	end
end)

minetest.register_on_joinplayer(function(player)
	inventory_plus.register_button(player,"outfit", "Outfit")
	local player_inv = player:get_inventory()
	local name = player:get_player_name()
	local armor_inv = minetest.create_detached_inventory(name.."_outfit",{
		on_put = function(inv, listname, index, stack, player)
			player:get_inventory():set_stack(listname, index, stack)
			armor:set_player_armor(player)
		end,
		on_take = function(inv, listname, index, stack, player)
			player:get_inventory():set_stack(listname, index, nil)
			armor:set_player_armor(player)
		end,
		allow_put = function(inv, listname, index, stack, player)
			if inv:is_empty(listname) then
				return 1
			end
			return 0
		end,
		allow_take = function(inv, listname, index, stack, player)
			return stack:get_count()
		end,
		allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
			return 0
		end,
	})
	for _,v in ipairs({"head", "torso", "legs", "shield"}) do
		local list = "armor_"..v
		player_inv:set_size(list, 1)
		armor_inv:set_size(list, 1)
		armor_inv:set_stack(list, 1, player_inv:get_stack(list, 1))
	end
	armor.player_hp[name] = 0
	minetest.after(0, function(player)
		armor:set_player_armor(player)
	end, player)	
end)

minetest.register_globalstep(function(dtime)
	time = time + dtime
	if time > update_time then
		for _,player in ipairs(minetest.get_connected_players()) do
			armor:update_armor(player)
		end
		time = 0
	end
end)

