local function isGameModeCoop(gm)
{
  return gm == -1 || gm == ::GM_SINGLE_MISSION || gm == ::GM_DYNAMIC || gm == ::GM_BUILDER
}

local function isGameModeVersus(gm)
{
  return gm == -1 || gm == ::GM_SKIRMISH || gm == ::GM_DOMINATION
}

return {
  isGameModeCoop
  isGameModeVersus
}

