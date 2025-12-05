from "%rGui/globals/ui_library.nut" import *
let {set_tank_sight_setting, get_tank_sight_highlight_obj, TSI_RANGEFINDER_POS, TSI_TURRET_ORI_POS, TSI_GUN_READY_POS, TSO_TURRET,
  TSO_RANGEFINDER, TSO_GUN_READY, TSO_VERT_DIST, TSI_VERT_DIST_OFFSET, TSO_BULLET_TYPE, get_tank_sight_elem_pos,
  get_tank_sight_elem_size, TSI_BULLET_TYPE_POS} = require("tankSightSettings")
let { Point2, E3DCOLOR } = require("dagor.math")
let { eventbus_subscribe, eventbus_send } = require("eventbus")
let { getDasScriptByPath } = require("%rGui/utils/cacheDasScriptForView.nut")

let getTankSightDas  = @() getDasScriptByPath("%rGui/tankSight.das")

let turretState = Watched({
  pos = [0, 0]
})

let rangefinderState = Watched({
  pos = [0, 0]
})

let gunReadyState = Watched({
  pos = [0, 0]
})

let vertDistState = Watched({
  pos = [0, 0]
  size = const [hdpx(80), hdpx(50)]
})

let bulletTypeState = Watched({
  pos = [0, 0]
})

let highlightedObjectWatch = Watched(0)
eventbus_subscribe("TankSight.HighlightedObjectChanged", @(_) highlightedObjectWatch.trigger())

let highlightColor = E3DCOLOR(255, 76, 255, 255)
let lineWidth = 2.0

function onTankSightReloaded(_) {
  let newTPos = get_tank_sight_elem_pos(TSI_TURRET_ORI_POS)
  turretState.set({pos = [hdpx(newTPos.x), hdpx(newTPos.y)]})
  let newRPos = get_tank_sight_elem_pos(TSI_RANGEFINDER_POS)
  rangefinderState.set({pos = [hdpx(newRPos.x), hdpx(newRPos.y)]})
  let newGPos = get_tank_sight_elem_pos(TSI_GUN_READY_POS)
  gunReadyState.set({pos = [hdpx(newGPos.x), hdpx(newGPos.y)]})
  let newBPos = get_tank_sight_elem_pos(TSI_BULLET_TYPE_POS)
  bulletTypeState.set({pos = [hdpx(newBPos.x), hdpx(newBPos.y)]})
  let newVPos = get_tank_sight_elem_pos(TSI_VERT_DIST_OFFSET)
  let newVSize = get_tank_sight_elem_size(TSO_VERT_DIST)
  vertDistState.set({pos = [sw(50) - newVPos.x, sh(50) - newVPos.y], size = [newVSize.x, newVSize.y]})
}
eventbus_subscribe("onTankSightReloaded", onTankSightReloaded)

function onCrosshairReloaded(_) {
  let newVPos = get_tank_sight_elem_pos(TSI_VERT_DIST_OFFSET)
  let newVSize = get_tank_sight_elem_size(TSO_VERT_DIST)
  vertDistState.set({pos = [sw(50) - newVPos.x, sh(50) - newVPos.y], size = [newVSize.x, newVSize.y]})
}
eventbus_subscribe("onCrosshairReloaded", onCrosshairReloaded)

let mkTankSight = @(isPreviewMode = false)
  {
    size = flex()
    children = [
      {
        size = flex()
        rendObj = ROBJ_DAS_CANVAS
        script = getTankSightDas()
        drawFunc = "draw_inner_fov_elem"
        setupFunc = "setup_data"
        lineWidth
        isPreviewMode
        highlightColor
      }
      @(){
        watch = turretState
        pos = turretState.get().pos
        size = const [hdpx(40), hdpx(70)]
        rendObj = ROBJ_DAS_CANVAS
        script = getTankSightDas()
        drawFunc = "draw_turret_orient_elem"
        setupFunc = "setup_data"
        lineWidth
        isPreviewMode
        highlightColor
        behavior = isPreviewMode ? Behaviors.MoveResize : null
        moveResizeModes = MR_AREA
        onMoveResizeStarted = @(_x, _y, _bbox) eventbus_send("TankSightObjectClick", TSO_TURRET)
        onMoveResize = function(dx, dy, _dw, _dh) {
          let w = turretState.get()
          w.pos = [max(0, min(w.pos[0]+dx, sw(100) - hdpx(40))), max(0, min(w.pos[1]+dy, sh(100) - hdpx(70)))]
          set_tank_sight_setting({param = TSI_TURRET_ORI_POS, value = Point2(w.pos[0], w.pos[1])})
          return w
        }
        onAttach = function() {
          let newPos = get_tank_sight_elem_pos(TSI_TURRET_ORI_POS)
          turretState.set({pos = [hdpx(newPos.x), hdpx(newPos.y)]})
        }
      }
      @(){
        watch = rangefinderState
        pos = rangefinderState.get().pos
        size = const [hdpx(90), hdpx(40)]
        rendObj = ROBJ_DAS_CANVAS
        script = getTankSightDas()
        drawFunc = "draw_rangefinder_elem"
        setupFunc = "setup_data"
        lineWidth
        isPreviewMode
        highlightColor
        behavior = isPreviewMode ? Behaviors.MoveResize : null
        moveResizeModes = MR_AREA
        onMoveResizeStarted = @(_x, _y, _bbox) eventbus_send("TankSightObjectClick", TSO_RANGEFINDER)
        onMoveResize = function(dx, dy, _dw, _dh) {
          let w = rangefinderState.get()
          w.pos = [max(0, min(w.pos[0]+dx, sw(100) - hdpx(90))), max(0, min(w.pos[1]+dy, sh(100) - hdpx(40)))]
          set_tank_sight_setting({param = TSI_RANGEFINDER_POS, value = Point2(w.pos[0], w.pos[1])})
          return w
        }
        onAttach = function() {
          let newPos = get_tank_sight_elem_pos(TSI_RANGEFINDER_POS)
          rangefinderState.set({pos = [hdpx(newPos.x), hdpx(newPos.y)]})
        }
      }
      @(){
        watch = gunReadyState
        pos = gunReadyState.get().pos
        size = const [hdpx(80), hdpx(50)]
        rendObj = ROBJ_DAS_CANVAS
        script = getTankSightDas()
        drawFunc = "draw_reload_progress_elem"
        setupFunc = "setup_data"
        lineWidth
        isPreviewMode
        highlightColor
        behavior = isPreviewMode ? Behaviors.MoveResize : null
        moveResizeModes = MR_AREA
        onMoveResizeStarted = @(_x, _y, _bbox) eventbus_send("TankSightObjectClick", TSO_GUN_READY)
        onMoveResize = function(dx, dy, _dw, _dh) {
          let w = gunReadyState.get()
          w.pos = [max(0, min(w.pos[0]+dx, sw(100) - hdpx(80))), max(0, min(w.pos[1]+dy, sh(100) - hdpx(50)))]
          set_tank_sight_setting({param = TSI_GUN_READY_POS, value = Point2(w.pos[0], w.pos[1])})
          gunReadyState.set(w)
          return w
        }
        onAttach = function() {
          let newPos = get_tank_sight_elem_pos(TSI_GUN_READY_POS)
          gunReadyState.set({pos = [hdpx(newPos.x), hdpx(newPos.y)]})
        }
      }
      @(){
        watch = bulletTypeState
        pos = bulletTypeState.get().pos
        size = const [hdpx(120), hdpx(40)]
        rendObj = ROBJ_DAS_CANVAS
        script = getTankSightDas()
        drawFunc = "draw_bullet_type_elem"
        setupFunc = "setup_data"
        lineWidth
        isPreviewMode
        highlightColor
        behavior = isPreviewMode ? Behaviors.MoveResize : null
        moveResizeModes = MR_AREA
        onMoveResizeStarted = @(_x, _y, _bbox) eventbus_send("TankSightObjectClick", TSO_BULLET_TYPE)
        onMoveResize = function(dx, dy, _dw, _dh) {
          let w = bulletTypeState.get()
          w.pos = [max(0, min(w.pos[0]+dx, sw(100) - hdpx(80))), max(0, min(w.pos[1]+dy, sh(100) - hdpx(50)))]
          set_tank_sight_setting({param = TSI_BULLET_TYPE_POS, value = Point2(w.pos[0], w.pos[1])})
          bulletTypeState.set(w)
          return w
        }
        onAttach = function() {
          let newPos = get_tank_sight_elem_pos(TSI_BULLET_TYPE_POS)
          bulletTypeState.set({pos = [hdpx(newPos.x), hdpx(newPos.y)]})
        }
      }
      isPreviewMode ? @(){
        watch = vertDistState
        pos = vertDistState.get().pos
        size = vertDistState.get().size
        behavior = Behaviors.MoveResize
        moveResizeModes = MR_AREA
        onMoveResizeStarted = @(_x, _y, _bbox) eventbus_send("TankSightObjectClick", TSO_VERT_DIST)
        onMoveResize = function(dx, _dy, _dw, _dh) {
          let w = vertDistState.get()
          w.pos = [max(0, min(w.pos[0]+dx, sw(100) - hdpx(80))), w.pos[1]]
          set_tank_sight_setting({param = TSI_VERT_DIST_OFFSET, value = w.pos[0] - sw(50)})
          vertDistState.set(w)
          return w
        }
        onAttach = function() {
          let newPos = get_tank_sight_elem_pos(TSI_VERT_DIST_OFFSET)
          let newSize = get_tank_sight_elem_size(TSO_VERT_DIST)
          vertDistState.set({pos = [sw(50) - newPos.x, sh(50) + hdpx(newPos.y)], size = [newSize.x, newSize.y]})
        }
        children = [
          function () {
            let isSellected = get_tank_sight_highlight_obj() == TSO_VERT_DIST
            return {
              watch = highlightedObjectWatch
              rendObj = ROBJ_VECTOR_CANVAS
              color = highlightColor
              fillColor = E3DCOLOR(0x00000000)
              size = flex()
              lineWidth = hdpx(lineWidth)
              commands = isSellected ? [
                [VECTOR_RECTANGLE, -50, 0, 150, 100],
              ] : []
            }
          }
        ]
      } : null
    ]
  }

return mkTankSight