import "%sqstd/ecs.nut" as ecs
from "%rGui/hud/state/controlledHeroEid.nut" import controlledHeroEid
from "%rGui/common_queries.nut" import find_local_player
from "%rGui/hud/humanSquad/humanEnums.nut" import SquadBehaviourEnum
from "%rGui/globals/ui_library.nut" import *



const SQUAD_BEHAVIOUR_ID = "ai/squadBehaviour"


let savedSquadBehaviours = mkWatched(persist, SQUAD_BEHAVIOUR_ID, {})
let DEFAULT_BEHAVIOUR = SquadBehaviourEnum.ESB_AGGRESSIVE
let squadBehaviour = Watched(DEFAULT_BEHAVIOUR)


function applyNewBehaviour(_squadEid, behaviour) {
  
  squadBehaviour.set(behaviour)
}

function saveSquadBehaviour(squadProfileId, behaviour) {
  savedSquadBehaviours.mutate(@(v) v[squadProfileId] <- behaviour)
  
}


let heroSquadEidQuery = ecs.SqQuery("heroSquadEidQuery", {
  comps_ro=[["squad_member__squad", ecs.TYPE_EID]]
})

let squadProfileIdQuery = ecs.SqQuery("squadProfileIdQuery", {
  comps_ro=[["squad__squadProfileId", ecs.TYPE_STRING]]
})

function setSquadBehaviour(behaviour) {
  heroSquadEidQuery(controlledHeroEid.get(), function(_, comp) {
    let squadEid = comp.squad_member__squad
    applyNewBehaviour(squadEid, behaviour)
    squadProfileIdQuery(squadEid, @(_, squadComp)
      saveSquadBehaviour(squadComp.squad__squadProfileId, behaviour))
  })
}


function applyBehaviourOnSpawnSquad(eid, comp) {
  if (comp.squad__ownerPlayer == ecs.INVALID_ENTITY_ID || comp.squad__ownerPlayer != find_local_player())
    return
  let squadProfileId = comp.squad__squadProfileId

  if (squadProfileId in savedSquadBehaviours.get())
    applyNewBehaviour(eid, savedSquadBehaviours.get()[squadProfileId])
  else
    squadBehaviour.set(DEFAULT_BEHAVIOUR)
}

ecs.register_es("apply_squad_behaviour_on_spawn_es", {
    [[ecs.EventEntityCreated, ecs.EventComponentsAppear]] = applyBehaviourOnSpawnSquad
  },
  { comps_ro = [["squad__squadProfileId", ecs.TYPE_STRING], ["squad__ownerPlayer", ecs.TYPE_EID]] },
  { tags = "gameClient" }
)

return {
  setSquadBehaviour
  squadBehaviour
  SquadBehaviourEnum
}
