import "%sqStdLibs/helpers/u.nut" as u

let { GUI } = require("%scripts/utils/configs.nut")





let brToTier = {}

function initBrToTierConformity() {
  let brToTierBlk = GUI.get()?.events_br_to_tier_conformity
  if (!brToTierBlk)
    return

  brToTier.clear()
  foreach (p2 in brToTierBlk % "brToTier")
    if (u.isPoint2(p2))
      brToTier[p2.x] <- p2.y.tointeger()
}

function getTierByMaxBr(maxBR) {
  if (brToTier.len() == 0)
    initBrToTierConformity()
  local res = -1
  local foundBr = 0
  foreach (br, tier in brToTier)
    if (br == maxBR)
      return tier
    else if ((br < 0 && !foundBr) || (br > maxBR && (br < foundBr || foundBr <= 0))) {
      foundBr = br
      res = tier
    }
  return res
}

return { getTierByMaxBr }
