from "%rGui/globals/ui_library.nut" import *
let tankSightDas = load_das("%rGui/tankSight.das")
let {set_tank_sight_setting, TSI_RANGEFINDER_POS, TSI_TURRET_ORI_POS, TSI_GUN_READY_POS,
 get_tank_sight_elem_pos} = require("tankSightSettings")
let { Point2 } = require("dagor.math")

let turretState = Watched({
  pos = [0, 0]
})

let rangefinderState = Watched({
  pos = [0, 0]
})

let gunReadyState = Watched({
  pos = [0, 0]
})


let mkTankSight = @(isPreviewMode = false)
  {
    size = flex()
    children = [
      {
        size = flex()
        rendObj = ROBJ_DAS_CANVAS
        script = tankSightDas
        drawFunc = "draw_inner_fov_elem"
        setupFunc = "setup_data"
        lineWidth = 2.0
        isPreviewMode
      }
      @(){
        watch = turretState
        pos = turretState.get().pos
        size = [hdpx(40), hdpx(70)]
        rendObj = ROBJ_DAS_CANVAS
        script = tankSightDas
        drawFunc = "draw_turret_orient_elem"
        setupFunc = "setup_data"
        lineWidth = 2.0
        isPreviewMode
        behavior = isPreviewMode ? Behaviors.MoveResize : null
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
        size = [hdpx(90), hdpx(40)]
        rendObj = ROBJ_DAS_CANVAS
        script = tankSightDas
        drawFunc = "draw_rangefinder_elem"
        setupFunc = "setup_data"
        lineWidth = 2.0
        isPreviewMode
        behavior = isPreviewMode ? Behaviors.MoveResize : null
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
        size = [hdpx(80), hdpx(50)]
        rendObj = ROBJ_DAS_CANVAS
        script = tankSightDas
        drawFunc = "draw_reload_progress_elem"
        setupFunc = "setup_data"
        lineWidth = 2.0
        isPreviewMode
        behavior = isPreviewMode ? Behaviors.MoveResize : null
        onMoveResize = function(dx, dy, _dw, _dh) {
          let w = gunReadyState.get()
          w.pos = [max(0, min(w.pos[0]+dx, sw(100) - hdpx(80))), max(0, min(w.pos[1]+dy, sh(100) - hdpx(50)))]
          set_tank_sight_setting({param = TSI_GUN_READY_POS, value = Point2(w.pos[0], w.pos[1])})
          gunReadyState.update(w)
          return w
        }
        onAttach = function() {
          let newPos = get_tank_sight_elem_pos(TSI_GUN_READY_POS)
          gunReadyState.set({pos = [hdpx(newPos.x), hdpx(newPos.y)]})
        }
      }
    ]
  }

return mkTankSight