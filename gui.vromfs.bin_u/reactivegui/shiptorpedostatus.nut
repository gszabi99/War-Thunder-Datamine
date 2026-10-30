from "%rGui/shipState.nut" import torpedoStatesTrigger
from "%rGui/shipMultiRailWeaponStatus.nut" import mkMultiRailWeaponsStatus

let { torpedoStates } = require("%rGui/shipState.nut")

const torpedoRowIcon = "!ui/gameuiskin#dmg_ship_torpedo_tubes.svg"

return mkMultiRailWeaponsStatus(torpedoStates, torpedoStatesTrigger, torpedoRowIcon)
