-- Standalone HGSS-style time-of-day mod for Gen 1 Recomp.
--
-- This mod has no alternate-intro functionality and registers no commands
-- from any other project.

return function(mod)
  local source = mod:read("src/hgss_time_spawns.lua")
  if not source then
    mod.log:error("hgss_time_spawns.lua is missing")
    return
  end

  local chunk, err = load(source, "@" .. mod.path .. "/src/hgss_time_spawns.lua")
  if not chunk then
    mod.log:error("hgss_time_spawns.lua failed to compile: %s", tostring(err))
    return
  end

  local ok, layer = pcall(chunk)
  if not ok then
    mod.log:error("hgss_time_spawns.lua failed to load: %s", tostring(layer))
    return
  end

  if type(layer) ~= "table" or type(layer.install) ~= "function" then
    mod.log:error("hgss_time_spawns.lua did not return an installable layer")
    return
  end

  layer.install(mod)
end
