from "%rGui/globals/ui_library.nut" import *
import "%sqstd/ecs.nut" as ecs


let { controlledHeroEid } = require("%rGui/hud/state/controlledHeroEid.nut")
let { find_local_player } = require("%rGui/common_queries.nut")
let { SquadFormationSpreadEnum } = require("%rGui/hud/humanSquad/humanEnums.nut")

let SQUAD_FORMATION_ORDER_ID = "ai/squadFormationOrder"

let savedSquadFormationOrders = mkWatched(persist, SQUAD_FORMATION_ORDER_ID, {})
let DEFAULT_FORMATION = SquadFormationSpreadEnum.ESFN_STANDARD
let squadFormation = Watched(DEFAULT_FORMATION)


function applyNewFormation(_squadEid, formation) {
  
  squadFormation.set(formation)
}

function saveSquadFormation(squadProfileId, formation) {
  savedSquadFormationOrders.mutate(@(v) v[squadProfileId] <- formation)
  
}


let heroSquadEidQuery = ecs.SqQuery("heroSquadEidQuery", {
  comps_ro=[["squad_member__squad", ecs.TYPE_EID]]
})

let squadProfileIdQuery = ecs.SqQuery("squadProfileIdQuery", {
  comps_ro=[["squad__squadProfileId", ecs.TYPE_STRING]]
})

function setSquadFormation(formation) {
  heroSquadEidQuery(controlledHeroEid.value, function(_, comp) {
    let squadEid = comp.squad_member__squad
    applyNewFormation(squadEid, formation)
    squadProfileIdQuery(squadEid, @(_, compPrfl) saveSquadFormation(compPrfl.squad__squadProfileId, formation))
  })
}


function applyFormationOrderOnSpawnSquad(_evt, eid, comp) {
  if (comp.squad__ownerPlayer == ecs.INVALID_ENTITY_ID || comp.squad__ownerPlayer != find_local_player())
    return
  let squadProfileId = comp.squad__squadProfileId

  if (squadProfileId in savedSquadFormationOrders)
    applyNewFormation(eid, savedSquadFormationOrders[squadProfileId])
  else
    squadFormation.set(DEFAULT_FORMATION)
}

ecs.register_es("apply_squad_formation_order_es", {
    [[ecs.EventEntityCreated, ecs.EventComponentsAppear]] = applyFormationOrderOnSpawnSquad
  },
  { comps_ro = [["squad__squadProfileId", ecs.TYPE_STRING], ["squad__ownerPlayer", ecs.TYPE_EID]] },
  { tags = "gameClient" }
)

return {
  setSquadFormation
  squadFormation
  SquadFormationSpreadEnum
}