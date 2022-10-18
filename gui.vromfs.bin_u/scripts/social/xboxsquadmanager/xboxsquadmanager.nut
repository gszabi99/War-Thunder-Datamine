let { is_available } = require("%xboxLib/impl/mpa.nut")

if (is_available()) {
  return require("%scripts/social/xboxSquadManager/mpa.nut")
}

return require("%scripts/social/xboxSquadManager/xboxServices.nut")