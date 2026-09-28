-- HGSS-style time-of-day wild encounter layer for Gen 1.
--
-- The clock is the engine's Gen 2 Clock.lua, so this does not create a second
-- RTC implementation. Gen 1 reads the host clock directly through that same
-- clock and uses its MORN/DAY/NITE periods.
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
  local ok, Clock = pcall(require, "src.core.gen2.Clock")
  if ok and type(Clock) == "table" then return Clock end
  return nil
end

local function currentPeriod(game, Clock)
  if not Clock or not game then return "DAY" end
  local ok, hour = pcall(Clock.hour, game.save)
  if not ok or type(hour) ~= "number" then return "DAY" end

  -- Clock.daytimeLabel uses the engine's Palettes.clockDaytime boundaries.
  local Palettes = require("src.world.gen2.Palettes")
  local okTod, tod = pcall(Palettes.clockDaytime, hour)
  if okTod and PERIODS[tod] then return tod end
  return "DAY"
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
    mod.log:warn("HGSS time-of-day spawns require the National Dex mod's "
      .. "read API; no encounter tables were changed")
    return
  end

  local Clock = loadClock()
  if not Clock then
    mod.log:error("HGSS time-of-day spawns could not load Gen 2 Clock.lua")
    return
  end

  -- Gen 1 has no native time-of-day. The shared world.tod seam is the
  -- authoritative answer used by the rest of the engine.
  mod.hooks:wrap("world.tod", function(next, tod, ctx)
    local game = mod.game
    if not game and ctx then game = ctx.game end
    local period = currentPeriod(game, Clock)
    if period == "MORN" or period == "DAY" or period == "NITE" then
      return period
    end
    return next(tod, ctx)
  end)

  mod.hooks:wrap("encounter.roll", function(next, encDef, ctx)
    local base = next(encDef, ctx)
    if not base or not ctx then return base end

    local map = TEST_TABLES[ctx.mapId]
    if not map then return base end

    local period = currentPeriod(mod.game, Clock)

    if ctx.terrain == "grass" and map.grass then
      local rows = map.grass[period]
      local picked = weightedPick(filterRows(dex, rows), ctx.rng)
      if picked then return picked end
    elseif ctx.terrain == "water" and map.water then
      local picked = weightedPick(filterRows(dex, map.water), ctx.rng)
      if picked then return picked end
    end

    return base
  end)

  -- Fishing is separate from encounter.roll in Gen 1. Replace only the
  -- candidate pool on maps that explicitly define one; all other rods remain
  -- vanilla. The engine performs the final bite/slot roll.
  mod.hooks:wrap("encounter.fishing", function(next, rod, mapId, pool)
    local map = TEST_TABLES[mapId]
    if not map or not map.fishing then
      return next(rod, mapId, pool)
    end

    local period = currentPeriod(mod.game, Clock)
    local rows = map.fishing[rod] or map.fishing.all
    if type(rows) == "table" and rows[period] then rows = rows[period] end
    rows = filterRows(dex, rows)

    if #rows == 0 then return next(rod, mapId, pool) end
    return next(rod, mapId, rows)
  end)

  mod.exports.timeOfDay = function()
    return currentPeriod(mod.game, Clock)
  end

  mod.exports.encounterTables = TEST_TABLES
end

return M
