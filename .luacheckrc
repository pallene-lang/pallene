-- vim: set filetype=lua : --

-- Luacheck configuration file
-- See https://luacheck.readthedocs.io/en/stable/config.html

ignore = {
    "212/_.*", -- Unused argument, (unless name starts with "_")
    "542", -- An empty if branch.
}


