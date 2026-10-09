-- Emerald quick start: bypass the moving truck / family introduction,
-- but retain the original Route 101 Birch rescue and starter scripts.
return function(mod)
  local Game3 = require("src.core.Game3")
  if Game3._alternateOakEmeraldQuickStart then return end
  Game3._alternateOakEmeraldQuickStart = true

  local nativeEnterField = Game3._enterField
  local Map = require("src.core.game3.map")
  local nativeMapLoad = Map.load
  local pendingTruckExit = false
  local Flags = require("src.core.game3.scripting.flags")
  local EM = Flags.forVersion("emerald")

  local function putVar(session, name, value)
    local id = assert(EM.VAR_IDS[name], "Emerald missing var " .. name)
    session.vars = session.vars or {}
    session.vars[tostring(id)] = value
  end

  local function putFlag(session, name)
    local id = assert(EM.IDS[name], "Emerald missing flag " .. name)
    session.flags = session.flags or {}
    session.flags[tostring(id)] = true
  end

  local function prepare(session)
    -- Keep the native moving-truck start and its exit warp.
    -- Only the story state is advanced; the player exits normally.

    -- Intro 7 = Mom's TV broadcast finished / told to meet the rival.
    -- Town 1 = met the rival; the next event is the Birch rescue.
    -- Rival 3 = met upstairs; the Route 103 rival remains available.
    -- Neither the Birch rescue nor starter selection is marked complete.
    putVar(session, "VAR_LITTLEROOT_INTRO_STATE", 7)
    putVar(session, "VAR_LITTLEROOT_TOWN_STATE", 1)
    putVar(session, "VAR_LITTLEROOT_RIVAL_STATE", 3)
    putVar(session, "VAR_LITTLEROOT_HOUSES_STATE_BRENDAN", 2)
    putVar(session, "VAR_LITTLEROOT_HOUSES_STATE_MAY", 2)
    putFlag(session, "FLAG_MET_RIVAL_MOM")
    putFlag(session, "FLAG_SYS_TV_HOME")
    putFlag(session, "FLAG_HIDE_LITTLEROOT_TOWN_MOM_OUTSIDE")
    putFlag(session, "FLAG_HIDE_LITTLEROOT_TOWN_BRENDANS_HOUSE_TRUCK")
    putFlag(session, "FLAG_HIDE_LITTLEROOT_TOWN_MAYS_HOUSE_TRUCK")

    -- Equivalent to confirming the wall clock in the normal intro.
    -- Use the game's own RTC initialization rather than inventing a time.
    local Rtc = require("src.core.game3.rtc")
    -- Zero offset means Emerald's local time tracks the host system clock.
    -- This is initialized once on new game, not reset on every load.
    session.localTimeOffset = Rtc.newTime(0, 0, 0, 0)
    local TimeEvents = require("src.core.game3.time_events")
    local store = { flags = session.flags, vars = session.vars }
    TimeEvents.init(session, { store = store })
    session.flags, session.vars = store.flags, store.vars
  end

  Game3._enterField = function(self, session, reason, opts)
    if session and session.version == "emerald"
        and reason == "new_game"
        and session.map == "EM_INSIDE_OF_TRUCK" then
      -- The truck's exit coord event requires its vanilla intro state.
      -- Advance the story only when the truck actually warps to town.
      pendingTruckExit = true
    end
    -- Keep the normal truck field callback and moving-truck sequence.
    return nativeEnterField(self, session, reason, opts)
  end

  Map.load = function(modArg, game, mapId, opts)
    if pendingTruckExit and mapId == "EM_LITTLEROOT_TOWN" then
      local Runtime = require("src.core.game3.runtime")
      local session = Runtime.getSession()
      if session and session.version == "emerald" then
        prepare(session)
        pendingTruckExit = false
      end
    end
    return nativeMapLoad(modArg, game, mapId, opts)
  end
end
