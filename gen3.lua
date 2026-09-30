return function(mod)
  local Scene = require("src.ui.game3.new_game_scene")
  local Naming = require("src.ui.game3.naming")
  local Pokemon = require("src.core.game3.pokemon")
  local Party = require("src.core.game3.party")
  local FrlgFont = require("src.ui.game3.frlg_font")
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
  local RIVAL_OBJECT_ID = 8

  local function rawPrint(scene, text)
    text = text:gsub("\\f", "\f")
    text = text:gsub("\\n", "\n")
    text = text:gsub("\\p", "\f")
    text = text:gsub("\\l", "\n")
    text = text:gsub("{PLAYER}", scene.playerName or "RED")

    local pages = {}
    for page in (text .. "\f"):gmatch("(.-)\f") do
      pages[#pages + 1] = page
    end

    local printer = {
      pages = pages,
      page = 1,
      revealed = 0,
      pos = 1,
      active = true,
      waiting = false,
      delay = 0,
    }

    local function charCount(s)
      return FrlgFont.countChars(s or "")
    end

    printer.total = charCount(printer.pages[1])

    function printer:run(newAB, heldAB)
      if not self.active then return end

      if self.waiting then
        if newAB then
          Audio.playSe(SE.SE_SELECT)
          if self.page < #self.pages then
            self.page = self.page + 1
            self.revealed = 0
            self.pos = 1
            self.waiting = false
            self.delay = 0
            self.total = charCount(self.pages[self.page])
          else
            self.active = false
          end
        end
        return
      end

      local speed = tonumber(scene.textSpeed) or 4
      if speed < 1 then speed = 1 end
      if heldAB then speed = 0 end

      if self.delay > 0 then
        self.delay = self.delay - 1
        return
      end

      if self.revealed >= self.total then
        self.waiting = true
        return
      end

      self.revealed = self.revealed + 1
      self.delay = speed - 1
      if newAB then
        self.delay = 0
      end
    end

    function printer:draw(x, y, opts)
      FrlgFont.draw(self.pages[self.page] or "", x, y, {
        maxWidth = opts.maxWidth,
        colors = opts.colors or FrlgFont.COLOR.NORMAL,
        linePitch = FrlgFont.LINE_PITCH,
        limitChars = self.revealed,
      })
    end

    scene.win.dialog = true
    scene.printer = printer
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
      rawPrint(self, "Before you leave,\\nget yourself a\\nPOKéMON!")
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
    if t.data.picFadeState == 0 then return end
    self:clearTrainerPic()
    self:loadTrainerPic("oak")
    t.data.picPosX = 0
    self.coordOffsetX = 0
    self.bg2X = 0
    self:createFadeOutTask(t, 2)
    t.func = Scene.Task_AlternateOakPokedexText
  end

  function Scene.Task_AlternateOakPokedexText(self, t)
    if t.data.picFadeState == 0 then return end
    if self:printerActive() then return end

    if t.data.page == nil then
      t.data.page = 1
      rawPrint(self,
        "I have a request for you.\f" ..
        "I want you to help me with\nmy research.\f" ..
        "I've given you an invention\nof mine, the POKéDEX!\f" ..
        "It records information on\nPOKéMON you've seen or\ncaught!\f" ..
        "It's a hi-tech encyclopedia!\f" ..
        "Take this with you, {PLAYER}!\f" ..
        "It will help you on your journey.\f" ..
        "To make a complete guide on\nall the POKéMON in the world...\f" ..
        "That was my dream! But, I'm too\nold! I can't do it!\f" ..
        "So, I want you to fulfill my\ndream for me!\f" ..
        "Get moving! This is a great\nundertaking in POKéMON history!")
      return
    end

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

  local function applyProgress(session)
    session.vars = session.vars or {}
    session.flags = session.flags or {}

    local species = tonumber(mod.save:get("firered_starter"))
    local row = STARTER_BY_SPECIES[species]
    if not row then return end

    session.vars[0x4031] = row.index
    session.vars[0x4050] = 1
    session.vars[0x4055] = 6

    session.flags[40] = true
    session.flags[41] = true
    session.flags[42] = true
    session.flags[43] = false
    session.flags[44] = true
    session.flags[45] = true
    session.flags[0x829] = true

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
    if activeRival then
      local Objects = require("src.core.game3.objects")
      Objects.removeObject(activeRival)
      activeRival = nil
    end
  end

  local function spawnRival(mapId, x)
    if activeRival then
      removeRival()
    end

    local Objects = require("src.core.game3.objects")
    if not Objects.addObject(RIVAL_OBJECT_ID) then return nil end

    local handle = mod.world:npc(mapId, RIVAL_OBJECT_ID)
    if not handle then
      Objects.removeObject(RIVAL_OBJECT_ID)
      return nil
    end

    handle:placeAt(15, 8, "up")
    activeRival = RIVAL_OBJECT_ID
    return handle
  end

  local function move(handle, dir, count, done)
    if count <= 0 then
      done()
      return
    end
    handle:scriptMove(dir, 1, function()
      move(handle, dir, count - 1, done)
    end)
  end

  local function departRival(handle, playerX)
    move(handle, "up", 2, removeRival)
  end

  local function startRivalBattle(mapId, x, y)
    if encounterRunning or mod.save:get("firered_pallet_rival_done") then
      return true
    end

    local species = tonumber(mod.save:get("firered_starter"))
    local trainerId = RIVAL_TRAINERS[species]
    if not trainerId then return false end

    local handle = spawnRival(mapId, x)
    if not handle then return false end

    encounterRunning = true
    mod.save:set("firered_pallet_rival_done", true)
    setVar("VAR_MAP_SCENE_PALLET_TOWN_OAK", 1)

    if Flags.IDS.FLAG_HIDE_RIVAL_IN_LAB then
      Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_RIVAL_IN_LAB, true)
    end
    if Flags.IDS.FLAG_HIDE_OAK_IN_HIS_LAB then
      Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_OAK_IN_HIS_LAB, false)
    end

    local playerName = liveGame.save.player.name or "RED"
    local rivalName = liveGame.save.rivalName or "BLUE"
    local foe = Trainers.foeFromId(trainerId)
    if not foe then
      removeRival()
      encounterRunning = false
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
        defeatText = "Not bad, " .. playerName .. "!\\nYou're pretty tough.",
        done = function()
          Party.healAll(liveGame.save.party)
          if Flags.IDS.FLAG_BEAT_RIVAL_IN_OAKS_LAB then
            Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_BEAT_RIVAL_IN_OAKS_LAB, true)
          end
          rivalDialog(
            "I need to train my POKéMON more.\\n" ..
            "I'll see you around, " .. playerName .. "!",
            function()
              departRival(handle, x)
            end
          )
        end,
      })
      if not ok then
        removeRival()
        encounterRunning = false
      end
    end

    move(handle, "up", 6, function()
      move(handle, "left", 15 - x, function()
        handle:face("up")
      rivalDialog(
        "Hey, " .. playerName .. "!\\n" ..
        "Heading out already?\\n\\f" ..
        "I've got a POKéMON too.\\nLet's have a battle!",
        beginBattle
      )
      end)
    end)

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
      setVar("VAR_MAP_SCENE_PALLET_TOWN_OAK", 1)
      setVar("VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB", 6)
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
    if not liveGame or mod.save:get("firered_mom_gift_done") then return end
    local handle = mod.world:npc("FR_PLAYERS_HOUSE_1F", 1)
    if not handle then return end

    local Message = require("src.ui.game3.message")
    local Bag = require("src.core.game3.bag")
    local session = liveGame.save
    session.bag = session.bag or Bag.new()

    local function returnMom()
      handle:scriptMove("up", 1, function()
        handle:face("down")
        mod.save:set("firered_mom_gift_done", true)
      end)
    end

    local function giveMap()
      Bag.add(session.bag, 361, 1)
      Audio.playFanfare("MUS_OBTAIN_KEY_ITEM")
      Message.show((session.player and session.player.name or "RED") ..
        " got a TOWN MAP!", {
        npcColor = FrlgFont.NPC_TEXT_COLOR.MALE,
        done = returnMom,
      })
    end

    local function giveBalls()
      Bag.add(session.bag, 4, 10)
      Audio.playFanfare("MUS_LEVEL_UP")
      Message.show((session.player and session.player.name or "RED") ..
        " got 10 POKé BALLs!", {
        npcColor = FrlgFont.NPC_TEXT_COLOR.MALE,
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

    local px = tonumber(session.player and session.player.x) or 8
    local py = tonumber(session.player and session.player.y) or 5
    local mx, my = handle:position()
    local steps = 0

    local function walkToPlayer()
      mx, my = handle:position()
      if mx == px and my == py - 1 then
        handle:face("up")
        talk()
        return
      end

      local dir
      if my > py - 1 then
        dir = "up"
      elseif my < py - 1 then
        dir = "down"
      elseif mx < px then
        dir = "right"
      elseif mx > px then
        dir = "left"
      end

      if not dir or steps >= 16 or not handle:canStep(dir) then
        handle:face("up")
        talk()
        return
      end

      steps = steps + 1
      handle:scriptMove(dir, 1, walkToPlayer)
    end

    walkToPlayer()
  end
  mod.events:on("map.entered", function(ev)
    if not ev.mapId then return end
    if tostring(ev.mapId) == "FR_PLAYERS_HOUSE_1F"
        and mod.save:get("firered_starter")
        and not mod.save:get("firered_mom_gift_done") then
      runMomEvent()
    end
    if tostring(ev.mapId):find("PALLET_TOWN_PROFESSOR_OAKS_LAB", 1, true) then
      if Flags.IDS.FLAG_HIDE_RIVAL_IN_LAB then
        Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_RIVAL_IN_LAB, true)
      end
      if Flags.IDS.FLAG_HIDE_OAK_IN_HIS_LAB then
        Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_OAK_IN_HIS_LAB, false)
      end
      setVar("VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB", 6)
    end
  end)

  mod.events:on("world.stepped", function(ev)
    if encounterRunning or mod.save:get("firered_pallet_rival_done") then return end
    if not liveGame or not ev.mapId then return end
    local mapId = tostring(ev.mapId)
    if not mapId:find("PALLET_TOWN", 1, true)
        or mapId:find("PROFESSOR_OAKS_LAB", 1, true) then
      return
    end
    if ev.y ~= 2 or (ev.x ~= 12 and ev.x ~= 13) then return end
    if not mod.save:get("firered_starter") then return end
    if not mod.save:get("firered_mom_gift_done") then return end

    startRivalBattle(ev.mapId, ev.x, ev.y)
  end)
end
