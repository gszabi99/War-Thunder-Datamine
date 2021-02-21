local iconWidget = require("reactiveGui/editor/components/icon3d.nut")
local function mkIconView(eid){
  if (::ecs.get_comp_val(eid, "animchar.res") != null && ::ecs.get_comp_val(eid, "item.iconYaw") != null) { // it has icon in it most likely!
    local itemParams = Watched(null)
    local iconParams = {width=min(hdpx(256), sh(40)), height=min(hdpx(256), sh(40))}
    local function updateItemParams(){
      local iconOffs = ::ecs.get_comp_val(eid, "item.iconOffset")
      local itemTbl = {
        iconName = ::ecs.get_comp_val(eid, "animchar.res")
        iconYaw = ::ecs.get_comp_val(eid, "item.iconYaw")
        iconPitch = ::ecs.get_comp_val(eid, "item.iconPitch")
        iconRoll = ::ecs.get_comp_val(eid, "item.iconRoll")
        iconScale = ::ecs.get_comp_val(eid, "item.iconScale")
        iconSunZenith = ::ecs.get_comp_val(eid, "item.iconSunZenith")
        iconSunAzimuth = ::ecs.get_comp_val(eid, "item.iconSunAzimuth")
        iconOffsX = iconOffs?.x
        iconOffsY = iconOffs?.y
      }
      itemParams(itemTbl)
    }
    updateItemParams()
    ::gui_scene.setInterval(1, updateItemParams)
    return @(){
      watch = itemParams
      children = iconWidget(itemParams.value, iconParams)
      hplace = ALIGN_CENTER
    }
  }
  return null
}
return mkIconView

