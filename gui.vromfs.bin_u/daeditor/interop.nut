from "eventbus" import eventbus_subscribe

let entity_editor = require("entity_editor")
let { callPointActionCallback, handleEntityCreated, handleEntityRemoved,
  handleEntityMoved, edObjectFlagsUpdateTrigger } = require("state.nut")
let { get_point_action_op } = entity_editor


eventbus_subscribe("entity_editor.onEditorChanged", function onEditorChanged(_) {
  local paOp = get_point_action_op()
  if (paOp != "") {
    let mod      = entity_editor?.get_point_action_mod()
    let has_pos  = entity_editor?.get_point_action_has_pos()
    let pos      = entity_editor?.get_point_action_pos()
    let ext_id   = entity_editor?.get_point_action_ext_id()
    let ext_name = entity_editor?.get_point_action_ext_name()
    let ext_mtx  = entity_editor?.get_point_action_ext_mtx()
    let ext_sph  = entity_editor?.get_point_action_ext_sph()
    let ext_eid  = entity_editor?.get_point_action_ext_eid()
    local ev = {
      op = paOp
      mod
      pos = has_pos ? pos : null
      ext_id
      ext_name
      ext_mtx
      ext_sph
      ext_eid
    }
    callPointActionCallback(ev)
  }
})

eventbus_subscribe("entity_editor.onEntityRemoved", function onEntityRemoved(eid) {
  handleEntityRemoved(eid)
})

eventbus_subscribe("entity_editor.onEntityNewBySample", function onEntityNewBySample(eid) {
  handleEntityCreated(eid)
})

eventbus_subscribe("entity_editor.onEntityMoved", function onEntityMoved(eid) {
  handleEntityMoved(eid)
})

eventbus_subscribe("entity_editor.edObjectFlagsUpdateTrigger", function onEdObjectFlagsUpdateTrigger(_) {
  edObjectFlagsUpdateTrigger.modify(@(v) v+1)
})
