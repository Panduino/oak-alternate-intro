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
  local RomText = require("src.core.game3.rom_text")

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

  local function starterRow(scene)
    return STARTER_BY_SPECIES[tonumber(scene._alternateStarterSpecies)]
  end

  local function starterImage(scene)
    local row = starterRow(scene)
    if not row then return nil end
    local ok, entry = pcall(Pokemon.frontPic, row.species, nil, false, 0)
    if ok and entry then return entry end
    return nil
  end

  local originalOakPrint = Scene.oakPrint
  local makePrinter
  for i = 1, 20 do
    local name, value = debug.getupvalue(originalOakPrint, i)
    if not name then break end
    if name == "newPrinter" then
      makePrinter = value
      break
    end
  end

  local function oakPrintText(self, text, speed)
    if not makePrinter then
      return originalOakPrint(self, "lets_go", speed)
    end
    text = RomText.ascii(text, {
      playerName = self.playerName,
      rivalName = self.rivalName,
    }):gsub("\\p", "\f"):gsub("\\l", "\n")
    self.win.dialog = true
    self.printer = makePrinter(text, speed == nil and self.textSpeed or speed, true)
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

  local function showStarterMenu(self)
    self.win.menu = {
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
    self._alternateStarterMenu = true
  end

  function Scene.Task_AlternateOakStarterIntro(self, t)
    if self:fadeActive() then return end
    self._alternateStarterSpecies = self._alternateStarterSpecies or STARTERS[1].species
    oakPrintText(self,
      "Before you leave, you should have\\na POKéMON of your own!\\f" ..
      "I have three wonderful\\nPOKéMON here for you.\\nWhich one would you like?"
    )
    showStarterMenu(self)
    t.func = Scene.Task_AlternateOakStarterInput
  end

  function Scene.Task_AlternateOakStarterInput(self, t)
    if self:printerActive() then return end
    local r = self:menuInput(false)
    local cursor = self.win.menu and self.win.menu.cursor or 0
    if self.win.menu then
      self._alternateStarterSpecies = STARTERS[cursor + 1].species
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
    oakPrintText(self,
      ("A %s will be a great\\npartner for you!\\f" ..
      "Would you like to\\ngive it a nickname?"):format(row.name)
    )
    t.func = Scene.Task_AlternateOakStarterNaming
  end

  function Scene.Task_AlternateOakStarterNaming(self, t)
    if self:printerActive() then return end

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

  local originalOakSpeechLetsGo = Scene.Task_OakSpeech_LetsGo

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
    self._alternateStarterInserted = true
    t.data.timer = 0
    t.func = originalOakSpeechLetsGo
  end

  Scene.Task_OakSpeech_LetsGo = function(self, t)
    if not self._alternateStarterInserted then
      self._alternateStarterInserted = true
      t.func = Scene.Task_AlternateOakStarterIntro
      return
    end
    return originalOakSpeechLetsGo(self, t)
  end

  local function setVar(name, value)
    local id = Flags.VAR_IDS[name]
    if id then
      Flags.setVar(Space.store, nil, id, value)
    end
  end

  local function setupProgress(session)
    session.vars = session.vars or {}
    session.flags = session.flags or {}

        local species = tonumber(mod.save:get("firered_starter"))
    local row = STARTER_BY_SPECIES[species]
    if not row then return end

    session.vars[0x4031] = row.index
    session.vars[0x4055] = 4

    session.flags[40] = true
    session.flags[41] = true
    session.flags[42] = true
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

    setupProgress(session)
    return session
  end)

  local function runMomEvent()
    if momEventRunning or not liveGame or mod.save:get("firered_mom_gift_done") then return end
    local Objects = require("src.core.game3.objects")
    local Field = require("src.core.game3.field")
    local Bag = require("src.core.game3.bag")
    local Message = require("src.ui.game3.message")
    local handle = Objects.find(1)
    if not handle then return end
    local session = liveGame.save
    session.bag = session.bag or Bag.new()
    Field.lock("alternate_oak_mom")
    momEventRunning = true
    local function finish()
      handle:scriptMove("up", 1, function()
        handle:face("left")
        mod.save:set("firered_mom_gift_done", true)
        momEventRunning = false
        Field.unlock("alternate_oak_mom")
      end)
    end
    local function giveShoes()
      if Flags.IDS.SYS_B_DASH then Flags.setFlag(Space.store, nil, Flags.IDS.SYS_B_DASH, true) end
      Audio.playFanfare("MUS_OBTAIN_ITEM")
      Message.show((session.playerName or session.name or "RED") .. " got the RUNNING SHOES!", {
        npcColor = FrlgFont.NPC_TEXT_COLOR.FEMALE, done = finish,
      })
    end
    local function giveMap()
      Bag.add(session.bag, 361, 1)
      Audio.playFanfare("MUS_OBTAIN_KEY_ITEM")
      Message.show((session.playerName or session.name or "RED") .. " got a TOWN MAP!", {
        npcColor = FrlgFont.NPC_TEXT_COLOR.FEMALE, done = giveShoes,
      })
    end
    local function giveBalls()
      Bag.add(session.bag, 4, 10)
      Audio.playFanfare("MUS_OBTAIN_ITEM")
      Message.show((session.playerName or session.name or "RED") .. " got 10 POKé BALLs!", {
        npcColor = FrlgFont.NPC_TEXT_COLOR.FEMALE, done = giveMap,
      })
    end
    handle:scriptMove("down", 1, function()
      handle:face("down")
      Message.show("Right. All kids leave home\\nsomeday. It said so on TV.\\fI packed your things for your journey.", {
        npcColor = FrlgFont.NPC_TEXT_COLOR.FEMALE, done = giveBalls,
      })
    end)
  end

  local function rivalDialog(text, done)
    local Message = require("src.ui.game3.message")
    Message.show(text, {
      npcColor = FrlgFont.NPC_TEXT_COLOR.MALE,
      done = done,
    })
  end

  local function spawnRival(mapId, x, y)
    local Objects = require("src.core.game3.objects")
    local Collision = require("src.core.game3.collision")
    local handle = Objects.find(8)
    if not handle then return nil end
    local startY
    for candidate = y + 1, math.min(y + 8, 19) do
      if Collision.inBounds(x, candidate) and Collision.isWalkable(x, candidate) and not Objects.at(x, candidate) then
        startY = candidate
        break
      end
    end
    if not startY then return nil end
    handle.hidden = false
    handle.visible = true
    handle.invisible = false
    handle.scriptBusy = false
    handle:placeAt(x, startY, "up")
    Audio.playSong(315)
    return handle, startY
  end

  local function removeRival()
    local Objects = require("src.core.game3.objects")
    local handle = Objects.find(8)
    if handle then
      handle.hidden = false
      handle.visible = true
      handle.scriptBusy = false
    end
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
    local Collision = require("src.core.game3.collision")
    local function leave()
      local y = tonumber(handle.cellY) or 0
      local x = tonumber(handle.cellX) or playerX
      if y <= 0 then
        handle.hidden = true
        handle.visible = false
        return
      end
      if Collision.inBounds(x, y - 1) and Collision.isWalkable(x, y - 1) then
        handle:scriptMove("up", 1, leave)
      else
        handle:scriptMove("left", 1, leave)
      end
    end
    leave()
  end

  local function startRivalBattle(mapId, x, y)
    if encounterRunning or mod.save:get("firered_pallet_rival_done") then
      return true
    end

    local species = tonumber(mod.save:get("firered_starter"))
    local trainerId = RIVAL_TRAINERS[species]
    if not trainerId then return false end

    local handle, startY = spawnRival(mapId, x, y)
    if not handle then return false end

    encounterRunning = true
    setVar("VAR_MAP_SCENE_PALLET_TOWN_OAK", 3)

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
          mod.save:set("firered_pallet_rival_done", true)
          Party.healAll(liveGame.save.party)
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

    move(handle, "up", math.max(0, startY - y), function()
      handle:face("up")
      rivalDialog(
        "Hey, " .. playerName .. "!\\n" ..
        "Heading out already?\\n\\f" ..
        "I've got a POKéMON too.\\nLet's have a battle!",
        beginBattle
      )
    end)

    return true
  end

  mod.events:on("game.ready", function(ev)
    liveGame = ev.game
  end)

  mod.events:on("map.entered", function(ev)
    if not ev.mapId then return end
    local entered = tostring(ev.mapId)
    if entered:find("PALLET_TOWN_PROFESSOR_OAKS_LAB", 1, true) then
      if Flags.IDS.FLAG_HIDE_RIVAL_IN_LAB then Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_RIVAL_IN_LAB, true) end
      if Flags.IDS.FLAG_HIDE_OAK_IN_HIS_LAB then Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_OAK_IN_HIS_LAB, false) end
    end
  end)

  -- Player.tryMove is the correct seam for an outdoor connection: the
  -- native movement code checks the destination bounds and only then calls
  -- tryConnection. Intercept that exact attempt before the Route 1 warp.
  local Player = require("src.core.game3.player")
  local Collision = require("src.core.game3.collision")
  local Map = require("src.core.game3.map")
  local SpaceMod = require("src.core.game3.scripting.space")
  local nativePlayerTryMove = Player.tryMove
  Player.tryMove = function(dir, game, run)
    if liveGame and not momEventRunning and not encounterRunning and dir == "up"
        and (mod.save:get("firered_starter") or (liveGame.save and liveGame.save.party and #liveGame.save.party > 0))
        and mod.save:get("firered_mom_gift_done") and not mod.save:get("firered_pallet_rival_done") then
      local mapId = tostring(Map.current or SpaceMod.mapId or "")
      if mapId == "FR_PALLET_TOWN" then
        local x, y = tonumber(Player.cellX), tonumber(Player.cellY)
        if x and y and not Collision.inBounds(x, y - 1) and startRivalBattle(mapId, x, y) then
          return "blocked", "alternate_rival"
        end
      end
    end
    return nativePlayerTryMove(dir, game, run)
  end

  mod.hooks:wrap("core.update", function(next, game, dt)
    local mapId = tostring(Map.current or (liveGame and liveGame.save and liveGame.save.map) or "")
    if liveGame and not momEventRunning and mapId == "FR_PLAYERS_HOUSE_1F"
        and (mod.save:get("firered_starter") or (liveGame.save and liveGame.save.party and #liveGame.save.party > 0))
        and not mod.save:get("firered_mom_gift_done") and not Player.moving
        and Player.cellX == 8 and Player.cellY == 5 then
      runMomEvent()
    end
    return next(game, dt)
  end)
end
