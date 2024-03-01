from "%scripts/dagui_library.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let { g_mislist_type } =  require("%scripts/missions/misListType.nut")
let { dynamicLoadPreview, dynamicUnloadPreview, dynamicLoadSummary } = require("dynamicMission")
let DataBlock = require("DataBlock")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

enum MAP_PREVIEW_TYPE {
  MISSION_MAP
  DYNAMIC_SUMMARY
}

//load/unload mission preview depend on visible preview scenes and their modal counter
let previewList = []
local curPreview = null

function validateList() {
  for (local i = previewList.len() - 1; i >= 0; i--)
    if (!previewList[i].isValid() || previewList[i].isEmpty())
      previewList.remove(i)

  previewList.sort(function(a, b) {
    local res = (b.isInCurGuiScene() ? 1 : 0) - (a.isInCurGuiScene() ? 1 : 0)
    if (!res)
      res = a.obj.getModalCounter() - b.obj.getModalCounter()
    return res
  })
}

function createPreview(previewType, missionBlk, mapObj, param) {
  let preview = {
    type = previewType
    blk = missionBlk
    obj = mapObj
    param = param

    isValid = @() checkObj(this.obj)
    isEmpty = @() !this.blk
    isInCurGuiScene = @() this.obj.getScene().isEqual(get_cur_gui_scene())
    function show(shouldShow) {
      if (this.isValid())
        this.obj.show(shouldShow)
    }
  }
  previewList.append(preview)
  return preview
}

function findPreview(obj) {
  return u.search(previewList, (@(p) checkObj(p.obj) && p.obj.isEqual(obj)))
}

function hideCurPreview() {
  if (!curPreview)
    return
  curPreview.show(false)
  dynamicUnloadPreview()
  curPreview = null
}

function refreshCurPreview(isForced = false) {
  validateList()
  let newPreview = previewList?[0]
  if (!newPreview || !newPreview.isInCurGuiScene()) {
    hideCurPreview()
    return
  }

  if (!isForced && newPreview == curPreview)
    return

  hideCurPreview()
  curPreview = newPreview
  curPreview.show(true)
  if (curPreview.type == MAP_PREVIEW_TYPE.MISSION_MAP)
    dynamicLoadPreview(curPreview.blk)
  else if (curPreview.type == MAP_PREVIEW_TYPE.DYNAMIC_SUMMARY)
    dynamicLoadSummary(curPreview.param, curPreview.blk)
}

function getMissionBriefingConfig(mission) {
  let config = DataBlock()
  let blk = g_mislist_type.isUrlMission(mission)
    ? mission.urlMission.getMetaInfo()
    : mission?.blk
  if (!blk)
    return config

  config.load(blk.getStr("mis_file", ""))
  return config
}

function setPreview(previewType, mapObj, missionBlk, param = null) {
  if (!checkObj(mapObj))
    return

  local preview = findPreview(mapObj)
  if (preview) {
    preview.blk = missionBlk
    preview.param = param
  }
  else
    preview = createPreview(previewType, missionBlk, mapObj, param)

  if (preview != curPreview)
    preview.show(false)

  refreshCurPreview(preview == curPreview)
}

//add or replace (by scene) preview to show.
//obj is scene to check visibility and modal counter (not a obj with tqactical map behavior)
function setMapPreview(mapObj, missionBlk) {
  setPreview(MAP_PREVIEW_TYPE.MISSION_MAP, mapObj, missionBlk)
}

function setSummaryPreview(mapObj, missionBlk, mapName) {
  setPreview(MAP_PREVIEW_TYPE.DYNAMIC_SUMMARY, mapObj, missionBlk, mapName)
}

addListenersWithoutEnv({
  ActiveHandlersChanged = @(_) refreshCurPreview()
})


return {
  setMapPreview
  setSummaryPreview
  getMissionBriefingConfig
}