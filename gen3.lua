return function(mod)
  local Scene = require("src.ui.game3.new_game_scene")
  local Naming = require("src.ui.game3.naming")
  local Pokemon = require("src.core.game3.pokemon")
  local Party = require("src.core.game3.party")
  local FrlgFont = require("src.ui.game3.frlg_font")
  local Audio = require("src.core.game3.audio")
  local Song = require("src.core.game3.song_ids")

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
    self:oakPrint(
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

    Audio.playSe(Song.SE_SELECT)
    pcall(Audio.playCry, row.species, 0)

    self.win.menu = nil
    self._alternateStarterMenu = false
    self:clearDialog()
    self:oakPrint(
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

  Scene.Task_OakSpeech_FadeOutPlayerPic = function(self, t)
    local d = t.data
    if d.picFadeState == 0 then return end
    self:clearTrainerPic()
    if d.timer ~= 0 then
      d.timer = d.timer - 1
      return
    end

    -- FireRed normally changes from the player portrait to the rival
    -- portrait here. Splice the starter sequence at exactly that seam.
    self:loadTrainerPic("oak")
    d.picPosX = 0
    self.coordOffsetX = 0
    self.bg2X = 0
    self:createFadeOutTask(t, 2)
    t.data.timer = 0
    t.func = Scene.Task_AlternateOakStarterIntro
  end

  mod.hooks:wrap("save.new_game", function(next, session)
    session = next(session) or session

    local species = tonumber(mod.save:get("firered_starter"))
    local row = STARTER_BY_SPECIES[species]
    if not row then return session end

    local nickname = mod.save:get("firered_starter_nickname")
    local ok = Party.giveMon(session, row.species, 5, nickname or row.name)
    if not ok then return session end

    -- FireRed's existing script/state machinery uses these values to
    -- choose the rival starter and determine the Oak's Lab scene.
    session.vars = session.vars or {}
    session.vars[0x4031] = row.index
    session.vars[0x4055] = 4

    session.flags = session.flags or {}
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

    return session
  end)
end
