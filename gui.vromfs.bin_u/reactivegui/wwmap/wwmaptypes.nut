let zoneSideType = {
  SIDE_NONE = 0
  SIDE_1 = 1
  SIDE_2 = 2
  SIDE_3 = 3
}

let zoneSideTypeStr = [
  "SIDE_NONE",
  "SIDE_1",
  "SIDE_2",
  "SIDE_3"
]

let zoneStatusTypes = [
  { mask = 1, type = "highlighted", order = 0, color = "highlightedZonesGridColor0"},
  { mask = 2, type = "highlighted", order = 1, color = "highlightedZonesGridColor1"},
  { mask = 4, type = "highlighted", order = 2, color = "highlightedZonesGridColor2"},
  { mask = 8, type = "highlighted", order = 3, color = "highlightedZonesGridColor3"},
  { mask = 16, type = "outlined", color = "outlinedZonesGridColor"},
]

let armyIconByType = {
  UT_AIR = { type = "armyIconAir" }
  UT_GROUND = { type = "armyIconGround" }
  UT_WATER = { type = "armyIconWater" }
  UT_INFANTRY = { type = "armyIconInfantry" }
  UT_ARTILLERY = { type = "armyIconArtillery" }
}

let actionType = {
  AUT_None = -1
  AUT_ArtilleryFire = 0
  AUT_TransportLoad = 1
  AUT_TransportUnload = 2
}

let battleStates = {
  ACTIVE = "Active"
  INACTIVE = "Inactive"
  STARTED = "StartedOnServer"
  FULL = "Full"
  ENDED = "Ended"
  FAKE = "Fake"
}

return {
  zoneSideType
  zoneSideTypeStr
  zoneStatusTypes
  armyIconByType
  actionType
  battleStates
}
