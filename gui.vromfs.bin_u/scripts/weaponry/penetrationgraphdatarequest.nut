from "eventbus" import eventbus_send
from "math" import cos, PI

let { graphColorList, getBulletCacheSaveId } = require("%scripts/weaponry/graphCompareBullets/bulletsGraphState.nut")
let { requestArmorPenetrationData } = require("%scripts/weaponry/graphCompareBullets/armorPenetrationDataRequest.nut")

let PENETRATION_ANGLES = [0, 30, 60]
const DEG_TO_RAD = PI / 180.0



let scaleByAngle = @(penetrationData, angle) penetrationData.map(@(p) {
  distance = p.distance
  penetration = p.penetration * cos(angle * DEG_TO_RAD)
})

let mkGraphParams = @(penetrationData) PENETRATION_ANGLES.map(@(angle, idx) {
  angle
  graphColor = graphColorList[idx].int
  graphData = scaleByAngle(penetrationData, angle)
})

let penetrationDataCache = {}
local activeBulletId = null

function sendGraphParams(penetrationData) {
  eventbus_send("update_bullets_penetration_graph_state", { graphData = { graphParams = mkGraphParams(penetrationData) } })
}

function onPenetrationDataReceived(bulletId, res) {
  let { penetrationData = [] } = res
  penetrationDataCache[bulletId] <- penetrationData
  if (activeBulletId != bulletId)
    return
  sendGraphParams(penetrationData)
}

function requestTooltipPenetrationGraphData(bullet) {
  let bulletId = getBulletCacheSaveId(bullet)
  activeBulletId = bulletId

  let cached = penetrationDataCache?[bulletId]
  if (cached != null) {
    sendGraphParams(cached)
    return
  }

  requestArmorPenetrationData(bullet, null, @(res) onPenetrationDataReceived(bulletId, res))
}

function clearActivePenetrationGraphRequest() {
  activeBulletId = null
}

return {
  requestTooltipPenetrationGraphData
  clearActivePenetrationGraphRequest
}
