return function(mod)
  if mod.generation ~= 3 then return end

  local modern = mod:find("modern_spawns")
  if not modern or type(modern.exports) ~= "table" then
    mod.log:error("Modern Spawns exports are unavailable")
    return
  end

  local api = modern.exports
  if type(api.isActive) ~= "function"
      or type(api.tableFor) ~= "function"
      or type(api.drawFor) ~= "function"
      or type(api.profileOf) ~= "function" then
    mod.log:error("Modern Spawns API is missing the table/profile functions")
    return
  end

  local okEnc, Encounters = pcall(require, "src.core.game3.encounters")
  local okPokemon, Pokemon = pcall(require, "src.core.game3.pokemon")
  if not okEnc or type(Encounters) ~= "table"
      or not okPokemon or type(Pokemon) ~= "table"
      or type(Pokemon.speciesFromNational) ~= "function" then
    mod.log:error("Gen 3 encounter/species APIs are unavailable")
    return
  end

  local original = Encounters._untamedModernSpawnsOriginal
    or Encounters.tableFor
  Encounters._untamedModernSpawnsOriginal = original

  local function engineSpecies(id)
    if type(id) == "number" then return id end

    local profile = api.profileOf(id)
    local national = profile and tonumber(profile.dex)
    if not national then national = tonumber(id) end
    if not national then return nil end

    return Pokemon.speciesFromNational(national)
  end

  local function convertArea(area)
    if type(area) ~= "table" or type(area.slots) ~= "table" then
      return area
    end

    local out = {}
    for k, v in pairs(area) do out[k] = v end
    out.slots = {}

    for i, slot in ipairs(area.slots) do
      if type(slot) ~= "table" then return nil end

      local species = engineSpecies(slot.species)
      if not species then return nil end

      local copy = {}
      for k, v in pairs(slot) do copy[k] = v end
      copy.species = species
      out.slots[i] = copy
    end

    return out
  end

  local function modernArea(mapId, terrain)
    local mode = type(api.spawnMode) == "function" and api.spawnMode() or nil
    local area

    if mode == "random" then
      area = api.drawFor(mapId, terrain)
    else
      area = api.tableFor(mapId, terrain)
    end

    return convertArea(area)
  end

  Encounters.tableFor = function(mapId)
    local vanilla = original(mapId)
    if type(vanilla) ~= "table" then vanilla = {} end

    local active = false
    local okActive, value = pcall(api.isActive)
    if okActive then active = value == true end
    if not active then return vanilla end

    local out = {}
    for k, v in pairs(vanilla) do out[k] = v end

    local okLand, land = pcall(modernArea, mapId, "grass")
    if okLand and land then out.land = land end

    local okWater, water = pcall(modernArea, mapId, "water")
    if okWater and water then out.water = water end

    return out
  end

  mod.log:info("Untamed Advanced will use Modern Spawns encounter tables")
end
