local storage = core.get_mod_storage()
session_disabled_privs = {}

if storage:contains("players_disabled_privs") then 
	session_disabled_privs = core.parse_json(storage:get_string("players_disabled_privs"))
end

local dump_state = function()
	storage:set_string("players_disabled_privs", core.write_json(session_disabled_privs))
end

core.register_on_mods_loaded(function()
	local old_core_get_player_privs = core.get_player_privs
	-- Override the core function
	function core.get_player_privs(name)
		if session_disabled_privs[name] == nil then
			session_disabled_privs[name] = {}
		end
		local enabled_privs = {}
		for k,v in pairs(old_core_get_player_privs(name)) do
			enabled_privs[k] = v
		end
		for k,v in pairs(session_disabled_privs[name]) do
			enabled_privs[k] = nil
		end
		return enabled_privs
	end

	minetest.get_player_privs = core.get_player_privs

	local disable_priv = function(name, param)
		if old_core_get_player_privs(name)[param] then
			if session_disabled_privs[name] == nil then
				session_disabled_privs[name] = {}
			end
			if session_disabled_privs[name][param] then
				core.chat_send_player(name, "Privilege already disabled")
			else
				session_disabled_privs[name][param] = true
				core.chat_send_player(name, "Disabled "..param)
				dump_state()
			end
		else
			core.chat_send_player(name, "You do not have this priv")
		end
	end

	local enable_priv = function(name, param)
		if old_core_get_player_privs(name)[param] then
			if type(session_disabled_privs[name]) == "table" then
				if session_disabled_privs[name][param] then
					session_disabled_privs[name][param] = nil
					core.chat_send_player(name, "Enabled "..param)
					dump_state()
				else
					core.chat_send_player(name, "Privilege already enabled")
				end
			end
		else
			core.chat_send_player(name, "You do not have this priv")
		end
	end

	core.register_chatcommand("disable", {
		params = "<privilege>",
		func = disable_priv
	})

	core.register_chatcommand("enable", {
		params = "<privilege>",
		func = enable_priv
	})

	core.register_chatcommand("toggle", {
		params = "<privilege>",
		func = function(name, param)
			if session_disabled_privs[name][param] then
				enable_priv(name, param)
			else
				disable_priv(name, param)
			end
		end
	})
end)
