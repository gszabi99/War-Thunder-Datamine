from "%sqstd/ecs.nut" import *
from "state.nut" import selectedEntity, selectedEntities, selectedCompName
from "%darg/ui_imports.nut" import *


selectedEntities.subscribe(function(val) {
  if (val.len() == 1)
    selectedEntity(val.keys()[0])
  else
    selectedEntity(INVALID_ENTITY_ID)
})

selectedEntity.subscribe(function(_eid) {
  selectedCompName(null)
})

let function addEntitySelection(eid, _comp) {
  selectedEntities.mutate(@(val) val[eid] <- true)
}

let function removeEntitySelection(eid, _comp) {
  selectedEntities.mutate(@(val) delete val[eid])
}

register_es("update_selected_entities", {
    onInit = addEntitySelection,
    onDestroy = removeEntitySelection
  },
  { comps_rq = ["daeditor__selected"]}
)
