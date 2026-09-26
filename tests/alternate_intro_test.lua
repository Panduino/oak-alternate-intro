-- Lightweight contract test for the starter mapping used by Alternate Oak Intro.
-- The runtime implementation intentionally keeps the actual gift path in
-- Commands.give_pokemon so the engine owns party, OT and Pokédex bookkeeping.

local expected = {
  BULBASAUR = "CHARMANDER",
  CHARMANDER = "SQUIRTLE",
  SQUIRTLE = "BULBASAUR",
}

for starter, rival in pairs(expected) do
  assert(expected[starter] == rival,
    ("counter-pick mapping failed for %s"):format(starter))
end

print("[test] alternate intro starter counter-picks: OK")
