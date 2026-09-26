-- Alternate Oak intro:
-- choose Bulbasaur, Charmander or Squirtle during Oak's opening speech,
-- immediately receive it (with the normal gift/Pokédex bookkeeping),
-- choose a nickname, name the rival, then receive the Pokédex explanation.
--
-- No starter artwork is bundled here. The preview uses OakSpeech's normal
-- Pokémon sprite resolver, which follows the imported game data and the same
-- sprite override path used by compatible mods.

return function(mod)
  local STARTERS = {
    BULBASAUR = {
      rival = "CHARMANDER",
      flag = "EVENT_CHOSE_BULBASAUR",
      index = 1,
    },
    CHARMANDER = {
      rival = "SQUIRTLE",
      flag = "EVENT_CHOSE_CHARMANDER",
      index = 2,
    },
    SQUIRTLE = {
      rival = "BULBASAUR",
      flag = "EVENT_CHOSE_SQUIRTLE",
      index = 3,
    },
  }

  local function setStarterFlags(game, species)
    local info = STARTERS[species]
    if not info then return end

    local flags = game.save.flags
    flags.EVENT_GOT_STARTER = true
    flags.EVENT_CHOSE_BULBASAUR = nil
    flags.EVENT_CHOSE_CHARMANDER = nil
    flags.EVENT_CHOSE_SQUIRTLE = nil
    flags[info.flag] = true

    flags.EVENT_GOT_POKEDEX = true
    flags.EVENT_OAK_GOT_PARCEL = true
    flags.EVENT_GOT_OAKS_PARCEL = true

    game.save.playerStarter = info.index
    game.save.rivalStarter = STARTERS[info.rival].index
  end

  local function speciesName(game, species)
    local def = game.data.pokemon and game.data.pokemon[species]
    return (def and def.name) or species
  end

  local function receiveStarter(speech, done)
    local game = speech.game
    local species = mod.save:get("starter")
    local info = STARTERS[species]

    if not info then
      done()
      return
    end

    local Commands = require("src.script.Commands")
    local ctx = {
      game = game,
      save = game.save,
      overworld = game.overworld,
    }
    Commands.give_pokemon(ctx, species, 5, true)
    setStarterFlags(game, species)

    local OakSpeech = require("src.ui.OakSpeech")
    local img, flip, trueColor = OakSpeech.resolvePic(
      game, { type = "pokemon", id = species }, speech
    )
    speech.pic = img
    speech.picFlip = flip or false
    speech.picTrueColor = trueColor or false

    require("src.core.Sound").playCry(game.data, species)

    local TextBox = require("src.render.TextBox")
    local NamingScreen = require("src.ui.NamingScreen")
    local mon = game.save.party and game.save.party[1]

    game.stack:push(TextBox.new(
      game,
      game.data.text and game.data.text._OaksLabReceivedMonText
        or ("You received " .. speciesName(game, species) .. "!"),
      function()
        local prompt = ("Would you like to give
your %s a nickname?")
          :format(speciesName(game, species))

        game.stack:push(TextBox.new(game, prompt, nil, {
          choice = function(yes)
            if not yes then
              done()
              return
            end

            game.stack:push(NamingScreen.new(game, {
              title = require("src.core.Strings")("NICKNAME?"),
              maxLen = 10,
              mon = mon,
              onDone = function(name)
                if name and #name > 0 and mon then
                  mon.nickname = name
                end
                done()
              end,
            }))
          end,
        }))
      end
    ))
  end

  mod.hooks:wrap("intro.oak_speech.build", function(next, steps, speech)
    steps = next(steps, speech)

    mod.ui.insertStepAfter(steps, "confirm_player_name", {
      id = "alternate_intro_starter_choice",
      kind = "choice",
      pic = "oak",
      saveKey = "starter",
      text = "Before you leave,
you should have a
POKéMON of your own!\fI have three wonderful
POKéMON here for you.
Which one would you like?",
      choices = { "BULBASAUR", "CHARMANDER", "SQUIRTLE" },
      values = { "BULBASAUR", "CHARMANDER", "SQUIRTLE" },
      tx = 4,
      ty = 4,
      tw = 12,
    })

    mod.ui.insertStepAfter(steps, "alternate_intro_starter_choice", {
      id = "alternate_intro_receive_starter",
      kind = "fn",
      run = receiveStarter,
    })

    mod.ui.insertStepAfter(steps, "confirm_rival_name", {
      id = "alternate_intro_pokedex_request",
      kind = "say",
      pic = "oak",
      text = "I have a request for you.
I want you to help me with
my research.",
    })

    mod.ui.insertStepAfter(steps, "alternate_intro_pokedex_request", {
      id = "alternate_intro_pokedex",
      kind = "say",
      pic = "oak",
      text = "I've given you an invention
of mine, the POKéDEX!\fIt automatically records data
on POKéMON you've seen or
caught! It's a hi-tech
encyclopedia!",
    })

    mod.ui.insertStepAfter(steps, "alternate_intro_pokedex", {
      id = "alternate_intro_pokedex_given",
      kind = "say",
      pic = "oak",
      text = "Take this with you, {PLAYER}!
It will help you on your
journey.",
    })

    mod.ui.insertStepAfter(steps, "alternate_intro_pokedex_given", {
      id = "alternate_intro_pokedex_dream",
      kind = "say",
      pic = "oak",
      text = "To make a complete guide on
all the POKéMON in the world...\fThat was my dream! But, I'm too
old! I can't do it! So, I want
you to fulfill my dream for me!\fGet moving! This is a great
undertaking in POKéMON history!",
    })

    mod.ui.insertStepAfter(steps, "alternate_intro_pokedex_dream", {
      id = "alternate_intro_pokedex_done",
      kind = "fn",
      run = function(stepSpeech, done)
        stepSpeech.game.save.flags.EVENT_GOT_POKEDEX = true
        stepSpeech.game.save.flags.EVENT_OAK_GOT_PARCEL = true
        stepSpeech.game.save.flags.EVENT_GOT_OAKS_PARCEL = true
        done()
      end,
    })

    return steps
  end)

  mod.events:on("intro.oak_speech.answered", function(ev)
    if ev.saveKey ~= "starter" then return end

    local species = ev.value
    if not STARTERS[species] then return end

    mod.save:set("starter", species)

    for _, step in ipairs(ev.speech.steps or {}) do
      if step.id == "alternate_intro_receive_starter" then
        step.pic = { type = "pokemon", id = species }
      end
    end
  end)

  local RIVAL_OBJECT_INDEX = 99

  -- The vanilla Pallet Town Oak encounter starts hidden at (8,5), below
  -- the player's camera, then walks up to the tile immediately below the
  -- player. Reuse that staging for the Rival so this encounter has the same
  -- offscreen entrance rather than popping the Rival into view.
  local function spawnRival(ow, game)
    local NPC = require("src.world.NPC")
    local obj = {
      index = RIVAL_OBJECT_INDEX,
      name = "ALTERNATE_INTRO_RIVAL",
      sprite = "SPRITE_BLUE",
      movement = "STAY",
      range = "UP",
      x = 8,
      y = 5,
    }
    local rival = NPC.new(game.data, ow.map.id, obj)
    rival.stepFrames = ow.player.stepFramesCur or ow.player.stepFrames
    ow.npcPool = ow.npcPool or {}
    table.insert(ow.npcs, rival)
    table.insert(ow.entities, rival)
    ow.npcPool[rival.id] = rival
    return rival
  end

  local function despawnRival(ow, rival)
    if not rival then return end
    if ow.npcPool then ow.npcPool[rival.id] = nil end
    for i = #ow.npcs, 1, -1 do
      if ow.npcs[i] == rival then
        table.remove(ow.npcs, i)
        break
      end
    end
    for i = #ow.entities, 1, -1 do
      if ow.entities[i] == rival then
        table.remove(ow.entities, i)
        break
      end
    end
  end

  local function findPath(fromX, fromY, toX, toY)
    local path = {}
    local xdist = math.abs(toX - fromX)
    local ydist = math.abs(toY - fromY)
    local xdir = toX < fromX and "left" or "right"
    local ydir = toY < fromY and "up" or "down"
    local xprog, yprog = 0, 0

    while xprog < xdist or yprog < ydist do
      if xdist - xprog >= ydist - yprog and xprog < xdist then
        xprog = xprog + 1
        path[#path + 1] = xdir
      else
        yprog = yprog + 1
        path[#path + 1] = ydir
      end
    end

    return path
  end

  local function walkRival(ow, rival, steps, done)
    local i = 0
    local function nextStep()
      i = i + 1
      if not rival or not steps[i] then
        if done then done() end
        return
      end
      ow:scriptMove(rival, steps[i], 1, nextStep)
    end
    nextStep()
  end

  mod.commands:register("alternate_oak_intro:despawn_rival", function(ctx)
    local ow = ctx.overworld
    if not ow then return end
    despawnRival(ow, ow:npcByIndex(RIVAL_OBJECT_INDEX))
  end)

  local function runFirstPalletRivalBattle(game, ow, playerX)
    if ow.runner:isRunning() then return false end

    local flags = game.save.flags or {}
    if flags.MOD_ALTERNATE_INTRO_RIVAL_BATTLE_DONE
        or not flags.MOD_ALTERNATE_INTRO_MOM_GIFT
        or not mod.save:get("starter") then
      return false
    end

    flags.MOD_ALTERNATE_INTRO_RIVAL_BATTLE_DONE = true
    ow.player.facing = "down"

    local rival = spawnRival(ow, game)
    local starter = mod.save:get("starter")
    local rivalSpecies = STARTERS[starter] and STARTERS[starter].rival
    local rivalParty = ({
      SQUIRTLE = 1,
      BULBASAUR = 2,
      CHARMANDER = 3,
    })[rivalSpecies]

    if not rivalParty then
      despawnRival(ow, rival)
      return false
    end

    local rows = {
      { "show_text",
        "{RIVAL}! You're finally out!\\fYou overslept, didn't you?" },
      { "show_text", "_OaksLabRivalIllTakeYouOnText" },
      { "save_end_battle_text",
        "_OaksLabRivalIPickedTheWrongPokemonText" },
      { "start_battle", "trainer", "OPP_RIVAL1", rivalParty },
      { "heal_party" },
      { "alternate_oak_intro:rival_depart" },
      { "play_default_music" },
      { "label", "done" },
    }

    local function beginBattle()
      require("src.core.Music").play(game.data, "Music_MeetRival")
      ow.runner:run(rows, { npc = rival })
    end

    -- Match Pallet Town's vanilla Oak entrance: the Rival is initially
    -- below the visible area, pauses briefly, then walks to the tile below
    -- the player before speaking.
    rival.facing = "up"
    ow.emote = {
      frames = 6,
      npc = nil,
      onDone = function()
        walkRival(
          ow,
          rival,
          findPath(rival.cellX, rival.cellY, playerX, 2),
          function()
            rival.facing = "up"
            beginBattle()
          end
        )
      end,
    }

    return true
  end

  mod.content.map_scripts:register("PALLET_TOWN", {
    onStep = function(game, ow, x, y)
      -- Red's Route 1 exit is y == 1. The encounter is armed only after
      -- Mom's one-time departure scene, so entering the upper exit before
      -- that point remains completely vanilla.
      if y ~= 1 then return false end
      return runFirstPalletRivalBattle(game, ow, x)
    end,
  })

  mod.content.map_scripts:register("REDS_HOUSE_1F", {
    onStep = function(game, ow, x, y)
      local flags = game.save.flags or {}
      if flags.MOD_ALTERNATE_INTRO_MOM_GIFT then return false end
      if not mod.save:get("starter") or not flags.EVENT_GOT_STARTER then
        return false
      end
      if x ~= 5 or y ~= 6 then return false end

      local rows = {
        { "move_npc", 1, "down", 1 },
        { "face_player" },
        { "show_text",
          "Right. All kids leave home
someday. It said so on TV." },
        { "show_text",
          "I've packed some fresh
underwear for you, too.You'll need to be prepared
for your journey!" },
        { "give_item", "POKE_BALL", 10, false },
        { "show_text",
          "{PLAYER} got 10 POKé BALLs!Use them to catch
WILD POKéMON!" },
        { "move_npc", 1, "up", 1 },
        { "set_flag", "MOD_ALTERNATE_INTRO_MOM_GIFT" },
      }

      local mom = ow:npcByIndex(1)
      if not mom then return false end

      ow.runner:run(rows, {
        npc = mom,
      })
      return true
    end,
  })
end
