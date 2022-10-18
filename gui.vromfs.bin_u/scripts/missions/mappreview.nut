from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

enum MAP_PREVIEW_TYPE {
  MISSION_MAP
  DYNAMIC_SUMMARY
}

//load/unload mission preview depend on visible preview scenes and their modal counter
::g_map_preview <- {
  list = []
  curPreview = null
}

//add or replace (by scene) preview to show.
//obj is scene to check visibility and modal counter (not a obj with tqactical map behavior)
::g_map_preview.setMapPreview <- function setMapPreview(mapObj, missionBlk)
{
  this.setPreview(MAP_PREVIEW_TYPE.MISSION_MAP, mapObj, missionBlk)
}

::g_map_preview.setSummaryPreview <- function setSummaryPreview(mapObj, missionBlk, mapName)
{
  this.setPreview(MAP_PREVIEW_TYPE.DYNAMIC_SUMMARY, mapObj, missionBlk, mapName)
}

::g_map_preview.setPreview <- function setPreview(previewType, mapObj, missionBlk, param = null)
{
  if (!checkObj(mapObj))
    return

  local preview = this.findPreview(mapObj)
  if (preview)
  {
    preview.blk = missionBlk
    preview.param = param
  }
  else
    preview = this.createPreview(previewType, missionBlk, mapObj, param)

  if (preview != this.curPreview)
    preview.show(false)

  this.refreshCurPreview(preview == this.curPreview)
}

::g_map_preview.createPreview <- function createPreview(previewType, missionBlk, mapObj, param)
{
  let preview = {
    type = previewType
    blk = missionBlk
    obj = mapObj
    param = param

    isValid = @() checkObj(obj)
    isEmpty = @() !blk
    isInCurGuiScene = @() obj.getScene().isEqual(::get_cur_gui_scene())
    show = function(shouldShow)
    {
      if (isValid())
        obj.show(shouldShow)
    }
  }
  this.list.append(preview)
  return preview
}

::g_map_preview.findPreview <- function findPreview(obj)
{
  return ::u.search(this.list, (@(obj) function(p) { return checkObj(p.obj) && p.obj.isEqual(obj) })(obj))
}

::g_map_preview.hideCurPreview <- function hideCurPreview()
{
  if (!this.curPreview)
    return
  this.curPreview.show(false)
  ::dynamic_unload_preview()
  this.curPreview = null
}

::g_map_preview.refreshCurPreview <- function refreshCurPreview(isForced = false)
{
  this.validateList()
  let newPreview = getTblValue(0, this.list)
  if (!newPreview || !newPreview.isInCurGuiScene())
  {
    hideCurPreview()
    return
  }

  if (!isForced && newPreview == this.curPreview)
    return

  hideCurPreview()
  this.curPreview = newPreview
  this.curPreview.show(true)
  if (this.curPreview.type == MAP_PREVIEW_TYPE.MISSION_MAP)
    ::dynamic_load_preview(this.curPreview.blk)
  else if (this.curPreview.type == MAP_PREVIEW_TYPE.DYNAMIC_SUMMARY)
    ::dynamic_load_summary(this.curPreview.param, this.curPreview.blk)
}

::g_map_preview.validateList <- function validateList()
{
  for(local i = this.list.len() - 1; i >= 0; i--)
    if (!this.list[i].isValid() || this.list[i].isEmpty())
      this.list.remove(i)


  this.list.sort(function(a, b)
  {
    local res = (b.isInCurGuiScene() ? 1 : 0) - (a.isInCurGuiScene() ? 1 : 0)
    if (!res)
      res = a.obj.getModalCounter() - b.obj.getModalCounter()
    return res
  })
}

::g_map_preview.getMissionBriefingConfig <- function getMissionBriefingConfig(mission)
{
  let config = ::DataBlock()
  let blk = ::g_mislist_type.isUrlMission(mission)
              ? mission.urlMission.getMetaInfo()
              : mission?.blk
  if (!blk)
    return config

  config.load(blk.getStr("mis_file",""))
  return config
}


::g_map_preview.onEventActiveHandlersChanged <- function onEventActiveHandlersChanged(_p) { refreshCurPreview() }

::subscribe_handler(::g_map_preview, ::g_listener_priority.DEFAULT_HANDLER)