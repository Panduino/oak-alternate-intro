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
        local prompt = ("Would you like to give\nyour %s a nickname?")
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
      text = "Before you leave,\nyou should have a\nPOKéMON of your own!\fI have three wonderful\nPOKéMON here for you.\nWhich one would you like?",
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
      text = "I have a request for you.\nI want you to help me with\nmy research.",
    })

    mod.ui.insertStepAfter(steps, "alternate_intro_pokedex_request", {
      id = "alternate_intro_pokedex",
      kind = "say",
      pic = "oak",
      text = "I've given you an invention\nof mine, the POKéDEX!\fIt automatically records data\non POKéMON you've seen or\ncaught! It's a hi-tech\nencyclopedia!",
    })

    mod.ui.insertStepAfter(steps, "alternate_intro_pokedex", {
      id = "alternate_intro_pokedex_given",
      kind = "say",
      pic = "oak",
      text = "Take this with you, {PLAYER}!\nIt will help you on your\njourney.",
    })

    mod.ui.insertStepAfter(steps, "alternate_intro_pokedex_given", {
      id = "alternate_intro_pokedex_dream",
      kind = "say",
      pic = "oak",
      text = "To make a complete guide on\nall the POKéMON in the world...\fThat was my dream! But, I'm too\nold! I can't do it! So, I want\nyou to fulfill my dream for me!\fGet moving! This is a great\nundertaking in POKéMON history!",
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

  -- This scripted Rival battle uses the same no-blackout behavior as the
  -- vanilla Oak's Lab starter battle. The BattleState check must happen
  -- during BattleState:enter(), before battle.started exists.
  local BattleState = require("src.battle.BattleState")
  local originalIsOaksLabStarterRival = BattleState.isOaksLabStarterRival
  BattleState.isOaksLabStarterRival = function(battle)
    if battle then
      local game = battle.game
      local flags = game and game.save and game.save.flags or {}
      if battle.oppClass == "OPP_RIVAL1"
          and flags.MOD_ALTERNATE_INTRO_RIVAL_BATTLE_DONE
          and BattleState.currentMapId(battle) == "PALLET_TOWN" then
        return true
      end
      if battle.alternateOakIntroCanLose then
        return true
      end
    end
    return originalIsOaksLabStarterRival(battle)
  end

  -- Commands.start_battle calls OverworldState:afterBattle from its
  -- completion callback. Without this matching special case, a loss on
  -- PALLET_TOWN would still trigger the normal blackout/warp even though
  -- BattleState correctly skipped the blackout screen above.
  local OverworldState = require("src.world.OverworldController")
  local originalAfterBattle = OverworldState.afterBattle
  OverworldState.afterBattle = function(ow, result, battle)
    if result == "lose" and battle then
      local game = battle.game
      local flags = game and game.save and game.save.flags or {}
      if battle.oppClass == "OPP_RIVAL1"
          and flags.MOD_ALTERNATE_INTRO_RIVAL_BATTLE_DONE
          and ow.map and ow.map.id == "PALLET_TOWN" then
        return
      end
    end
    return originalAfterBattle(ow, result, battle)
  end

  mod.events:on("battle.started", function(ev)
    local battle = ev and ev.battle
    if not battle or battle.oppClass ~= "OPP_RIVAL1" then return end
    local flags = battle.game and battle.game.save and battle.game.save.flags or {}
    if flags.MOD_ALTERNATE_INTRO_RIVAL_BATTLE_DONE then
      battle.alternateOakIntroCanLose = true

      -- Keep the scripted opening battle gentle even when other mods change
      -- the starters' normal level-up moves. The Rival may only use the
      -- basic attack plus a basic stat-lowering move.
      local starter = mod.save:get("starter")
      local movePair = ({
        BULBASAUR = {
          { id = "TACKLE", pp = 35 },
          { id = "GROWL", pp = 40 },
        },
        CHARMANDER = {
          { id = "SCRATCH", pp = 35 },
          { id = "GROWL", pp = 40 },
        },
        SQUIRTLE = {
          { id = "TACKLE", pp = 35 },
          { id = "LEER", pp = 30 },
        },
      })[starter]

      if movePair and battle.enemy and battle.enemy.mon then
        battle.enemy.mon.moves = movePair
        battle.enemy.curMoves = battle.enemy.mon.moves
      end
    end
  end)

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

  -- Match the vanilla OaksLabRivalStartsExitScript: after the battle the
  -- Rival says his parting line, sidesteps around the player, walks toward
  -- the Route 1 exit, then disappears off the Pallet Town map.
  mod.commands:register("alternate_oak_intro:rival_depart", function(ctx)
    local ow = ctx.overworld
    local rival = ow and ow:npcByIndex(RIVAL_OBJECT_INDEX)
    if not ow or not rival then return end

    local playerX = ow.player.cellX
    local playerY = ow.player.cellY

    -- Pick the side that actually leads into the walkable corridor above
    -- the player. This keeps the Rival from stepping onto the wall when
    -- the player is standing on the left-hand Route 1 exit grass.
    local preferredSide = playerX <= 8 and "right" or "left"
    local sides = { preferredSide, preferredSide == "right" and "left" or "right" }
    local side

    for _, candidate in ipairs(sides) do
      local sideX = playerX + (candidate == "right" and 1 or -1)
      if ow.map:inBounds(sideX, playerY)
          and ow.map:isWalkableCell(sideX, playerY)
          and ow.map:inBounds(sideX, 1)
          and ow.map:isWalkableCell(sideX, 1) then
        side = candidate
        break
      end
    end

    -- Fall back to the original side choice if neither route can be
    -- identified as walkable.
    side = side or preferredSide

    local steps = { side, "up", "up", "up", "up", "up" }
    local runner = ctx.runner
    local i = 0

    local function step()
      i = i + 1
      if not steps[i] then
        despawnRival(ow, rival)
        runner:resume()
        return
      end
      ow:scriptMove(rival, steps[i], 1, step)
    end

    rival.facing = side
    step()
    runner:yield()
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
        "{RIVAL}! You're finally out! You overslept, didn't you?" },
      { "show_text", "_OaksLabRivalIllTakeYouOnText" },
      { "save_end_battle_text",
        "_OaksLabRivalIPickedTheWrongPokemonText" },
      { "start_battle", "trainer", "OPP_RIVAL1", rivalParty },
      { "heal_party" },
      -- The saved end-battle text already handles the Rival's win line on
      -- the battle screen. This shared line is the normal post-battle exit
      -- dialogue and must play after either a win or a loss.
      { "show_text", "OK! I'll make my POKéMON\nfight to toughen it up!\n{PLAYER}! Smell you later!" },
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

  -- The Town Map is now given during Mom's scene, so Daisy should
  -- behave exactly as if she had already handed the map to the player.
  mod.content.map_scripts:register("BLUES_HOUSE", {
    talk = {
      TEXT_BLUESHOUSE_DAISY_SITTING = {
        { "show_text", "_BluesHouseDaisyUseMapText" },
      },
    },
  })

  mod.content.map_scripts:register("REDS_HOUSE_1F", {
    -- Fire as soon as the player enters the first floor from the bedroom,
    -- so the Mom scene cannot be missed while walking off the stairs.
    onEnter = function(game, ow)
      local flags = game.save.flags or {}
      if flags.MOD_ALTERNATE_INTRO_MOM_GIFT then return end
      if not mod.save:get("starter") or not flags.EVENT_GOT_STARTER then
        return
      end

      local mom = ow:npcByIndex(1)
      if not mom then return end

      -- The player is now standing at the bottom of the stairs when this
      -- fires. Walk Mom to the tile directly in front of the player rather
      -- than using her old fixed one-tile movement.
      local originalMomX = mom.cellX
      local originalMomY = mom.cellY
      local targetX = ow.player.cellX
      local targetY = ow.player.cellY + 1
      local momPath = findPath(mom.cellX, mom.cellY, targetX, targetY)
      local returnPath = findPath(targetX, targetY, originalMomX, originalMomY)

      local rows = {
        { "walk_npc", 1, momPath },
        { "face_player" },
        { "show_text",
          "Right. All kids leave home\nsomeday. It said so on TV." },
        { "show_text",
          "I've packed some fresh\nunderwear for you, too.You'll need to be prepared\nfor your journey!" },
        { "give_item", "POKE_BALL", 10, false },
        { "show_text",
          "{PLAYER} got 10 POKé BALLs!Use them to catch\nWILD POKéMON!" },
        { "give_item", "TOWN_MAP", 1, false },
        { "show_text",
          "{PLAYER} got a TOWN MAP!\fIt shows the towns and\ncities of KANTO." },
        { "set_flag", "EVENT_GOT_TOWN_MAP" },
        { "hide_object", "BLUES_HOUSE", "BLUESHOUSE_TOWN_MAP" },
        { "walk_npc", 1, returnPath },
        { "set_flag", "MOD_ALTERNATE_INTRO_MOM_GIFT" },
      }

      ow.runner:run(rows, {
        npc = mom,
      })
    end,
  })
end
