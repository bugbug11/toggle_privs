# Ideas
- Instead of overriding `core.get_player_privs`, have the mod override the `/grant` and `/revoke` commands to store granted privileges in a separate table and have the mod toggle actual privs, to account for builtin functionality, like the `interact` priv allowing players to interact with blocks. Currently, disabling `interact` still allows players to interact with blocks because the engine is reading the actual granted privileges instead of using the function `core.get_player_privs`.
- add commands /sticky_grant and /sticky_revoke to prevent mods from modifying specific privileges of a player
- At this point rename the mod to something else like advanced_privileges because it's gonna get so complicated
