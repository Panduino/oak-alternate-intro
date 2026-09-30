return function(mod)
  local Scene = require("src.ui.game3.new_game_scene")
  local Naming = require("src.ui.game3.naming")
  local Pokemon = require("src.core.game3.pokemon")
  local Party = require("src.core.game3.party")
  local FrlgFont = require("src.ui.game3.frlg_font")
  local Audio = require("src.core.game3.audio")
  local Flags = require("src.core.game3.scripting.flags")
  local Space = require("src.core.game3.scripting.space")
  local Trainers = require("src.core.game3.scripting.trainers")
  local BattleBridge = require("src.core.game3.battle_bridge")
  local SE = require("src.core.game3.se_ids")
  local Message = require("src.ui.game3.message")
  local Objects = require("src.core.game3.objects")
  local Field = require("src.core.game3.field")
  local Bag = require("src.core.game3.bag")
  local Collision = require("src.core.game3.collision")
  local Player = require("src.core.game3.player")
  local Map = require("src.core.game3.map")

  if Scene._alternateOakIntroGen3Installed then return end
  Scene._alternateOakIntroGen3Installed = true

  local STARTERS = {
    { species = 1, index = 0, name = "BULBASAUR" },
    { species = 4, index = 1, name = "CHARMANDER" },
    { species = 7, index = 2, name = "SQUIRTLE" },
  }

  local STARTER_BY_SPECIES = {}
  for _, row in ipairs(STARTERS) do
    STARTER_BY_SPECIES[row.species] = row
  end

  local RIVAL_TRAINERS = {
    [1] = 328,
    [4] = 326,
    [7] = 327,
  }

  local RIVAL_MOVES = {
    [1] = { 33, 45 },
    [4] = { 10, 45 },
    [7] = { 33, 43 },
  }

  local liveGame
  local momEventRunning = false
  local encounterRunning = false

  local function starterRow(scene)
    return STARTER_BY_SPECIES[tonumber(scene._alternateStarterSpecies)]
  end

  local function playerName(game)
    local save = game and game.save
    local player = save and save.player
    return (player and player.name) or (save and save.playerName) or (save and save.name) or "RED"
  end

  local function rivalName(game)
    local save = game and game.save
    return save and (save.rivalName or (save.player and save.player.rivalName)) or "BLUE"
  end

  local function starterImage(scene)
    local row = starterRow(scene)
    if not row then return nil end
    local ok, entry = pcall(Pokemon.frontPic, row.species, nil, false, 0)
    if ok and entry then return entry end
    return nil
  end

  local function clearMessage()
    if Message.isOpen() then Message.close() end
  end

  local function showText(scene, text, opts)
    opts = opts or {}
    opts.speed = opts.speed == nil and scene.textSpeed or opts.speed
    opts.ctx = opts.ctx or {
      playerName = scene.playerName,
      rivalName = scene.rivalName,
    }
    Message.show(text, opts)
  end

  local function showStarterMenu(scene)
    scene.win.menu = {
      kind = "starter",
      left = 12,
      top = 4,
      width = 16,
      height = 8,
      items = {
        { "BULBASAUR", 8, 1 },
        { "CHARMANDER", 8, 17 },
        { "SQUIRTLE", 8, 33 },
      },
      cursorX = 0,
      cursorY = 1,
      pitch = 16,
      cursor = 0,
      wrap = false,
    }
    scene._alternateStarterMenu = true
  end

  local originalDrawBg0Text = Scene.drawBg0Text
  Scene.drawBg0Text = function(self)
    originalDrawBg0Text(self)
    if not self._alternateStarterMenu then return end

    local row = starterRow(self)
    local entry = starterImage(self)
    if not (row and entry and entry.image) then return end

    local img = entry.image
    local iw = entry.w or img:getWidth()
    local ih = entry.h or img:getHeight()
    local scale = math.min(80 / iw, 80 / ih)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, 48, 68, 0, scale, scale, iw / 2, ih / 2)
    FrlgFont.draw(row.name, 8, 118, {
      colors = FrlgFont.COLOR.WHITE,
      maxWidth = 80,
    })
  end

  --------------------------------------------------------------------------
  -- Oak speech
  --
  -- The native FireRed name sequence is left alone. The only native task
  -- seam we replace is FadeOutBGM, which is assigned dynamically by the
  -- native LetsGo task. This avoids changing an already-created task's
  -- function reference.
  --------------------------------------------------------------------------

  local originalOakSpeechFadeOutBGM = Scene.Task_OakSpeech_FadeOutBGM

  mod.events:on("intro.oak_speech.step", function(ev)
    local speech = ev and ev.speech
    local step = ev and ev.step
    if speech and step and step.id == "lets_go" and not speech._alternateStarterPending then
      speech._alternateStarterPending = true
      speech:clearDialog()
    end
  end)

  Scene.Task_OakSpeech_FadeOutBGM = function(self, t)
    if self._alternateStarterPending and not self._alternateStarterStarted then
      self._alternateStarterPending = false
      self._alternateStarterStarted = true
      clearMessage()
      t.data.timer = 0
      t.func = Scene.Task_AlternateOakStarterIntro
      return
    end
    return originalOakSpeechFadeOutBGM(self, t)
  end

  function Scene.Task_AlternateOakStarterIntro(self, t)
    if self:fadeActive() then return end

    self._alternateStarterSpecies = self._alternateStarterSpecies or STARTERS[1].species
    showText(self,
      "Before you leave.\f" ..
      "You should have a POKéMON of your own!\f" ..
      "I have three wonderful POKéMON here for you.\f" ..
      "Which one would you like?"
    )
    t.func = Scene.Task_AlternateOakStarterInput
  end

  function Scene.Task_AlternateOakStarterInput(self, t)
    if Message.isOpen() then return end

    if not self._alternateStarterMenu then
      showStarterMenu(self)
      return
    end

    local result = self:menuInput(false)
    if type(result) ~= "number" or result < 0 or result > 2 then return end

    local row = STARTERS[result + 1]
    self._alternateStarterSpecies = row.species
    mod.save:set("firered_starter", row.species)
    self:_answered("starter", row.species, "starter")

    Audio.playSe(SE.SE_SELECT)
    pcall(Audio.playCry, row.species, 0)

    self.win.menu = nil
    self._alternateStarterMenu = false
    clearMessage()

    showText(self,
      ("A %s will be a great partner for you!\f" ..
      "Would you like to give it a nickname?"):format(row.name)
    )
    t.func = Scene.Task_AlternateOakStarterNaming
  end

  function Scene.Task_AlternateOakStarterNaming(self, t)
    if Message.isOpen() then return end

    local row = starterRow(self)
    if not row then
      t.func = Scene.Task_AlternateOakPokedex
      return
    end

    clearMessage()
    self._alternateStarterNamingTask = t
    self._alternateStarterNaming = true

    local Pal = require("src.core.game3.pal_fade")
    self.naming = { stage = "setup", timer = 8, pal = Pal.new() }
    self.naming.pal:blend(Pal.ALL, 16, Pal.BLACK)

    local scene = self
    Naming.open({
      title = Naming.monTitle(row.name),
      maxLen = 10,
      initialText = row.name,
      template = "NICKNAME",
      species = row.species,
      hold = true,
      onDone = function(name)
        scene._alternateStarterNickname = name and name ~= "" and name or row.name
        scene.naming.stage = "fade_out"
        scene.naming.pal:beginFade(Pal.ALL, 0, 0, 16, Pal.BLACK)
      end,
    })
  end

  local originalNamingFrame = Scene.namingFrame
  Scene.namingFrame = function(self)
    if not self._alternateStarterNaming then
      return originalNamingFrame(self)
    end

    local n = self.naming
    local Pal = require("src.core.game3.pal_fade")

    if n.stage == "setup" then
      n.timer = n.timer - 1
      if n.timer <= 0 then
        n.stage = "fade_in"
        n.pal:beginFade(Pal.ALL, 0, 16, 0, Pal.BLACK)
      end
    elseif n.stage == "fade_in" then
      n.pal:updateFade()
      if not n.pal:fadeActive() then n.stage = "input" end
    elseif n.stage == "input" then
      Naming.handleInput(self.inputProxy)
      Naming.update(1 / Scene.GBA_HZ)
    elseif n.stage == "fade_out" then
      n.pal:updateFade()
      if not n.pal:fadeActive() then
        Naming.dismiss()
        self.naming = nil
        self._alternateStarterNaming = false

        local task = self._alternateStarterNamingTask
        self._alternateStarterNamingTask = nil
        if task then
          task.data.timer = 20
          task.func = Scene.Task_AlternateOakStarterAfterNaming
        end
      end
    end
  end

  function Scene.Task_AlternateOakStarterAfterNaming(self, t)
    if t.data.timer and t.data.timer > 0 then
      t.data.timer = t.data.timer - 1
      return
    end

    local row = starterRow(self)
    if row then
      mod.save:set("firered_starter_nickname", self._alternateStarterNickname or row.name)
    end

    clearMessage()

    self:clearTrainerPic()
    self:loadTrainerPic("oak")
    self.bg2X = 0
    self.coordOffsetX = 0
    t.data.timer = 0
    t.func = Scene.Task_AlternateOakPokedex
  end

  function Scene.Task_AlternateOakPokedex(self, t)
    if self._alternatePokedexShown then
      if Message.isOpen() then return end
      t.func = originalOakSpeechFadeOutBGM
      return
    end

    self._alternatePokedexShown = true
    clearMessage()
    self:clearTrainerPic()
    self:loadTrainerPic("oak")
    self.bg2X = 0
    self.coordOffsetX = 0

    showText(self,
      "I have a request for you.\f" ..
      "I want you to help me with my research.\f" ..
      "I've given you an invention of mine, the POKéDEX!\f" ..
      "It automatically records data on POKéMON\f" ..
      "you've seen or caught!\f" ..
      "It's a hi-tech encyclopedia!\f" ..
      "Take this with you, {PLAYER}!\f" ..
      "It will help you on your journey.\f" ..
      "To make a complete guide on all the POKéMON in the world...\f" ..
      "That was my dream! But, I'm too old!\f" ..
      "I can't do it!\f" ..
      "So, I want you to fulfill my dream for me!\f" ..
      "Get moving! This is a great undertaking in POKéMON history!"
    )
    t.func = Scene.Task_AlternateOakPokedexWait
  end

  function Scene.Task_AlternateOakPokedexWait(self, t)
    if Message.isOpen() then return end
    clearMessage()
    t.data.timer = 0
    t.func = originalOakSpeechFadeOutBGM
  end

  --------------------------------------------------------------------------
  -- Save/new-game state
  --------------------------------------------------------------------------

  local function setVar(name, value)
    local id = Flags.VAR_IDS[name]
    if id then Flags.setVar(Space.store, nil, id, value) end
  end

  local function setSessionVar(session, name, value)
    local id = Flags.VAR_IDS[name]
    if id then session.vars[id] = value end
  end

  local function setSessionFlag(session, name)
    local id = Flags.IDS[name]
    if id then session.flags[id] = true end
  end

  local function setupProgress(session)
    session.vars = session.vars or {}
    session.flags = session.flags or {}

    local species = tonumber(mod.save:get("firered_starter"))
    local row = STARTER_BY_SPECIES[species]
    if not row then return end

    -- Starter selection / Pokédex / opening progression.
    setSessionVar(session, "VAR_STARTER", row.index)
    setSessionVar(session, "VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB", 6)
    setSessionVar(session, "VAR_MAP_SCENE_VIRIDIAN_CITY_OLD_MAN", 2)
    setSessionVar(session, "VAR_MAP_SCENE_VIRIDIAN_CITY_MART", 1)
    setSessionVar(session, "VAR_MAP_SCENE_PALLET_TOWN_SIGN_LADY", 2)

    -- These are the existing early-game progression flags used by the
    -- FireRed field scripts for the post-opening state.
    session.flags[40] = true
    session.flags[41] = true
    session.flags[42] = true
    session.flags[45] = true
    session.flags[0x829] = true

    if Flags.IDS.EVENT_GOT_TOWN_MAP then
      session.flags[Flags.IDS.EVENT_GOT_TOWN_MAP] = true
    end

    session.dex = session.dex or { seen = {}, owned = {}, caught = {} }
    session.dex.seen = session.dex.seen or {}
    session.dex.owned = session.dex.owned or {}
    session.dex.caught = session.dex.caught or {}
    session.dex.seen[row.species] = true
    session.dex.owned[row.species] = true
    session.dex.caught[row.species] = true
  end

  mod.hooks:wrap("save.new_game", function(next, session)
    session = next(session) or session

    local species = tonumber(mod.save:get("firered_starter"))
    local row = STARTER_BY_SPECIES[species]
    if not row then return session end

    local nickname = mod.save:get("firered_starter_nickname")
    Party.giveMon(session, row.species, 5, nickname or row.name)
    setupProgress(session)
    return session
  end)

  --------------------------------------------------------------------------
  -- Mom
  --------------------------------------------------------------------------

  local function momDone()
    mod.save:set("firered_mom_gift_done", true)
    momEventRunning = false
    Field.unlock("alternate_oak_mom")
  end

  local function runMomEvent()
    if momEventRunning or not liveGame or mod.save:get("firered_mom_gift_done") then return end

    local handle = Objects.find(1)
    if not handle then return end

    local session = liveGame.save
    session.bag = session.bag or Bag.new()

    momEventRunning = true
    Field.lock("alternate_oak_mom")

    local function finish()
      handle:scriptMove("up", 1, function()
        handle:face("left")
        momDone()
      end)
    end

    local function giveShoes()
      if Flags.IDS.SYS_B_DASH then
        Flags.setFlag(Space.store, nil, Flags.IDS.SYS_B_DASH, true)
      end
      Audio.playFanfare("MUS_OBTAIN_ITEM")
      Message.show(
        playerName(liveGame) .. " got the RUNNING SHOES!",
        { npcColor = FrlgFont.NPC_TEXT_COLOR.FEMALE, done = finish }
      )
    end

    local function giveMap()
      Bag.add(session.bag, 361, 1)
      if Flags.IDS.EVENT_GOT_TOWN_MAP then
        Flags.setFlag(Space.store, nil, Flags.IDS.EVENT_GOT_TOWN_MAP, true)
      end
      Audio.playFanfare("MUS_OBTAIN_KEY_ITEM")
      Message.show(
        playerName(liveGame) .. " got a TOWN MAP!",
        { npcColor = FrlgFont.NPC_TEXT_COLOR.FEMALE, done = giveShoes }
      )
    end

    local function giveBalls()
      Bag.add(session.bag, 4, 10)
      Audio.playFanfare("MUS_OBTAIN_ITEM")
      Message.show(
        playerName(liveGame) .. " got 10 POKé BALLs!\\f" ..
        "They're useful for catching wild POKéMON.",
        { npcColor = FrlgFont.NPC_TEXT_COLOR.FEMALE, done = giveMap }
      )
    end

    handle:scriptMove("down", 1, function()
      handle:face("down")
      Message.show(
        "Right. All kids leave home someday.\\n" ..
        "It said so on TV.\\f" ..
        "I packed your things for your journey.\\n" ..
        "I even packed some fresh underwear.",
        { npcColor = FrlgFont.NPC_TEXT_COLOR.FEMALE, done = giveBalls }
      )
    end)
  end

  --------------------------------------------------------------------------
  -- Rival
  --------------------------------------------------------------------------

  local function hideRival(handle)
    if not handle then return end
    handle.hidden = true
    handle.visible = false
    handle.invisible = true
    handle.scriptBusy = false
  end

  local function revealRival(handle, x, y)
    handle.hidden = false
    handle.visible = true
    handle.invisible = false
    handle.scriptBusy = false
    handle:placeAt(x, y, "up")
  end

  local function moveSteps(handle, dir, count, done)
    if count <= 0 then
      done()
      return
    end
    handle:scriptMove(dir, 1, function()
      moveSteps(handle, dir, count - 1, done)
    end)
  end

  local function spawnRival(x, playerY)
    local handle = Objects.find(8)
    if not handle then return nil end

    local startY
    for y = playerY + 1, math.min(playerY + 8, 19) do
      if Collision.inBounds(x, y)
          and Collision.isWalkable(x, y)
          and not Objects.at(x, y) then
        startY = y
        break
      end
    end

    if not startY then return nil end

    revealRival(handle, x, startY)
    Audio.playSong(315)
    return handle, startY
  end

  local function rivalLeave(handle, playerX)
    local function step()
      if not handle or handle.hidden then return end

      local x = tonumber(handle.cellX) or playerX
      local y = tonumber(handle.cellY) or 0

      if Collision.inBounds(x, y - 1) and Collision.isWalkable(x, y - 1)
          and not Objects.at(x, y - 1) then
        handle:scriptMove("up", 1, step)
      elseif Collision.inBounds(x - 1, y) and Collision.isWalkable(x - 1, y)
          and not Objects.at(x - 1, y) then
        handle:scriptMove("left", 1, step)
      elseif Collision.inBounds(x + 1, y) and Collision.isWalkable(x + 1, y)
          and not Objects.at(x + 1, y) then
        handle:scriptMove("right", 1, step)
      else
        hideRival(handle)
      end
    end

    step()
  end

  local function startRivalBattle(x, y)
    if encounterRunning or mod.save:get("firered_pallet_rival_done") then
      return true
    end

    local species = tonumber(mod.save:get("firered_starter"))
    local trainerId = RIVAL_TRAINERS[species]
    if not trainerId then return false end

    local handle, startY = spawnRival(x, y)
    if not handle then return false end

    encounterRunning = true
    setVar("VAR_MAP_SCENE_PALLET_TOWN_OAK", 3)

    if Flags.IDS.FLAG_HIDE_RIVAL_IN_LAB then
      Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_RIVAL_IN_LAB, true)
    end
    if Flags.IDS.FLAG_HIDE_OAK_IN_HIS_LAB then
      Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_OAK_IN_HIS_LAB, false)
    end

    local name = playerName(liveGame)
    local rival = rivalName(liveGame)
    local foe = Trainers.foeFromId(trainerId)
    if not foe or not foe.party or not foe.party[1] then
      hideRival(handle)
      encounterRunning = false
      return false
    end

    foe.trainerId = trainerId
    foe.trainerName = rival
    foe.moves = RIVAL_MOVES[species]
    foe.party[1].moves = RIVAL_MOVES[species]

    local function beginBattle()
      local ok = BattleBridge.start(mod, liveGame, foe, {
        trainerId = trainerId,
        trainerName = rival,
        trainerClass = foe.trainerClass,
        trainerClassName = foe.trainerClassName,
        trainerPicId = foe.trainerPic,
        earlyRival = true,
        rivalFlags = 1,
        noWhiteout = true,
        rivalName = rival,
        defeatText = "Not bad, " .. name .. "!\\nYou're pretty tough.",
        done = function()
          mod.save:set("firered_pallet_rival_done", true)
          Party.healAll(liveGame.save.party)
          Message.show(
            "I need to train my POKéMON more.\\n" ..
            "I'll see you around, " .. name .. "!",
            {
              npcColor = FrlgFont.NPC_TEXT_COLOR.MALE,
              done = function()
                encounterRunning = false
                rivalLeave(handle, x)
              end,
            }
          )
        end,
      })

      if not ok then
        hideRival(handle)
        encounterRunning = false
      end
    end

    moveSteps(handle, "up", math.max(0, startY - y), function()
      handle:face("up")
      Message.show(
        "Hey, " .. name .. "!\\n" ..
        "Heading out already?\\f" ..
        "I've got a POKéMON too.\\n" ..
        "Let's have a battle!",
        {
          npcColor = FrlgFont.NPC_TEXT_COLOR.MALE,
          done = beginBattle,
        }
      )
    end)

    return true
  end

  --------------------------------------------------------------------------
  -- World-state hooks
  --------------------------------------------------------------------------

  mod.events:on("game.ready", function(ev)
    liveGame = ev.game
  end)

  mod.events:on("map.entered", function(ev)
    local mapId = tostring(ev and ev.mapId or "")
    if mapId:find("PALLET_TOWN_PROFESSOR_OAKS_LAB", 1, true) then
      if Flags.IDS.FLAG_HIDE_RIVAL_IN_LAB then
        Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_RIVAL_IN_LAB, true)
      end
      if Flags.IDS.FLAG_HIDE_OAK_IN_HIS_LAB then
        Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_OAK_IN_HIS_LAB, false)
      end

      setVar("VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB", 6)
    end
  end)

  --------------------------------------------------------------------------
  -- Pallet Town exit / Rival interception
  --------------------------------------------------------------------------

  local nativePlayerTryMove = Player.tryMove

  Player.tryMove = function(dir, game, run)
    if liveGame
        and dir == "up"
        and not momEventRunning
        and not encounterRunning
        and mod.save:get("firered_starter")
        and mod.save:get("firered_mom_gift_done")
        and not mod.save:get("firered_pallet_rival_done") then

      local mapId = tostring(Map.current or (liveGame.save and liveGame.save.map) or "")
      if mapId:find("PALLET_TOWN", 1, true)
          and not mapId:find("PROFESSOR_OAKS_LAB", 1, true) then
        local x = tonumber(Player.cellX)
        local y = tonumber(Player.cellY)

        if x and y and Collision.inBounds(x, y - 1) == false then
          if startRivalBattle(x, y) then
            return "blocked", "alternate_rival"
          end
        end
      end
    end

    return nativePlayerTryMove(dir, game, run)
  end

  --------------------------------------------------------------------------
  -- Mom trigger
  --------------------------------------------------------------------------

  mod.hooks:wrap("core.update", function(next, game, dt)
    local mapId = tostring(Map.current or (liveGame and liveGame.save and liveGame.save.map) or "")

    if liveGame
        and not momEventRunning
        and mapId == "FR_PLAYERS_HOUSE_1F"
        and mod.save:get("firered_starter")
        and not mod.save:get("firered_mom_gift_done")
        and not Player.moving
        and Player.cellX == 8
        and Player.cellY == 5 then
      runMomEvent()
    end

    return next(game, dt)
  end)
end
