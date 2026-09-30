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
        -- Mom's normal position faces left toward the room. Do this only
        -- after she has actually reached the seat.
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

        -- Route back to Mom's normal tile without ever stepping onto the
        -- player's tile. The old axis-by-axis route could walk straight
        -- through the player when the player was between Mom and her seat.
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

    local function showItem(itemText, explanation, fanfare, done)
      Message.show(itemText, {
        npcColor = FrlgFont.NPC_TEXT_COLOR.FEMALE,
        done = function()
          Audio.playFanfare(fanfare)
          Message.show(explanation, {
            npcColor = FrlgFont.NPC_TEXT_COLOR.FEMALE,
            done = function()
              Audio.waitFanfare(done)
            end,
          })
        end,
      })
    end

    local function giveShoes()
      if Flags.IDS.SYS_B_DASH then
        Flags.setFlag(Space.store, nil, Flags.IDS.SYS_B_DASH, true)
      end
      showItem(
        playerName(liveGame) .. " got the RUNNING SHOES!",
        "They let you run while you hold the B Button.",
        "MUS_OBTAIN_ITEM",
        finish
      )
    end

    local function giveTeachyTv()
      Bag.add(session.bag, 366, 1)
      showItem(
        playerName(liveGame) .. " got the TEACHY TV!",
        "You can use it if you need help.",
        "MUS_OBTAIN_KEY_ITEM",
        giveShoes
      )
    end

    local function giveMap()
      Bag.add(session.bag, 361, 1)
      if Flags.IDS.EVENT_GOT_TOWN_MAP then
        Flags.setFlag(Space.store, nil, Flags.IDS.EVENT_GOT_TOWN_MAP, true)
      end
      showItem(
        playerName(liveGame) .. " got a TOWN MAP!",
        "It shows the towns and routes you've visited.",
        "MUS_OBTAIN_KEY_ITEM",
        giveTeachyTv
      )
    end

    local function giveBalls()
      Bag.add(session.bag, 4, 10)
      showItem(
        playerName(liveGame) .. " got 10 POKé BALLs!",
        "You can use POKé BALLs to catch wild POKéMON.",
        "MUS_OBTAIN_ITEM",
        giveMap
      )
    end

    local function talk()
      local px = tonumber(Player.cellX) or 10
      local py = tonumber(Player.cellY) or 3
      local mx = tonumber(handle.cellX) or 8
      local my = tonumber(handle.cellY) or 4

      local function facePlayer()
        -- Face based on Mom's actual final position, not the position she
        -- started the movement from.
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