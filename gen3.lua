return function(mod)
  local Scene = require("src.ui.game3.new_game_scene")
  local Naming = require("src.ui.game3.naming")
  local Pokemon = require("src.core.game3.pokemon")
  local Party = require("src.core.game3.party")
  local FrlgFont = require("src.ui.game3.frlg_font")
  local RomText = require("src.core.game3.rom_text")
  local Chrome = require("src.ui.game3.chrome")
  local Audio = require("src.core.game3.audio")
  local SE = require("src.core.game3.se_ids")
  local Flags = require("src.core.game3.scripting.flags")
  local Space = require("src.core.game3.scripting.space")
  local Trainers = require("src.core.game3.scripting.trainers")
  local BattleBridge = require("src.core.game3.battle_bridge")

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
  local activeRival
  local encounterRunning = false
  local momEventRunning = false
  local RIVAL_OBJECT_ID = 3

  -- Reuse the engine's working FireRed Oak printer instead of maintaining
  -- a second text implementation.  We temporarily replace RomText.ascii so
  -- Scene:oakPrint builds its normal native printer from our literal text.
  local nativeOakPrint = Scene.oakPrint

  local function rawPrint(scene, text)
    text = tostring(text or "")
    text = text:gsub("\\f", "\f")
    text = text:gsub("\\n", "\n")
    text = text:gsub("\\p", "\f")
    text = text:gsub("\\l", "\n")
    text = text:gsub("{PLAYER}", scene.playerName or "RED")

    local oldAscii = RomText.ascii
    RomText.ascii = function()
      return text
    end

    local ok, err = pcall(nativeOakPrint, scene, "lets_go")
    RomText.ascii = oldAscii
    if not ok then error(err, 0) end

    -- Native FireRed normally closes the final page at EOS.  For this intro
    -- every page, including the last one, must wait for A before the scene
    -- advances.  Keep the native renderer/arrow and only intercept EOS.
    local printer = scene.printer
    if printer and not printer._alternateFinalWait then
      local nativeRender = printer.render
      printer.render = function(p, newAB, heldAB)
        if p._alternateFinalWait then
          if newAB then
            p._alternateFinalWait = false
            p.active = false
            return "finish"
          end
          nativeRender(p, false, heldAB)
          return "update"
        end

        local result = nativeRender(p, newAB, heldAB)
        if result == "finish" then
          p._alternateFinalWait = true
          p.active = true
          p.state = "clear"
          p.arrowIdx = 0
          p.arrowDelay = 0
          p.arrowFrame = nil
          return "update"
        end
        return result
      end
    end
  end

  local function starterRow(scene)
    return STARTER_BY_SPECIES[tonumber(scene._alternateStarterSpecies)]
  end

  local function loadStarterImage(scene)
    local row = starterRow(scene)
    if not row then return end
    local ok, entry = pcall(Pokemon.frontPic, row.species, nil, false, 0)
    if ok and entry and entry.image then
      scene._alternateStarterImage = entry
    else
      scene._alternateStarterImage = nil
    end
  end

  local originalDrawBg0Text = Scene.drawBg0Text
  Scene.drawBg0Text = function(self)
    originalDrawBg0Text(self)
    if not self._alternateStarterMenu then return end

    local entry = self._alternateStarterImage
    if not (entry and entry.image) then return end

    local img = entry.image
    local iw = entry.w or img:getWidth()
    local ih = entry.h or img:getHeight()
    local scale = math.min(80 / iw, 80 / ih)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, 200, 68, 0, scale, scale, iw / 2, ih / 2)
  end

  local function showStarterMenu(self)
    self.win.menu = {
      kind = "starter",
      left = 2,
      top = 4,
      width = 18,
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
    self._alternateStarterMenu = true
    loadStarterImage(self)
  end

  function Scene.Task_AlternateOakStarterIntro(self, t)
    if self:fadeActive() then return end
    self._alternateStarterSpecies = self._alternateStarterSpecies or STARTERS[1].species

    if t.data.page == nil then
      t.data.page = 1
      rawPrint(self, "Before you leave\\fYou should have a\\nPOKéMON of your own!")
      return
    end

    if self:printerActive() then return end
    if t.data.page == 1 then
      t.data.page = 2
      rawPrint(self, "I have three wonderful\\nPOKéMON here for you.")
      return
    end

    if self:printerActive() then return end
    if t.data.page == 2 then
      t.data.page = 3
      rawPrint(self, "Which one would you like?")
      return
    end

    if self:printerActive() then return end
    t.func = Scene.Task_AlternateOakStarterInput
  end

  function Scene.Task_AlternateOakStarterInput(self, t)
    if self:printerActive() then return end
    if not self.win.menu then
      showStarterMenu(self)
      return
    end
    local oldCursor = self.win.menu.cursor
    local r = self:menuInput(false)
    local cursor = self.win.menu and self.win.menu.cursor or 0
    if self.win.menu then
      self._alternateStarterSpecies = STARTERS[cursor + 1].species
      if cursor ~= oldCursor then
        loadStarterImage(self)
      end
    end
    if type(r) ~= "number" or r < 0 or r > 2 then return end

    local row = STARTERS[r + 1]
    self._alternateStarterSpecies = row.species
    mod.save:set("firered_starter", row.species)
    self:_answered("starter", row.species, "starter")

    Audio.playSe(SE.SE_SELECT)
    pcall(Audio.playCry, row.species, 0)

    self.win.menu = nil
    self._alternateStarterMenu = false
    self:clearDialog()
    rawPrint(self,
      ("A %s will be a great\\npartner for you!"):format(row.name))
    t.func = Scene.Task_AlternateOakStarterNaming
  end

  function Scene.Task_AlternateOakStarterNaming(self, t)
    local row = starterRow(self)
    if not row then
      t.func = Scene.Task_OakSpeech_FadeInRivalPic
      return
    end

    if not t.data.questionShown then
      if self:printerActive() then return end
      rawPrint(self, ("Would you like to give\nyour %s a nickname?"):format(row.name))
      t.data.questionShown = true
      return
    end

    if self:printerActive() then return end

    self._alternateStarterNamingTask = t
    self.win.menu = {
      kind = "yesno",
      left = 2,
      top = 2,
      width = 6,
      height = 4,
      items = {
        { "Yes", 8, 2 },
        { "No", 8, 18 },
      },
      cursorX = 0,
      cursorY = 2,
      pitch = 16,
      cursor = 0,
    }
    t.func = Scene.Task_AlternateOakStarterNicknameChoice
  end

  function Scene.Task_AlternateOakStarterNicknameChoice(self, t)
    local r = self:menuInput(false)
    if r == "none" then return end

    self.win.menu = nil
    if r == 1 then
      local row = starterRow(self)
      self._alternateStarterNickname = row and row.name or "POKéMON"
      t.data.timer = 0
      t.func = Scene.Task_AlternateOakStarterAfterNaming
      return
    end

    local row = starterRow(self)
    if not row then
      t.func = Scene.Task_OakSpeech_FadeInRivalPic
      return
    end

    self:clearDialog()
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
          task.data.timer = 24
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

    self:clearDialog()
    self:createFadeInTask(t, 2)
    t.data.timer = 0
    t.func = Scene.Task_OakSpeech_FadeInRivalPic
  end

  local originalFadeInRivalPic = Scene.Task_OakSpeech_FadeInRivalPic
  Scene.Task_OakSpeech_FadeInRivalPic = function(self, t)
    self:loadTrainerPic("rival")
    return originalFadeInRivalPic(self, t)
  end

  Scene.Task_OakSpeech_AskRivalsName = function(self, t)
    if t.data.picFadeState == 0 then return end
    self:loadTrainerPic("rival")
    if self.pic then self.pic.hidden = false end
    self:oakPrint("rival_intro")
    self.hasPlayerBeenNamed = true
    t.func = Scene.Task_OakSpeech_MoveRivalDisplayNameOptions
  end

  Scene.Task_OakSpeech_FadeOutPlayerPic = function(self, t)
    local d = t.data
    if d.picFadeState == 0 then return end
    self:clearTrainerPic()
    if d.timer ~= 0 then
      d.timer = d.timer - 1
      return
    end

    self:loadTrainerPic("oak")
    d.picPosX = 0
    self.coordOffsetX = 0
    self.bg2X = 0
    self:createFadeOutTask(t, 2)
    t.data.timer = 0
    t.func = Scene.Task_AlternateOakStarterIntro
  end

  Scene.Task_OakSpeech_FadeOutRivalPic = function(self, t)
    if self:printerActive() then return end
    self:clearDialog()
    self:createFadeInTask(t, 2)
    t.func = Scene.Task_AlternateOakPokedexSetup
  end

  function Scene.Task_AlternateOakPokedexSetup(self, t)
    if self:fadeActive() then return end
    self:clearTrainerPic()
    self:loadTrainerPic("oak")
    if self.pic then self.pic.hidden = false end
    t.data.picPosX = 0
    self.coordOffsetX = 0
    self.bg2X = 0
    self:createFadeOutTask(t, 2)
    t.func = Scene.Task_AlternateOakPokedexText
  end

  function Scene.Task_AlternateOakPokedexText(self, t)
    if t.data.picFadeState == 0 then return end
    if self.pic then self.pic.hidden = false end

    if t.data.started ~= true then
      t.data.started = true
      rawPrint(self,
        "I have a request for you.\\f" ..
        "I want you to help me with\\nmy research.\\f" ..
        "I've given you an invention\\nof mine, the POKéDEX!\\f" ..
        "It automatically records\\ndata on POKéMON\\f" ..
        "you've seen or caught!\\f" ..
        "It's a hi-tech encyclopedia!\\f" ..
        "Take this with you, {PLAYER}!\\f" ..
        "It will help you on your journey.\\f" ..
        "To make a complete guide on\\nall the POKéMON in the world...\\f" ..
        "That was my dream! But, I'm too\\nold! I can't do it!\\f" ..
        "So, I want you to fulfill my\\ndream for me!\\f" ..
        "Get moving! This is a great\\nundertaking in POKéMON history!")
      return
    end

    if self:printerActive() then return end

    self:clearDialog()
    self:createFadeInTask(t, 2)
    t.func = Scene.Task_OakSpeech_ReshowPlayersPic
  end

  local function setVar(name, value)
    local id = Flags.VAR_IDS[name]
    if id then
      Flags.setVar(Space.store, nil, id, value)
    end
  end

  local function setFlag(name, value)
    local id = Flags.IDS[name]
    if id then
      Flags.setFlag(Space.store, nil, id, value)
    end
  end

  local function applyProgress(session)
    session.vars = session.vars or {}
    session.flags = session.flags or {}

    local species = tonumber(mod.save:get("firered_starter"))
    local row = STARTER_BY_SPECIES[species]
    if not row then return end

    session.vars[0x4031] = row.index
    session.vars[0x4050] = 3
    session.vars[0x4051] = 2 -- Viridian tutorial old man already completed
    session.vars[0x4070] = 2 -- Pallet Trainer Tips girl already completed
    session.vars[0x4055] = 6
    session.vars[0x4057] = 2
    session.vars[0x4058] = 2

    session.flags[40] = true
    session.flags[41] = true
    session.flags[42] = true
    session.flags[43] = false
    session.flags[44] = true
    session.flags[45] = true
    session.flags[58] = true -- FLAG_HIDE_POKEDEX
    -- FireRed's special flags are what actually expose these start-menu
    -- entries.  Keep these separate from the normal event flags.
    session.flags[0x828] = true -- Pokémon menu
    session.flags[0x829] = true -- Pokédex menu

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
    if not Party.giveMon(session, row.species, 5, nickname or row.name) then
      return session
    end

    applyProgress(session)
    return session
  end)

  local function rivalDialog(text, done)
    local Message = require("src.ui.game3.message")
    Message.show(text, {
      npcColor = FrlgFont.NPC_TEXT_COLOR.MALE,
      done = done,
    })
  end

  local function removeRival()
    if not activeRival then return end
    local Objects = require("src.core.game3.objects")
    Objects.removeObject(activeRival)
    activeRival = nil
    setFlag("FLAG_HIDE_OAK_IN_PALLET_TOWN", true)
    if Objects.refreshVisibility then Objects.refreshVisibility() end
    if Objects.refreshGraphics then Objects.refreshGraphics() end
  end

  local function spawnRival(mapId)
    if activeRival then
      removeRival()
    end

    local Objects = require("src.core.game3.objects")
    setFlag("FLAG_HIDE_OAK_IN_PALLET_TOWN", false)
    if not Objects.addObject(RIVAL_OBJECT_ID) then
      setFlag("FLAG_HIDE_OAK_IN_PALLET_TOWN", true)
      return nil
    end

    local handle = mod.world:npc(mapId, RIVAL_OBJECT_ID)
    if not handle then
      Objects.removeObject(RIVAL_OBJECT_ID)
      setFlag("FLAG_HIDE_OAK_IN_PALLET_TOWN", true)
      return nil
    end

    -- This is the exact live EventObject path used by the last known
    -- working Rival encounter. Only change its appearance after obtaining
    -- the real map object.
    handle:placeAt(10, 8, "up")
    if not handle:setAppearance("SPRITE_BLUE") then
      Objects.removeObject(RIVAL_OBJECT_ID)
      setFlag("FLAG_HIDE_OAK_IN_PALLET_TOWN", true)
      return nil
    end

    activeRival = RIVAL_OBJECT_ID
    return handle
  end

  local function pathBetween(handle, targetX, targetY, done)
    local Collision = require("src.core.game3.collision")
    local dirs = {
      { name = "up", dx = 0, dy = -1 },
      { name = "down", dx = 0, dy = 1 },
      { name = "left", dx = -1, dy = 0 },
      { name = "right", dx = 1, dy = 0 },
    }

    local sx, sy = handle:position()
    local queue = { { x = sx, y = sy, path = {} } }
    local head = 1
    local seen = { [sx .. "," .. sy] = true }
    local found

    while head <= #queue do
      local node = queue[head]
      head = head + 1
      if node.x == targetX and node.y == targetY then
        found = node.path
        break
      end
      for _, d in ipairs(dirs) do
        local nx, ny = node.x + d.dx, node.y + d.dy
        local key = nx .. "," .. ny
        if not seen[key] and Collision.canEnter(nil, nx, ny, {
            fromX = node.x, fromY = node.y, dir = d.name, surfing = false,
            elevation = 3,
          }) then
          seen[key] = true
          local nextPath = {}
          for i, step in ipairs(node.path) do nextPath[i] = step end
          nextPath[#nextPath + 1] = d.name
          queue[#queue + 1] = { x = nx, y = ny, path = nextPath }
        end
      end
    end

    if not found then
      done(false)
      return
    end

    local function walk(i)
      if i > #found then
        done(true)
        return
      end
      handle:scriptMove(found[i], 1, function()
        walk(i + 1)
      end)
    end
    walk(1)
  end

  local function departRival(handle, playerX)
    -- Go around the player, using the other north-exit lane, then continue
    -- to the edge. The final step deliberately leaves the map bounds so the
    -- player can actually see Rival walk off-screen.
    local escapeX = playerX == 12 and 13 or 12

    pathBetween(handle, escapeX, 0, function(ok)
      if not ok then
        removeRival()
        encounterRunning = false
        require("src.core.game3.field").unlock("alternate_oak_rival")
        return
      end

      handle:scriptMove("up", 1, function()
        removeRival()
        encounterRunning = false
        require("src.core.game3.field").unlock("alternate_oak_rival")
      end)
    end)
  end

  local function startRivalBattle(mapId, x, y)
    if encounterRunning or mod.save:get("firered_pallet_rival_done") then
      return true
    end

    local species = tonumber(mod.save:get("firered_starter"))
    local trainerId = RIVAL_TRAINERS[species]
    if not trainerId then return false end

    local handle = spawnRival(mapId)
    if not handle then return false end

    local Field = require("src.core.game3.field")
    local Player = require("src.core.game3.player")
    Field.lock("alternate_oak_rival")
    encounterRunning = true

    -- Face the approaching Rival before his first step.
    Player.facing = "down"
    if liveGame.save then liveGame.save.facing = "down" end

    -- The Rival's battle theme starts when he begins walking toward the player.
    Audio.playSong("MUS_VS_TRAINER")

    setVar("VAR_MAP_SCENE_PALLET_TOWN_OAK", 3)

    if Flags.IDS.FLAG_HIDE_RIVAL_IN_LAB then
      Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_RIVAL_IN_LAB, true)
    end
    if Flags.IDS.FLAG_HIDE_OAK_IN_HIS_LAB then
      Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_OAK_IN_HIS_LAB, false)
    end

    local playerName = liveGame.save.playerName or liveGame.save.name or "RED"
    local rivalName = liveGame.save.rivalName or "BLUE"
    local foe = Trainers.foeFromId(trainerId)
    if not foe then
      removeRival()
      encounterRunning = false
      require("src.core.game3.field").unlock("alternate_oak_rival")
      return false
    end

    foe.trainerId = trainerId
    foe.trainerName = rivalName
    foe.moves = RIVAL_MOVES[species]
    foe.party[1].moves = RIVAL_MOVES[species]

    local function beginBattle()
      local ok = BattleBridge.start(mod, liveGame, foe, {
        trainerId = trainerId,
        trainerName = rivalName,
        trainerClass = foe.trainerClass,
        trainerClassName = foe.trainerClassName,
        trainerPicId = foe.trainerPic,
        earlyRival = true,
        rivalFlags = 1,
        noWhiteout = true,
        rivalName = rivalName,
        defeatText = "WHAT? Unbelievable! I picked the wrong POKéMON!",
        done = function()
          Party.healAll(liveGame.save.party)
          rivalDialog(
            "OK! I'll make my POKéMON fight to toughen it up!\\n" ..
            playerName .. "! Smell you later!",
            function()
              departRival(handle, x)
            end
          )
        end,
      })
      if not ok then
        removeRival()
        encounterRunning = false
        require("src.core.game3.field").unlock("alternate_oak_rival")
      else
        mod.save:set("firered_pallet_rival_done", true)
      end
    end

    -- Use FireRed's exact Pallet Town Oak approach.  The native Oak object
    -- starts at (10,8); the left/right trigger movement is the same fixed
    -- applymovement sequence used by the ROM.
    local approach
    if x == 12 then
      approach = { "up", "up", "right", "up", "up", "right", "up", "up" }
    else
      approach = { "right", "up", "up", "right", "up", "up", "right", "up", "up" }
    end

    local function walkApproach(i)
      if i > #approach then
        handle:face("down")
        rivalDialog(
          playerName .. "! You're finally out! You overslept, didn't you?\\f" ..
          "Wait " .. playerName .. "! Let's check out our POKéMON!\\n" ..
          "Come on, I'll take you on!",
          beginBattle
        )
        return
      end

      handle:scriptMove(approach[i], 1, function()
        walkApproach(i + 1)
      end)
    end

    walkApproach(1)

    return true
  end

  mod.events:on("game.ready", function(ev)
    liveGame = ev.game
    if liveGame and liveGame.save then
      applyProgress(liveGame.save)
      if Flags.IDS.FLAG_HIDE_OAK_IN_HIS_LAB then
        Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_OAK_IN_HIS_LAB, false)
      end
      if Flags.IDS.FLAG_HIDE_OAK_IN_PALLET_TOWN then
        Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_OAK_IN_PALLET_TOWN, true)
      end
      if Flags.IDS.FLAG_HIDE_RIVAL_IN_LAB then
        Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_RIVAL_IN_LAB, true)
      end
      -- Scene 1 is the original Oak-catches-you sequence.  Scene 3 is the
      -- post-intro state, so never leave the vanilla grab trigger armed.
      setVar("VAR_MAP_SCENE_PALLET_TOWN_OAK", 3)
      setVar("VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB", 6)
      setVar("VAR_MAP_SCENE_PALLET_TOWN_RIVALS_HOUSE", 2)
      setVar("VAR_MAP_SCENE_VIRIDIAN_CITY_MART", 2)
      setFlag("FLAG_SYS_POKEMON_GET", true)
      setFlag("FLAG_SYS_POKEDEX_GET", true)
    end
  end)

  local function giveMomItems()
    local Bag = require("src.core.game3.bag")
    local session = liveGame and liveGame.save
    if not session then return end
    session.bag = session.bag or Bag.new()
    Bag.add(session.bag, 4, 10)
    Bag.add(session.bag, 361, 1)
  end

  local function runMomEvent()
    if momEventRunning then return end
    if not liveGame or mod.save:get("firered_mom_gift_done") then return end
    local handle = mod.world:npc("FR_PLAYERS_HOUSE_1F", 1)
    if not handle then return end

    local Message = require("src.ui.game3.message")
    local Bag = require("src.core.game3.bag")
    local Field = require("src.core.game3.field")
    local session = liveGame.save
    session.bag = session.bag or Bag.new()

    Field.lock("alternate_oak_mom")
    momEventRunning = true

    local function finish()
      -- Do not start the return walk until the final item message/fanfare
      -- has completely finished.
      handle:scriptMove("left", 2, function()
        handle:scriptMove("down", 1, function()
          handle:face("left")
          mod.save:set("firered_mom_gift_done", true)
          momEventRunning = false
          Field.unlock("alternate_oak_mom")
        end)
      end)
    end

    local function giveShoes()
      session.flags = session.flags or {}
      session.flags[0x82F] = true
      if Space and Space.store then
        local dashFlag = Flags.IDS.FLAG_SYS_B_DASH or Flags.IDS.SYS_B_DASH
        if dashFlag then
          Flags.setFlag(Space.store, nil, dashFlag, true)
        end
      end
      Audio.playFanfare("MUS_OBTAIN_KEY_ITEM")
      Message.show((session.playerName or session.name or "RED") ..
        " got RUNNING SHOES!", {
          npcColor = FrlgFont.NPC_TEXT_COLOR.FEMALE,
          done = finish,
        })
    end

    local function giveMap()
      Bag.add(session.bag, 361, 1)
      Audio.playFanfare("MUS_OBTAIN_KEY_ITEM")
      Message.show((session.playerName or session.name or "RED") ..
        " got a TOWN MAP!", {
          npcColor = FrlgFont.NPC_TEXT_COLOR.FEMALE,
          done = giveShoes,
        })
    end

    local function giveBalls()
      Bag.add(session.bag, 4, 10)
      Audio.playFanfare("MUS_OBTAIN_ITEM")
      Message.show((session.playerName or session.name or "RED") ..
        " got 10 POKé BALLs!", {
          npcColor = FrlgFont.NPC_TEXT_COLOR.FEMALE,
          done = giveMap,
        })
    end

    local function talk()
      handle:face("up")
      Message.show("Right. All kids leave home\\nsomeday. It said so on TV.", {
        npcColor = FrlgFont.NPC_TEXT_COLOR.FEMALE,
        done = function()
          Message.show("I've packed some fresh\\nunderwear for you, too.\\fYou'll need to be prepared\\nfor your journey!", {
            npcColor = FrlgFont.NPC_TEXT_COLOR.FEMALE,
            done = giveBalls,
          })
        end,
      })
    end

    handle:scriptMove("right", 2, function()
      handle:scriptMove("up", 1, function()
        handle:face("up")
        talk()
      end)
    end)
  end

  mod.events:on("map.entered", function(ev)
    if not ev.mapId then return end
    if tostring(ev.mapId):find("PALLET_TOWN_PROFESSOR_OAKS_LAB", 1, true) then
      if Flags.IDS.FLAG_HIDE_RIVAL_IN_LAB then
        Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_RIVAL_IN_LAB, true)
      end
      if Flags.IDS.FLAG_HIDE_OAK_IN_HIS_LAB then
        Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_OAK_IN_HIS_LAB, false)
      end
      -- FireRed's post-Pokédex lab state is scene 6. Oak is local
      -- object 4; the two Pokédex props are local objects 9 and 10.
      -- Explicitly restore that native state because the alternate intro
      -- never runs FireRed's normal scene-6 cleanup script.
      local Objects = require("src.core.game3.objects")
      setVar("VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB", 6)
      Objects.showObject(4)
      Objects.removeObject(9)
      Objects.removeObject(10)
      if Objects.refreshVisibility then Objects.refreshVisibility() end
      if Objects.refreshGraphics then Objects.refreshGraphics() end

      setVar("VAR_MAP_SCENE_PALLET_TOWN_RIVALS_HOUSE", 2)
      setVar("VAR_MAP_SCENE_VIRIDIAN_CITY_MART", 2)
    end
  end)

  -- FireRed's actual Pallet Town trigger is an on-frame coordinate
  -- trigger at (12,1) and (13,1), before the north connection to Route 1.
  -- Poll that exact in-town trigger tile before the engine processes the
  -- next movement frame. This avoids relying on movement.collision, which
  -- is not the vanilla coordinate-trigger seam for an edge connection.
  mod.hooks:wrap("core.update", function(next, game, dt)
    local ow = liveGame and liveGame.overworld
    local map = ow and ow.map
    local mapId = map and tostring(map.id or "") or ""

    if liveGame and not momEventRunning
        and mapId == "FR_PLAYERS_HOUSE_1F"
        and mod.save:get("firered_starter")
        and not mod.save:get("firered_mom_gift_done") then
      local Player = require("src.core.game3.player")
      local Warp = require("src.core.game3.warp")
      if not Player.moving and not Warp.isBusy() then
        runMomEvent()
      end
    end

    if liveGame and not encounterRunning
        and mod.save:get("firered_starter")
        and mod.save:get("firered_mom_gift_done")
        and not mod.save:get("firered_pallet_rival_done") then
      local Player = require("src.core.game3.player")
      local x, y = tonumber(Player.cellX), tonumber(Player.cellY)
      if mapId == "PALLET_TOWN"
          and (x == 12 or x == 13)
          and y == 1
          and Player.facing == "up" then
        startRivalBattle("PALLET_TOWN", x, y)
      end
    end
    return next(game, dt)
  end)
end