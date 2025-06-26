from "%scripts/dagui_library.nut" import *
let { get_ranks_blk } = require("blkGetters")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

let cachedBonusTooltips = {}

function getSkillBonusTooltipText(eventName) {
  if (cachedBonusTooltips?[eventName])
    return cachedBonusTooltips[eventName]

  let blk = get_ranks_blk()
  let bonuses = blk?.ExpSkillBonus[eventName]
  if (!bonuses)
    return ""
  let icon = loc("currency/researchPoints/sign/colored")

  local text = "".concat(loc("debrifieng/SkillBonusHintTitle"))
  foreach ( bonus in bonuses ) {
    let isBonusForKills = bonus?.kills != null
    let hintLoc = isBonusForKills ? "debrifieng/SkillBonusHintKills" : "debrifieng/SkillBonusHintDamage"
    let locData = loc(hintLoc, {req = isBonusForKills ? bonus.kills : bonus.damage, val = bonus.bonusPercent})
    text = "".concat( text, "\n\r", $"{locData}{icon}")
  }
  text = "".concat(text,"\n", loc("debrifieng/SkillBonusHintEnding"))
  text = colorize("commonTextColor", text)
  cachedBonusTooltips[eventName] <- text
  return text
}


function getWeaponTypeIcoByWeapon(airName, weapon) {
  let config = {
    bomb            = { icon = "", ratio = 0.375 }
    rocket          = { icon = "", ratio = 0.375 }
    torpedo         = { icon = "", ratio = 0.375 }
    additionalGuns  = { icon = "", ratio = 0.375 }
    mine            = { icon = "", ratio = 0.594 }
  }
  let air = getAircraftByName(airName)
  if (!air)
    return config

  foreach (w in air.getWeapons()) {
    if (w.name != weapon)
      continue

    let isShip = air.isShipOrBoat()
    config.bomb = {
      icon = !w.bomb ? ""
        : isShip ? "#ui/gameuiskin#weap_naval_bomb.svg"
        : "#ui/gameuiskin#weap_bomb.svg"
      ratio = isShip ? 0.594 : 0.375
    }
    config.rocket.icon = w.rocket ? "#ui/gameuiskin#weap_missile.svg" : ""
    config.torpedo.icon = w.torpedo ? "#ui/gameuiskin#weap_torpedo.svg" : ""
    config.additionalGuns.icon = w.additionalGuns ? "#ui/gameuiskin#weap_pod.svg" : ""
    config.mine.icon = w.hasMines ? "#ui/gameuiskin#weap_mine.svg" : ""
    break
  }
  return config
}

addListenersWithoutEnv({
  GameLocalizationChanged = function (_p) {
    cachedBonusTooltips.clear()
  }
})

return {
  getWeaponTypeIcoByWeapon
  getSkillBonusTooltipText
}