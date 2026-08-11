-- Show a warning to the server owner when they join because this mod modifies actual player privileges to enable and disable privileges based on player metadata privilege tables
if (not core.settings:get("toggle_privs.warning_acknowledged")) then
    core.register_on_joinplayer(function(player) 
        local player_name = player:get_player_name()
        local has_priv,missing_privs = core.check_player_privs(player_name, "server")
        if (has_priv) then
            core.chat_send_player(player_name, "[toggle_privs] Warning: this mod changes actual player privileges. If this mod is disabled, players will be left with whatever privileges they had enabled at the time it was disabled. To use this mod please use /acknowledge_warning and restart the server.")
        end
    end)

    core.register_chatcommand("acknowledge_warning", {
        description = "Acknowledge the toggle_privs warning.",
        privs = {server = true},
        func = function(name)
            core.settings:set("toggle_privs.warning_acknowledged","true")
            return true
        end
    })

else

    local real_registered_privileges_can_revoke = {}

    local old_core_register_privilege = core.register_privilege

    -- Override privileges defined before this mod is loaded
    for name, definition in pairs(core.registered_privileges) do
        local priv_table = {}
        priv_table.give_to_singleplayer=definition.give_to_singleplayer
        priv_table.give_to_admin=definition.give_to_admin
        real_registered_privileges_can_revoke[name]=priv_table
        definition.give_to_singleplayer = false
        definition.give_to_admin = false
    end

    -- Override privileges defined after this mod is loaded
    core.register_privilege = function(name, definition)
        local priv_table = {}
        priv_table.give_to_singleplayer=definition.give_to_singleplayer
        priv_table.give_to_admin=definition.give_to_admin
        real_registered_privileges_can_revoke[name]=priv_table
        new_definition = table.copy(definition)
        new_definition.give_to_singleplayer = false
        new_definition.give_to_admin = false
        old_core_register_privilege(name, new_definition)
    end

    -- Register the command "toggle" that toggles the state of a privilege (enabled or disabled)
    core.register_chatcommand("toggle", {
        description = "Toggles the state of a privilege",
        func = function(name, priv)
            local player = core.get_player_by_name(name)
            if (player) then -- Check to see if the player's online because the mod uses player metadata
                local player_meta = player:get_meta()
                local has_priv,missing_privs = core.check_player_privs(name, priv)
                if (has_priv) then -- The player has the privilege (no need to check the player's metadata; if the player isn't supposed to have the privilege, gladly remove it)
                    local changes = {}
                    changes[priv]=false
                    core.change_player_privs(name, changes)
                    return true, "Disabled "..priv
                elseif (not has_priv and core.string_to_privs(player_meta:get_string("real_privs"))[priv]) then -- The player has the privilege but it is disabled
                    local changes = {}
                    changes[priv]=true
                    core.change_player_privs(name, changes)
                    return true, "Enabled "..priv
                elseif (not core.string_to_privs(player_meta:get_string("real_privs"))[priv]) then -- The player does not have the privilege
                    return false, "You do not have this privilege."
                end
            end
        end
    })

    -- Helper function to parse command arguments
    function parse_params(str)
        local args = {}
        for param in string.gmatch(str, "%S+") do
            table.insert(args, param)
        end
        return args
    end

    -- Override grant and revoke to work with the mod

    core.override_chatcommand("grant", {
        params = "<name> <privilege>",
        func = function(name, param)
            if (not param) then return false end
            local args = parse_params(param)
            local target = args[1]
            local priv = args[2]
            if core.registered_privileges[priv] then
                local player = core.get_player_by_name(target)
                if (player) then
                    local player_meta = player:get_meta()
                    local player_privs = core.string_to_privs(player_meta:get_string("real_privs"))
                    player_privs[priv]=true
                    player_meta:set_string("real_privs", core.privs_to_string(player_privs))
                    local changes = {}
                    changes[priv]=true
                    core.change_player_privs(target, changes)
                    if (core.registered_privileges[priv].on_grant) then core.registered_privileges[priv].on_grant(target, name) end
                    return true
                end
                return false, "Player not online."
            else
                return false, "Unknown privilege: "..priv
            end
        end
    })

    core.override_chatcommand("grantme", {
        params = "<privilege>",
        func = function(name, args)
            if (not args) then return false end
            return core.registered_chatcommands["grant"].func(name,name.." "..args)
        end
    })

    core.override_chatcommand("revoke", {
        params = "<name> <privilege>",
        func = function(name, param)
            if (not param) then return false end
            local args = parse_params(param)
            local target = args[1]
            local priv = args[2]

            if (target=="singleplayer" and real_registered_privileges_can_revoke[priv] and real_registered_privileges_can_revoke[priv].give_to_singleplayer) then
                return false, "Cannot revoke in singleplayer: "..priv
            elseif (target==core.settings:get("name") and real_registered_privileges_can_revoke[priv] and real_registered_privileges_can_revoke[priv].give_to_admin) then
                return false, "Cannot revoke from admin: "..priv
            end

            if core.registered_privileges[priv] then
                local player = core.get_player_by_name(target)
                if (player) then
                    local player_meta = player:get_meta()
                    local player_privs = core.string_to_privs(player_meta:get_string("real_privs"))
                    player_privs[priv]=false
                    player_meta:set_string("real_privs", core.privs_to_string(player_privs))
                    local changes = {}
                    changes[priv]=false
                    core.change_player_privs(target, changes)
                    if (core.registered_privileges[priv].on_revoke) then core.registered_privileges[priv].on_revoke(target, name) end
                    return true
                end
                return false, "Player not online."
            else
                return false, "Unknown privilege: "..priv
            end
        end
    })

    core.override_chatcommand("revokeme", {
        params = "<privilege>",
        func = function(name, args)
            if (not args) then return false end
            return core.registered_chatcommands["revoke"].func(name,name.." "..args)
        end
    })

    core.override_chatcommand("haspriv", {
        func = function(name, param)
            if (not param) then return false end
            local players_with_priv = {}
            for _,player in pairs(core.get_connected_players()) do
                local player_meta = player:get_meta()
                local player_privs = core.string_to_privs(player_meta:get_string("real_privs"))
                if (player_privs[param]) then
                    table.insert(players_with_priv, player:get_player_name())
                end
            end
        
            -- Format the output names
            if (#players_with_priv==0) then
                return true, "No online player has the \""..param.."\" privilege."
            elseif (#players_with_priv==1) then
                return true, "Players online with the \""..param.."\" privilege: "..players_with_priv[1]
            else
                local str = "Players online with the \""..param.."\" privilege: "
                for i in 1,#players_with_priv-1 do
                    str = str..players_with_priv[i]..", "
                end
                str = str..players_with_priv[#players_with_priv]
            end
        end
    })

    core.register_on_joinplayer(function(player)
        local player_meta = player:get_meta()
        if (not (player_meta:get_string("toggle_privs_converted")=="true")) then
            player_meta:set_string("real_privs", core.privs_to_string(core.get_player_privs(player:get_player_name())))
            player_meta:set_string("toggle_privs_converted","true")
        end
    end)
end
