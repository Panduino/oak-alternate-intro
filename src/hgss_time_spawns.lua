-- HGSS-style time-of-day wild encounter layer for Gen 1.
--
-- The time-of-day period follows the host/system clock directly and uses the
-- same MORN/DAY/NITE boundaries as the engine's Gen 2 palette system.
--
-- Encounter selection is deliberately a hook over the existing Gen 1 tables:
-- the vanilla encounter-rate roll still decides whether a step produces a
-- battle, while this layer chooses the species for maps that have an HGSS
-- time-of-day table. Maps without a table remain completely vanilla.
--
-- National Dex species are resolved through the National Dex mod's read API.
-- No National Dex data files are copied into this mod.

local M = {}

local PERIODS = { MORN = true, DAY = true, NITE = true }

local TEST_TABLES = {
  ROUTE_1 = {
    grass = {
      MORN = {
        { species = "PIDGEY", weight = 45, level = 3 },
        { species = "RATTATA", weight = 30, level = 3 },
        { species = "SENTRET", weight = 20, level = 3 },
        { species = "FURRET", weight = 5, level = 6 },
      },
      DAY = {
        { species = "PIDGEY", weight = 45, level = 3 },
        { species = "RATTATA", weight = 30, level = 3 },
        { species = "SENTRET", weight = 20, level = 3 },
        { species = "FURRET", weight = 5, level = 6 },
      },
      NITE = {
        { species = "RATTATA", weight = 55, level = 3 },
        { species = "HOOTHOOT", weight = 45, level = 3 },
      },
    },
  },

  ROUTE_2 = {
    grass = {
      MORN = {
        { species = "CATERPIE", weight = 31, level = 4 },
        { species = "PIDGEY", weight = 45, level = 4 },
        { species = "LEDYBA", weight = 24, level = 3 },
      },
      DAY = {
        { species = "CATERPIE", weight = 31, level = 4 },
        { species = "PIDGEY", weight = 45, level = 4 },
        { species = "WEEDLE", weight = 24, level = 4 },
      },
      NITE = {
        { species = "HOOTHOOT", weight = 50, level = 4 },
        { species = "SPINARAK", weight = 30, level = 4 },
        { species = "NOCTOWL", weight = 20, level = 7 },
      },
    },
  },

  ROUTE_25 = {
    grass = {
      MORN = {
        { species = "PIDGEY", weight = 30, level = 8 },
        { species = "BELLSPROUT", weight = 30, level = 10 },
        { species = "VENONAT", weight = 20, level = 10 },
        { species = "ABRA", weight = 10, level = 9 },
        { species = "PIDGEOTTO", weight = 5, level = 10 },
        { species = "WEEPINBELL", weight = 5, level = 14 },
      },
      DAY = {
        { species = "PIDGEY", weight = 50, level = 8 },
        { species = "BELLSPROUT", weight = 30, level = 10 },
        { species = "ABRA", weight = 10, level = 9 },
        { species = "PIDGEOTTO", weight = 5, level = 10 },
        { species = "WEEPINBELL", weight = 5, level = 14 },
      },
      NITE = {
        { species = "ODDISH", weight = 30, level = 10 },
        { species = "VENONAT", weight = 30, level = 8 },
        { species = "VENOMOTH", weight = 20, level = 8 },
        { species = "ABRA", weight = 10, level = 9 },
        { species = "WEEPINBELL", weight = 5, level = 10 },
        { species = "BELLSPROUT", weight = 5, level = 14 },
      },
    },
    water = {
      { species = "GOLDEEN", weight = 60, level = 10 },
      { species = "SEAKING", weight = 10, level = 10 },
      { species = "MAGIKARP", weight = 30, level = 10 },
    },
  },

  ROUTE_21 = {
    grass = {
      MORN = {
        { species = "TANGELA", weight = 90, level = 28 },
        { species = "MR_MIME", weight = 10, level = 28 },
      },
      DAY = {
        { species = "TANGELA", weight = 90, level = 28 },
        { species = "MR_MIME", weight = 10, level = 30 },
      },
      NITE = {
        { species = "TANGELA", weight = 90, level = 28 },
        { species = "MR_MIME", weight = 10, level = 28 },
      },
    },
    water = {
      { species = "TENTACOOL", weight = 60, level = 32 },
      { species = "TENTACRUEL", weight = 40, level = 35 },
    },
  },
}

local function weightedPick(rows, random)
  if type(rows) ~= "table" or #rows == 0 then return nil end

  local total = 0
  for _, row in ipairs(rows) do
    total = total + (tonumber(row.weight) or 0)
  end
  if total <= 0 then return nil end

  local roll = random and random(1, total) or love.math.random(1, total)
  local running = 0
  for _, row in ipairs(rows) do
    running = running + (tonumber(row.weight) or 0)
    if roll <= running then
      return {
        species = row.species,
        level = row.level,
      }
    end
  end
end

local function loadClock()
  local ok, Palettes = pcall(require, "src.world.gen2.Palettes")
  if ok and type(Palettes) == "table" then return Palettes end
  return nil
end

local function currentPeriod(Palettes)
  if not Palettes then return "DAY" end

  -- HGSS-style mode is tied directly to the host/system clock. Do not use
  -- the Gen 2 save-time anchor here: this mod intentionally follows the
  -- computer clock.
  local hour = tonumber(os.date("%H")) or 12
  -- HGSS uses 04:00-09:59 morning, 10:00-19:59 day,
  -- and 20:00-03:59 night.
  if hour >= 4 and hour < 10 then return "MORN" end
  if hour >= 10 and hour < 20 then return "DAY" end
  return "NITE"
end

local function nationalDex(mod)
  local dex = mod.find and mod:find("national_dex")
  if not dex or not dex.exports then return nil end
  if type(dex.exports.statsBySpecies) ~= "function" then return nil end
  return dex.exports
end

local function speciesAvailable(dex, species)
  if not dex then return false end
  local ok, record = pcall(dex.statsBySpecies, species)
  return ok and type(record) == "table"
end

local function filterRows(dex, rows)
  if not dex then return rows or {} end
  local out = {}
  for _, row in ipairs(rows or {}) do
    if speciesAvailable(dex, row.species) then
      out[#out + 1] = row
    end
  end
  return out
end

function M.install(mod)
  local dex = nationalDex(mod)
  if not dex then
    mod.log:warn("HGSS time-of-day spawns could not find National Dex; "
      .. "running encounter tables without availability filtering")
  end

  local Palettes = loadClock()
  if not Palettes then
    mod.log:error("HGSS time-of-day spawns could not load Gen 2 time-of-day palettes")
    return
  end

  -- Keep our own live Game reference. mod.game is not the sanctioned runtime
  -- access path; the engine exposes it through game.ready.
  local game = nil
  local lastPeriod = currentPeriod(Palettes)

  mod.events:on("game.ready", function(ev)
    game = ev.game
  end)

  -- Gen 1 has no native time-of-day. The shared world.tod seam is the
  -- authoritative answer used by the rest of the engine.
  mod.hooks:wrap("world.tod", function(next, tod, ctx)
    local period = currentPeriod(Palettes)
    if period == "MORN" or period == "DAY" or period == "NITE" then
      return period
    end
    return next(tod, ctx)
  end)

  -- The engine's ADVANCED color mode does not use map.palette for the
  -- overworld. It bakes the pokered-gbc 8-group world palette through
  -- PaletteFX.worldGroupColors instead. Wrap that actual renderer seam so
  -- time-of-day changes are visible in ADVANCED as well as the simpler modes.
  local PaletteFX = require("src.render.PaletteFX")
  local originalWorldGroupColors = PaletteFX.worldGroupColors

  local function copyColor(c)
    return { c[1], c[2], c[3] }
  end

  local function tintColor(c, tod)
    if not c then return nil end
    local r, g, b = c[1], c[2], c[3]
    if tod == "NITE" then
      -- Blue/violet night grade, preserving the Advanced palette's local
      -- hue relationships instead of replacing its per-tile colors.
      return {
        math.floor(r * 0.48 + b * 0.10),
        math.floor(g * 0.50 + b * 0.08),
        math.floor(b * 0.82 + r * 0.04),
      }
    elseif tod == "MORN" then
      -- Pale blue morning grade, deliberately brighter than night.
      return {
        math.floor(r * 0.86 + b * 0.10 + 12),
        math.floor(g * 0.88 + b * 0.08 + 12),
        math.floor(b * 0.92 + r * 0.05 + 14),
      }
    end
    return copyColor(c)
  end

  local function tintGroups(groups, tod)
    if not groups then return nil end
    local out = {}
    for i, group in ipairs(groups) do
      local colors = {}
      for j, c in ipairs(group) do
        colors[j] = tintColor(c, tod)
      end
      out[i] = colors
    end
    return out
  end

  PaletteFX.worldGroupColors = function(data, tileset, mapId, playerCellY, lit)
    local groups = originalWorldGroupColors(data, tileset, mapId, playerCellY, lit)
    if not groups then return groups end
    return tintGroups(groups, currentPeriod(Palettes))
  end

  -- Keep the normal SGB/map-palette path working too. Advanced uses the
  -- worldGroupColors wrapper above; the other modes reach this hook.
  local OUTDOOR = {
    PALLET = true, VIRIDIAN = true, PEWTER = true, CERULEAN = true,
    LAVENDER = true, VERMILION = true, CELADON = true, FUCHSIA = true,
    CINNABAR = true, INDIGO = true, SAFFRON = true, ROUTE = true,
  }

  mod.hooks:wrap("map.palette", function(next, name, map, ctx)
    name = next(name, map, ctx)
    if not OUTDOOR[name] then return name end
    local tod = currentPeriod(Palettes)
    if tod == "NITE" then return name end
    return name
  end)

  -- Rewrite the result of the real encounter roll. This is the engine's
  -- guaranteed Gen 1 path: encounter.roll decides whether a battle happens,
  -- then we replace only its species/level. This keeps the ROM encounter rate
  -- while making the actual wild slot come from the time table.
  mod.hooks:wrap("encounter.roll", function(next, encDef, ctx)
    local enc = next(encDef, ctx)
    if not enc or not ctx then return enc end

    local map = TEST_TABLES[ctx.mapId]
    if not map then return enc end

    local terrain = tostring(ctx.terrain or ""):lower()
    local period = currentPeriod(Palettes)
    local rows

    if (terrain == "grass" or terrain == "land" or terrain == "cave")
        and map.grass then
      rows = map.grass[period]
    elseif (terrain == "water" or terrain == "surf")
        and map.water then
      rows = map.water
    end

    if type(rows) ~= "table" or #rows == 0 then return enc end

    -- Do not gate the test table through National Dex. The encounter hook
    -- needs to prove the live engine path first; National Dex is the source
    -- of the eventual full roster, not a reason to silently erase test rows.
    local picked = weightedPick(rows, ctx.rng)
    if not picked then return enc end

    return {
      species = picked.species,
      level = picked.level,
    }
  end)

  -- Fishing is separate from encounter.roll in Gen 1. Replace only the
  -- candidate pool on maps that explicitly define one; all other rods remain
  -- vanilla. The engine performs the final bite/slot roll.
  mod.hooks:wrap("encounter.fishing", function(next, rod, mapId, pool)
    local map = TEST_TABLES[mapId]
    if not map or not map.fishing then
      return next(rod, mapId, pool)
    end

    local period = currentPeriod(Palettes)
    local rows = map.fishing[rod] or map.fishing.all
    if type(rows) == "table" and rows[period] then rows = rows[period] end
    rows = filterRows(dex, rows)

    if #rows == 0 then return next(rod, mapId, pool) end
    return next(rod, mapId, rows)
  end)

  -- The Gen 1 world.tod hook is cached by the overworld. It is not polled
  -- every frame, so a host-clock transition can otherwise sit invisible until
  -- some unrelated palette lookup happens. world.stepped is the cheap live
  -- heartbeat; use it only to detect a period boundary.
  mod.events:on("world.stepped", function()
    local period = currentPeriod(Palettes)
    if period == lastPeriod then return end
    local previous = lastPeriod
    lastPeriod = period
    mod.log:info("HGSS time of day -> %s (from %s)", period, previous)

    -- The Advanced renderer bakes world groups into TileRenderer's atlas.
    -- Flush that atlas and rebuild every live map renderer so the new grade
    -- is actually drawn on the already-open screen.
    local TileRenderer = require("src.render.TileRenderer")
    TileRenderer.invalidate()

    local ow = game and game.overworld
    local function rebuildMap(m)
      if m and m.renderer and type(m.renderer.rebuild) == "function" then
        m.renderer:rebuild()
      end
    end

    if ow then
      rebuildMap(ow.map)

      -- Gen 1 neighbor rows carry map definitions, not live Map objects.
      -- Re-fetch their cached runtime maps so their TileRenderers also drop
      -- the atlas they were holding before the clock transition.
      local MapLoader = require("src.world.MapLoader")
      for _, entry in ipairs(ow.neighbors or {}) do
        local id = entry and entry.map and entry.map.id
        if id then rebuildMap(MapLoader.cached(id)) end
      end
    end

    -- Also update the engine's cached world.tod value immediately. The next
    -- normal palette lookup will see this through the hook, while encounters
    -- already read currentPeriod() directly.
    if ow then ow.tod = period end
  end)

  -- Initialize the live period from the system clock as soon as the game is
  -- live. This also makes a fresh boot render with the correct period rather
  -- than waiting for the first movement.
  mod.events:on("game.ready", function()
    lastPeriod = currentPeriod(Palettes)
  end)

  mod.exports.timeOfDay = function()
    return currentPeriod(Palettes)
  end

  mod.exports.encounterTables = TEST_TABLES
end

return M
