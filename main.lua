-- Alternate Oak intro:
-- choose Bulbasaur, Charmander or Squirtle during Oak's opening speech,
-- immediately receive it (with the normal gift/Pokédex bookkeeping),
-- choose a nickname, name the rival, then receive the Pokédex explanation.
--
-- No starter artwork is bundled here. The preview uses OakSpeech's normal
-- Pokémon sprite resolver, which follows the imported game data and the same
-- sprite override path used by compatible mods.

return function(mod)

  -- HGSS-style system-clock time of day and dynamic wild encounters.
  do
    local source = mod:read("src/hgss_time_spawns.lua")
    if source then
      local chunk, err = load(source, "@" .. mod.path .. "/src/hgss_time_spawns.lua")
      if chunk then
        local ok, layer = pcall(chunk)
        if ok and type(layer) == "table" and type(layer.install) == "function" then
          local installed, installErr = pcall(layer.install, mod)
          if not installed then
            mod.log:error("hgss_time_spawns.lua install failed: %s", tostring(installErr))
          end
        elseif not ok then
          mod.log:error("hgss_time_spawns.lua failed to load: %s", tostring(layer))
        end
      else
        mod.log:error("hgss_time_spawns.lua failed to compile: %s", tostring(err))
      end
    else
      mod.log:error("hgss_time_spawns.lua is missing")
    end
  end

  -- The stock OakSpeech choice uses the generic Menu widget. The widget
  -- does not have a per-item preview API, so this mod adds a narrowly scoped
  -- preview to the three-starter menu only. The sprite itself is resolved
  -- through OakSpeech.resolvePic -> pokemon.Sprites.path, so pokemon.sprite