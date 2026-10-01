return function(mod)
  local Scene = require("src.ui.game3.new_game_scene")
  local Naming = require("src.ui.game3.naming")
  local Pokemon = require("src.core.game3.pokemon")
  local Party = require("src.core.game3.party")
  local FrlgFont = require("src.ui.game3.frlg_font")
  local Chrome = require("src.ui.game3.chrome")
  local Audio = require("src.core.game3.audio")
  local Song = { MUS_OBTAIN_ITEM = 258, MUS_OBTAIN_KEY_ITEM = 318 }
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
  local rivalPlayerFacing = nil
  local rivalFacingLocked = false

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

  -- The Oak scene already has a native FireRed printer in new_game_scene.lua.
  -- Keep the same printer contract here so the alternate dialogue is drawn
  -- by the Oak scene itself, with the normal page arrow and A-button input.
  local function utf8Chars(s)
    local out = {}
    for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
      out[#out + 1] = ch
    end
    return out
  end

  local function newOakPrinter(text, speed)
    local p = {
      pages = {}, page = 1, revealed = 0, tokens = {}, pos = 1,
      active = true, state = "char", delay = 0, spedUp = false,
      canSpeedUp = true, arrowIdx = 0, arrowDelay = 0, arrowFrame = nil,
    }

    local pageText = ""
    local function addPage(raw)
      p.pages[#p.pages + 1] = FrlgFont.wrap(raw, Chrome.DLG_W * 8, {
        linePitch = FrlgFont.LINE_PITCH,
      })
    end
    for _, ch in ipairs(utf8Chars(text)) do
      if ch == "\f" then
        addPage(pageText)
        pageText = ""
        p.tokens[#p.tokens + 1] = "P"
      elseif ch == "\n" then
        pageText = pageText .. ch
        p.tokens[#p.tokens + 1] = "N"
      else
        pageText = pageText .. ch
        p.tokens[#p.tokens + 1] = "C"
      end
    end
    addPage(pageText)
    p.tokens[#p.tokens + 1] = "E"
    p.textSpeed = speed == 0 and 0 or speed - 1

    if speed == 0 then
      while p.active do
        local tok = p.tokens[p.pos]
        p.pos = p.pos + 1
        if tok == "C" or tok == "N" then
          p.revealed = p.revealed + 1
        elseif tok == "E" or tok == nil then
          p.active = false
        end
      end
    end

    function p:render(newAB, heldAB)
      if self.state == "char" then
        if heldAB and self.spedUp then self.delay = 0 end
        if self.delay > 0 and self.textSpeed > 0 then
          self.delay = self.delay - 1
          if self.canSpeedUp and newAB then
            self.spedUp = true
            self.delay = 0
          end
          return "update"
        end

        self.delay = self.textSpeed
        local tok = self.tokens[self.pos]
        self.pos = self.pos + 1

        if tok == "N" then
          self.revealed = self.revealed + 1
          return "repeat"
        elseif tok == "P" then
          self.state = "clear"
          self.arrowIdx, self.arrowDelay = 0, 0
          return "update"
        elseif tok == "E" or tok == nil then
          -- Keep the final page on screen until A is pressed, just like a
          -- normal FireRed dialogue page.
          self.state = "clear"
          self.arrowIdx, self.arrowDelay = 0, 0
          self._finalPage = true
          return "update"
        end

        self.revealed = self.revealed + 1
        return "print"
      end

      if self.arrowDelay ~= 0 then
        self.arrowDelay = self.arrowDelay - 1
      else
        self.arrowFrame = ({ 0, 1, 2, 1 })[self.arrowIdx + 1]
        self.arrowDelay = 8
        self.arrowIdx = (self.arrowIdx + 1) % 4
      end

      if newAB then
        Audio.playSe(SE.SE_SELECT)
        if self._finalPage then
          self.active = false
          self.arrowFrame = nil
        else
          self.page = self.page + 1
          self.revealed = 0
          self.arrowFrame = nil
          self.state = "char"
        end
      end
      return "update"
    end

    function p:run(newAB, heldAB)
      if not self.active then return end
      for _ = 1, 64 do
        if self:render(newAB, heldAB) ~= "repeat" then return end
      end
    end

    function p:draw(x, y, opts)
      local text = self.pages[self.page] or ""
      local _, endX, endY = FrlgFont.draw(text, x, y, {
        maxWidth = opts.maxWidth or 240,
        limitChars = self.revealed,
        colors = opts.colors or FrlgFont.COLOR.NORMAL,
        linePitch = opts.linePitch,
      })
      if self.state == "clear" and self.arrowFrame and endX then
        Chrome.promptArrow(endX, endY, self.arrowFrame)
      end
    end

    return p
  end

  local function showText(scene, text, opts)
    opts = opts or {}
    scene.win.dialog = true
    scene.printer = newOakPrinter(text, opts.speed == nil and scene.textSpeed or opts.speed)
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

    local menu = self.win.menu
    if menu and type(menu.cursor) == "number" then
      local cursorRow = STARTERS[menu.cursor + 1]
      if cursorRow then self._alternateStarterSpecies = cursorRow.species end
    end

    local row = starterRow(self)
    local entry = starterImage(self)
    if not (row and entry and entry.image) then return end

    local img = entry.image
    local iw = entry.w or img:getWidth()
    local ih = entry.h or img:getHeight()
    local scale = math.min(80 / iw, 80 / ih)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, 48, 68, 0, scale, scale, iw / 2, ih / 2)
  end

  --------------------------------------------------------------------------
  -- Oak speech
  --
  -- Leave the native player/rival naming sequence completely untouched.
  -- The native ReshowPlayersPic task is the transition immediately after
  -- the rival name has been confirmed. We replace only that transition so
  -- the native LetsGo text is never printed.
  --------------------------------------------------------------------------

  local originalOakSpeechReshowPlayersPic = Scene.Task_OakSpeech_ReshowPlayersPic
  local originalOakSpeechFadeOutBGM = Scene.Task_OakSpeech_FadeOutBGM

  Scene.Task_OakSpeech_ReshowPlayersPic = function(self, t)
    local d = t.data
    if d.picFadeState == 0 then return end

    self:clearTrainerPic()

    if d.timer ~= 0 then
      d.timer = d.timer - 1
      return
    end

    self:loadPlayerPic()
    d.picPosX = 0
    self.coordOffsetX = 0
    self.bg2X = 0
    self:createFadeOutTask(t, 2)

    -- This is the exact point where vanilla FireRed would assign
    -- Task_OakSpeech_LetsGo. Go straight into the alternate sequence.
    t.func = Scene.Task_AlternateOakStarterIntro
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
    if self:printerActive() then return end

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
    if self:printerActive() then return end

    local row = starterRow(self)
    if not row then
      t.func = Scene.Task_AlternateOakPokedex
      return
    end

    if not self._alternateNicknameChoice then
      self._alternateNicknameChoice = true
      self.win.menu = {
        kind = "yesno",
        left = 12,
        top = 8,
        width = 6,
        height = 4,
        items = {
          { "YES", 8, 2 },
          { "NO", 8, 18 },
        },
        cursorX = 0,
        cursorY = 2,
        pitch = 16,
        cursor = 0,
      }
      return
    end

    local result = self:menuInput(false)
    if result == "none" then return end

    self.win.menu = nil
    self._alternateNicknameChoice = false

    if result == 0 then
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
    else
      self._alternateStarterNickname = row.name
      t.data.timer = 1
      t.func = Scene.Task_AlternateOakStarterAfterNaming
    end
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
      if self:printerActive() then return end
      t.func = Scene.Task_AlternateOakPokedexWait
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
      "Take this with you, " .. (self.playerName or "RED") .. "!\f" ..
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
    if self:printerActive() then return end

    -- Finish the Pokédex speech by returning to the player picture,
    -- then use the native FireRed ending text and exit animation.
    clearMessage()
    self:clearTrainerPic()
    self:loadPlayerPic()
    self.bg2X = 0
    self.coordOffsetX = 0
    self:createFadeOutTask(t, 2)
    t.func = Scene.Task_AlternateOakLetsGo
  end

  function Scene.Task_AlternateOakLetsGo(self, t)
    if t.data.picFadeState == 0 then return end
    self:oakPrint("lets_go")
    t.data.timer = 30
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

    -- Match the actual FireRed post-Pokédex state.
    setSessionVar(session, "VAR_STARTER_MON", row.index)
    setSessionVar(session, "VAR_MAP_SCENE_PALLET_TOWN_OAK", 1)
    setSessionVar(session, "VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB", 6)
    setSessionVar(session, "VAR_MAP_SCENE_VIRIDIAN_CITY_MART", 2)
    setSessionVar(session, "VAR_MAP_SCENE_VIRIDIAN_CITY_OLD_MAN", 2)
    setSessionVar(session, "VAR_MAP_SCENE_PALLET_TOWN_RIVALS_HOUSE", 2)
    setSessionVar(session, "VAR_MAP_SCENE_ROUTE22", 1)
    setSessionVar(session, "VAR_MAP_SCENE_PALLET_TOWN_SIGN_LADY", 2)

    local progressionFlags = {
      "FLAG_SYS_POKEMON_GET",
      "FLAG_SYS_POKEDEX_GET",
      "FLAG_SYS_B_DASH",
      "FLAG_OPENED_START_MENU",
      "FLAG_PALLET_LADY_NOT_BLOCKING_SIGN",
      "FLAG_VISITED_OAKS_LAB",
      "FLAG_BEAT_RIVAL_IN_OAKS_LAB",
      "FLAG_WORLD_MAP_PALLET_TOWN",
      "FLAG_WORLD_MAP_VIRIDIAN_CITY",
    }
    for _, name in ipairs(progressionFlags) do
      if Flags.IDS[name] then
        session.flags[Flags.IDS[name]] = true
      end
    end

    -- The physical map and Pokédex objects have already been received.
    if Flags.IDS.FLAG_HIDE_TOWN_MAP then
      session.flags[Flags.IDS.FLAG_HIDE_TOWN_MAP] = true
    end
    if Flags.IDS.FLAG_HIDE_POKEDEX then
      session.flags[Flags.IDS.FLAG_HIDE_POKEDEX] = true
    end

    -- Oak is present in the lab; his lab rival is not.
    if Flags.IDS.FLAG_HIDE_OAK_IN_HIS_LAB then
      session.flags[Flags.IDS.FLAG_HIDE_OAK_IN_HIS_LAB] = false
    end

    local taken = { [row.species] = true }
    if row.species == 1 then taken[4] = true
    elseif row.species == 4 then taken[7] = true
    elseif row.species == 7 then taken[1] = true end
    local ballFlags = {
      [1] = "FLAG_HIDE_BULBASAUR_BALL",
      [4] = "FLAG_HIDE_CHARMANDER_BALL",
      [7] = "FLAG_HIDE_SQUIRTLE_BALL",
    }
    for speciesId, flagName in pairs(ballFlags) do
      local flag = Flags.IDS[flagName]
      if flag then session.flags[flag] = taken[speciesId] == true end
    end

    if Flags.IDS.FLAG_HIDE_RIVAL_IN_LAB then
      session.flags[Flags.IDS.FLAG_HIDE_RIVAL_IN_LAB] = true
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
      local px = tonumber(Player.cellX) or 0
      local py = tonumber(Player.cellY) or 0

      local function faceHome()
        Objects.scriptFace(handle, "left")
        momDone()
      end

      local function moveHome()
        local mx = tonumber(handle.cellX) or 8
        local my = tonumber(handle.cellY) or 4

        if mx == 8 and my == 4 then
          faceHome()
          return
        end

        local queue = { { x = mx, y = my, path = {} } }
        local seen = { [mx .. ":" .. my] = true }
        local dirs = {
          { dx = 0, dy = -1, dir = "up" },
          { dx = 0, dy = 1, dir = "down" },
          { dx = -1, dy = 0, dir = "left" },
          { dx = 1, dy = 0, dir = "right" },
        }
        local foundPath
        local head = 1

        while head <= #queue do
          local node = queue[head]
          head = head + 1
          if node.x == 8 and node.y == 4 then
            foundPath = node.path
            break
          end

          for _, d in ipairs(dirs) do
            local nx, ny = node.x + d.dx, node.y + d.dy
            local key = nx .. ":" .. ny
            if not seen[key]
                and Collision.inBounds(nx, ny)
                and Collision.isWalkable(nx, ny)
                and not (nx == px and ny == py)
                and not Objects.at(nx, ny) then
              seen[key] = true
              local path = {}
              for i, step in ipairs(node.path) do path[i] = step end
              path[#path + 1] = d.dir
              queue[#queue + 1] = { x = nx, y = ny, path = path }
            end
          end
        end

        if foundPath and #foundPath > 0 then
          local steps = {}
          for _, dir in ipairs(foundPath) do
            steps[#steps + 1] = { kind = "step", dir = dir }
          end
          Objects.startTrack(handle.localId, steps, faceHome)
        else
          faceHome()
        end
      end

      moveHome()
    end

    local giftStage = nil

    local function showItem(stage, itemText, explanation, fanfare, done)
      if giftStage == stage then return end
      giftStage = stage
      Message.show(itemText, {
        npcColor = FrlgFont.NPC_TEXT_COLOR.FEMALE,
        done = function()
          pcall(Audio.playFanfare, fanfare)
          Message.show(explanation, {
            npcColor = FrlgFont.NPC_TEXT_COLOR.FEMALE,
            done = function()
              if done then Audio.waitFanfare(done) end
            end,
          })
        end,
      })
    end

    local function giveShoes()
      if Flags.IDS.SYS_B_DASH then
        Flags.setFlag(Space.store, nil, Flags.IDS.SYS_B_DASH, true)
      end
      showItem("shoes",
        playerName(liveGame) .. " got the RUNNING SHOES!",
        "They let you run while you hold the B Button.",
        Song.MUS_OBTAIN_ITEM,
        finish
      )
    end

    local function giveTeachyTv()
      Bag.add(session.bag, 366, 1)
      showItem("teachy_tv",
        playerName(liveGame) .. " got the TEACHY TV!",
        "You can use it if you need help.",
        Song.MUS_OBTAIN_KEY_ITEM,
        giveShoes
      )
    end

    local function giveMap()
      Bag.add(session.bag, 361, 1)
      if Flags.IDS.EVENT_GOT_TOWN_MAP then
        Flags.setFlag(Space.store, nil, Flags.IDS.EVENT_GOT_TOWN_MAP, true)
      end
      showItem("town_map",
        playerName(liveGame) .. " got a TOWN MAP!",
        "It shows the towns and routes you've visited.",
        Song.MUS_OBTAIN_KEY_ITEM,
        giveTeachyTv
      )
    end

    local function giveBalls()
      Bag.add(session.bag, 4, 10)
      showItem("poke_balls",
        playerName(liveGame) .. " got 10 POKé BALLs!",
        "You can use POKé BALLs to catch wild POKéMON.",
        Song.MUS_OBTAIN_ITEM,
        giveMap
      )
    end

    local function talk()
      local px = tonumber(Player.cellX) or 10
      local py = tonumber(Player.cellY) or 3
      local mx = tonumber(handle.cellX) or 8
      local my = tonumber(handle.cellY) or 4

      local function facePlayer()
        mx = tonumber(handle.cellX) or mx
        my = tonumber(handle.cellY) or my
        px = tonumber(Player.cellX) or px
        py = tonumber(Player.cellY) or py

        if px < mx then Objects.scriptFace(handle, "left")
        elseif px > mx then Objects.scriptFace(handle, "right")
        elseif py < my then Objects.scriptFace(handle, "up")
        else Objects.scriptFace(handle, "down") end

        Message.show(
          "Right. All kids leave home someday.\\n" ..
          "It said so on TV.\\f" ..
          "I packed your things for your journey.\\n" ..
          "I even packed some fresh underwear.",
          { npcColor = FrlgFont.NPC_TEXT_COLOR.FEMALE, done = giveBalls }
        )
      end

      local function moveToPlayer()
        mx = tonumber(handle.cellX) or mx
        my = tonumber(handle.cellY) or my

        local targets = {
          { x = px - 1, y = py, dir = "right" },
          { x = px + 1, y = py, dir = "left" },
          { x = px, y = py - 1, dir = "down" },
          { x = px, y = py + 1, dir = "up" },
        }

        local target
        for _, candidate in ipairs(targets) do
          if Collision.inBounds(candidate.x, candidate.y)
              and Collision.isWalkable(candidate.x, candidate.y)
              and not (candidate.x == mx and candidate.y == my)
              and not Objects.at(candidate.x, candidate.y) then
            target = candidate
            break
          end
        end

        if not target then
          facePlayer()
          return
        end

        -- Find the complete route once. Recomputing the route after every
        -- step was causing Mom to pick a different adjacent tile and loop.
        local queue = { { x = mx, y = my, path = {} } }
        local seen = { [mx .. ":" .. my] = true }
        local dirs = {
          { dx = 0, dy = -1, dir = "up" },
          { dx = 0, dy = 1, dir = "down" },
          { dx = -1, dy = 0, dir = "left" },
          { dx = 1, dy = 0, dir = "right" },
        }
        local foundPath

        local head = 1
        while head <= #queue do
          local node = queue[head]
          head = head + 1
          if node.x == target.x and node.y == target.y then
            foundPath = node.path
            break
          end

          for _, d in ipairs(dirs) do
            local nx, ny = node.x + d.dx, node.y + d.dy
            local key = nx .. ":" .. ny
            if not seen[key]
                and Collision.inBounds(nx, ny)
                and Collision.isWalkable(nx, ny)
                and not (nx == px and ny == py)
                and not Objects.at(nx, ny) then
              seen[key] = true
              local path = {}
              for i, step in ipairs(node.path) do path[i] = step end
              path[#path + 1] = d.dir
              queue[#queue + 1] = { x = nx, y = ny, path = path }
            end
          end
        end

        if foundPath and #foundPath > 0 then
          Objects.startTrack(handle.localId, (function()
            local steps = {}
            for _, dir in ipairs(foundPath) do
              steps[#steps + 1] = { kind = "step", dir = dir }
            end
            return steps
          end)(), facePlayer)
        else
          facePlayer()
        end
      end

      moveToPlayer()
    end

    -- The vanilla stairs arrive at (10, 2). Trigger as the player steps
    -- onto the floor at the bottom of them, then keep the player locked
    -- while Mom walks over and handles the entire gift sequence.
    talk()
  end

  --------------------------------------------------------------------------
  -- Rival
  --------------------------------------------------------------------------

  -- Pallet Town does not have the normal Rival object in its map object list.
  -- Build one from the same Rival graphics used by FireRed and add it only
  -- when the encounter starts.
  local RIVAL_OBJECT_ID = 8

  local function ensureRivalObject(x, y)
    local handle = Objects.find(RIVAL_OBJECT_ID)
    if handle then return handle end

    if type(Objects._defs) ~= "table" then return nil end
    for _, def in ipairs(Objects._defs) do
      if tonumber(def.localId or def.index) == RIVAL_OBJECT_ID then
        Objects.addObject(RIVAL_OBJECT_ID)
        return Objects.find(RIVAL_OBJECT_ID)
      end
    end

    Objects._defs[#Objects._defs + 1] = {
      localId = RIVAL_OBJECT_ID,
      graphicsId = 72,
      x = x,
      y = y,
      movementType = 8,
      elevation = 3,
      passable = false,
    }
    Objects.addObject(RIVAL_OBJECT_ID)
    return Objects.find(RIVAL_OBJECT_ID)
  end

  local function hideRival(handle)
    if not handle then return end
    handle.hidden = true
    handle.visible = false
    handle.invisible = true
    handle.scriptBusy = false
  end

  local function revealRival(handle, x, y)
    handle.cellX = x
    handle.cellY = y
    handle.homeX = x
    handle.homeY = y
    handle.targetX = x
    handle.targetY = y
    handle.px = x * 16
    handle.py = y * 16
    handle.facing = "up"
    handle.hidden = false
    handle.visible = true
    handle.invisible = false
    handle.scriptBusy = false
  end

  local function moveSteps(handle, dir, count, done)
    if count <= 0 then
      done()
      return
    end
    local steps = {}
    for _ = 1, count do
      steps[#steps + 1] = { kind = "step", dir = dir }
    end
    Objects.startTrack(handle.localId, steps, done)
  end

  local function spawnRival(x, playerY)
    local handle = ensureRivalObject(x, playerY)
    if not handle then return nil end

    -- The player is stopped on the north edge of Pallet Town. Put Rival
    -- on the first walkable tile below the player, never on the player's tile.
    local startY
    local fallbackY
    for y = playerY + 1, math.min(playerY + 8, 19) do
      if Collision.inBounds(x, y)
          and Collision.isWalkable(x, y)
          and not Objects.at(x, y) then
        fallbackY = y
        if y >= playerY + 4 then
          startY = y
          break
        end
      end
    end
    startY = startY or fallbackY

    if not startY then return nil end

    revealRival(handle, x, startY)
    Audio.playSong(315)
    return handle, startY
  end

  local function rivalLeave(handle, playerX)
    local function hideAtRouteEntrance()
      hideRival(handle)
      Field.unlock("alternate_oak_rival")
    end

    local function findRoutePath()
      if not handle or handle.hidden then return nil end
      local sx = tonumber(handle.cellX) or playerX
      local sy = tonumber(handle.cellY) or 0
      local px = tonumber(Player.cellX) or playerX
      local py = tonumber(Player.cellY) or 0

      local queue = { { x = sx, y = sy, path = {} } }
      local seen = { [sx .. ":" .. sy] = true }
      local dirs = {
        { dx = 0, dy = -1, dir = "up" },
        { dx = 0, dy = 1, dir = "down" },
        { dx = -1, dy = 0, dir = "left" },
        { dx = 1, dy = 0, dir = "right" },
      }

      local head = 1
      while head <= #queue do
        local node = queue[head]
        head = head + 1
        if node.y == 0 then return node.path end

        for _, d in ipairs(dirs) do
          local nx, ny = node.x + d.dx, node.y + d.dy
          local key = nx .. ":" .. ny
          if not seen[key]
              and Collision.inBounds(nx, ny)
              and Collision.isWalkable(nx, ny)
              and not (nx == px and ny == py)
              and not Objects.at(nx, ny) then
            seen[key] = true
            local path = {}
            for i, step in ipairs(node.path) do path[i] = step end
            path[#path + 1] = d.dir
            queue[#queue + 1] = { x = nx, y = ny, path = path }
          end
        end
      end
      return nil
    end

    local path = findRoutePath()
    if not path or #path == 0 then
      hideAtRouteEntrance()
      return
    end

    local steps = {}
    for _, dir in ipairs(path) do
      steps[#steps + 1] = { kind = "step", dir = dir }
    end
    -- Keep the normal walking animation for the last three tiles as the
    -- Rival walks beyond the Route 1 boundary.
    steps[#steps + 1] = { kind = "step", dir = "up" }
    steps[#steps + 1] = { kind = "step", dir = "up" }
    steps[#steps + 1] = { kind = "step", dir = "up" }
    Objects.startTrack(handle.localId, steps, hideAtRouteEntrance)
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
    Field.lock("alternate_oak_rival")
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
      Field.unlock("alternate_oak_rival")
      return false
    end

    foe.trainerId = trainerId
    foe.trainerName = rival
    foe.moves = RIVAL_MOVES[species]
    foe.party[1].moves = RIVAL_MOVES[species]

    local function beginBattle()
      rivalPlayerFacing = nil
      rivalFacingLocked = false
      Player.facingLocked = false
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
            "OK! I'll make my POKéMON\\n" ..
            "fight to toughen it up!\\n" ..
            name .. "! Smell you later!",
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
        Field.unlock("alternate_oak_rival")
      end
    end

    moveSteps(handle, "up", math.max(0, startY - y - 1), function()
      local px = tonumber(Player.cellX) or x
      local py = tonumber(Player.cellY) or y
      local rx = tonumber(handle.cellX) or x
      local ry = tonumber(handle.cellY) or y
      local playerDir
      if math.abs(px - rx) > math.abs(py - ry) then
        playerDir = px > rx and "right" or "left"
      else
        playerDir = py > ry and "down" or "up"
      end
      Player.facing = playerDir
      Player.moveDir = playerDir
      Player.turnTimer = 0
      Player.turnArmed = false
      Player.facingLocked = true
      rivalPlayerFacing = playerDir
      Objects.facePlayer(handle.localId)
      Message.show(
        name .. "! You're finally out!\\n" ..
        "You overslept, didn't you?\\f" ..
        "I'll take you on!",
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

    -- Rival is not a normal Pallet Town object. Keep the temporary encounter
    -- object hidden whenever the map is entered; story code reveals it.
    if mapId == "FR_PALLET_TOWN" or mapId == "PalletTown" then
      local rivalHandle = Objects.find(RIVAL_OBJECT_ID)
      if rivalHandle then hideRival(rivalHandle) end
    end

    if mapId:find("PALLET_TOWN_PROFESSOR_OAKS_LAB", 1, true) then
      if Flags.IDS.FLAG_HIDE_RIVAL_IN_LAB then
        Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_RIVAL_IN_LAB, true)
      end
      if Flags.IDS.FLAG_HIDE_OAK_IN_HIS_LAB then
        Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_OAK_IN_HIS_LAB, false)
      end

      setVar("VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB", 6)
      setVar("VAR_MAP_SCENE_VIRIDIAN_CITY_MART", 2)
      setVar("VAR_MAP_SCENE_VIRIDIAN_CITY_OLD_MAN", 2)
      setVar("VAR_MAP_SCENE_PALLET_TOWN_RIVALS_HOUSE", 2)
      setVar("VAR_MAP_SCENE_ROUTE22", 1)

      if Flags.IDS.FLAG_HIDE_OAK_IN_HIS_LAB then
        Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_OAK_IN_HIS_LAB, false)
      end
      if Flags.IDS.FLAG_HIDE_RIVAL_IN_LAB then
        Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_RIVAL_IN_LAB, true)
      end
      if Flags.IDS.FLAG_HIDE_POKEDEX then
        Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_POKEDEX, true)
      end
      local species = tonumber(mod.save:get("firered_starter"))
      local taken = { [species] = true }
      if species == 1 then taken[4] = true
      elseif species == 4 then taken[7] = true
      elseif species == 7 then taken[1] = true end
      local ballFlags = {
        [1] = "FLAG_HIDE_BULBASAUR_BALL",
        [4] = "FLAG_HIDE_CHARMANDER_BALL",
        [7] = "FLAG_HIDE_SQUIRTLE_BALL",
      }
      for speciesId, flagName in pairs(ballFlags) do
        local flag = Flags.IDS[flagName]
        if flag then Flags.setFlag(Space.store, nil, flag, taken[speciesId] == true) end
      end
    end
  end)

  --------------------------------------------------------------------------
  -- Pallet Town exit / Rival interception
  --------------------------------------------------------------------------

  local nativePlayerTryMove = Player.tryMove

  Player.tryMove = function(dir, game, run)
    if encounterRunning then
      return "blocked", "alternate_rival"
    end

    if liveGame
        and not momEventRunning
        and not encounterRunning
        and mod.save:get("firered_starter")
        and not mod.save:get("firered_mom_gift_done") then
      local mapId = tostring(Map.current or (liveGame.save and liveGame.save.map) or "")
      if (mapId == "PalletTown_PlayersHouse_1F"
          or mapId == "FR_PLAYERS_HOUSE_1F"
          or mapId:find("PLAYERS_HOUSE_1F", 1, true)) then
        local dx, dy = 0, 0
        if dir == "up" then dy = -1
        elseif dir == "down" then dy = 1
        elseif dir == "left" then dx = -1
        elseif dir == "right" then dx = 1
        end

        local nx = tonumber(Player.cellX) + dx
        local ny = tonumber(Player.cellY) + dy
        if Collision.warpAt(nx, ny) then
          runMomEvent()
          return "blocked", "alternate_mom"
        end
      end
    end

    if liveGame
        and dir == "up"
        and not momEventRunning
        and not encounterRunning
        and mod.save:get("firered_starter")
        and mod.save:get("firered_mom_gift_done")
        and not mod.save:get("firered_pallet_rival_done") then

      local mapId = tostring(Map.current or (liveGame.save and liveGame.save.map) or "")
      if mapId == "FR_PALLET_TOWN" or mapId == "PalletTown" then
        local x = tonumber(Player.cellX)
        local y = tonumber(Player.cellY)

        -- Intercept the north exit before the native warp can fire.
        if x and y and y == 2 and (x == 12 or x == 13) then
          if startRivalBattle(x, y) then
            return "blocked", "alternate_rival"
          end
        end
      end
    end

    return nativePlayerTryMove(dir, game, run)
  end

  --------------------------------------------------------------------------
  -- Pallet Town Rival trigger
  --------------------------------------------------------------------------

  mod.events:on("world.stepped", function(ev)
    if encounterRunning
        or momEventRunning
        or mod.save:get("firered_pallet_rival_done")
        or not mod.save:get("firered_starter")
        or not mod.save:get("firered_mom_gift_done") then
      return
    end

    local mapId = tostring(ev and ev.mapId or "")
    if mapId ~= "FR_PALLET_TOWN" and mapId ~= "PalletTown" then return end

    local x = tonumber(ev.x)
    local y = tonumber(ev.y)
    if not x or not y then return end

    if y == 2 and (x == 12 or x == 13) then
      startRivalBattle(x, y)
    end
  end)

  --------------------------------------------------------------------------
  -- Mom trigger
  --------------------------------------------------------------------------

  mod.hooks:wrap("core.update", function(next, game, dt)
    local result = next(game, dt)

    local mapId = tostring(Map.current or (liveGame and liveGame.save and liveGame.save.map) or "")

    if rivalPlayerFacing then
      Player.facing = rivalPlayerFacing
      Player.moveDir = rivalPlayerFacing
      Player.turnTimer = 0
      Player.turnArmed = false
      Player.facingLocked = rivalFacingLocked
      if liveGame and Player.syncToHost then
        Player.syncToHost(liveGame)
      end
    end

    if liveGame and mapId:find("PALLET_TOWN_PROFESSOR_OAKS_LAB", 1, true) then
      if Flags.IDS.FLAG_HIDE_OAK_IN_HIS_LAB then
        Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_OAK_IN_HIS_LAB, false)
      end
      if Flags.IDS.FLAG_HIDE_RIVAL_IN_LAB then
        Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_RIVAL_IN_LAB, true)
      end
      if Flags.IDS.FLAG_HIDE_POKEDEX then
        Flags.setFlag(Space.store, nil, Flags.IDS.FLAG_HIDE_POKEDEX, true)
      end
      local species = tonumber(mod.save:get("firered_starter"))
      local taken = { [species] = true }
      if species == 1 then taken[4] = true
      elseif species == 4 then taken[7] = true
      elseif species == 7 then taken[1] = true end
      local ballFlags = {
        [1] = "FLAG_HIDE_BULBASAUR_BALL",
        [4] = "FLAG_HIDE_CHARMANDER_BALL",
        [7] = "FLAG_HIDE_SQUIRTLE_BALL",
      }
      for speciesId, flagName in pairs(ballFlags) do
        local flag = Flags.IDS[flagName]
        if flag then Flags.setFlag(Space.store, nil, flag, taken[speciesId] == true) end
      end
    end

    return result
  end)
end
