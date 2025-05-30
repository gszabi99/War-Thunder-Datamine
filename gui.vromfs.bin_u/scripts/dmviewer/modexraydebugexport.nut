from "%scripts/dagui_library.nut" import *
let { format } = require("string")
let { register_command, command } = require("console")
let { object_to_json_string } = require("json")
let { get_wpcost_blk } = require("blkGetters")
let { file } = require("io")
let { getUnitFileName } = require("vehicleModel")
let { DM_VIEWER_NONE, DM_VIEWER_XRAY } = require("hangar")
let { mkpath, file_exists } = require("dagor.fs")
let { get_time_msec } = require("dagor.time")
let { setInterval, clearTimer } = require("dagor.workcycle")
let { eachBlock } = require("%sqstd/datablock.nut")
let { getPartType } = require("%globalScripts/modeXrayLib.nut")
let dmViewer = require("%scripts/dmViewer/dmViewer.nut")

let progressId = "unitsXray"
local loadAllItemsProgress = null
let onFinishActions = []

let msToTimeStr = @(ms) format("%02dm%02ds", ms / 60000, (ms % 60000) / 1000)

function collectItemInfo(unitName, partsWhitelist) {
  dmViewer.updateUnitInfo(unitName)
  let damagePartsBlk = dmViewer.unitBlk?.DamageParts
  let partNames = []
  eachBlock(damagePartsBlk, function(partsBlk) {
    eachBlock(partsBlk, function(pBlk) {
      let partName = pBlk.getBlockName()
      if (partsWhitelist != null && partsWhitelist.findindex(@(v) partName.startswith(v)) == null)
        return
      if (!partNames.contains(partName))
        partNames.append(partName)
    })
  })
  partNames.sort()

  let res = {}
  foreach (name in partNames) {
    let partType = getPartType(name, dmViewer.xrayRemap)
    let { title, desc } = dmViewer.getPartTooltipInfo(partType, { name })
    if (title == partType && desc.len() == 0)
      continue
    let descText = "\n".join(desc.map(@(v) ("value" not in v) ? v
      : ("topValue" in v) ? $"{v.value} (★ {v.topValue})"
      : v.value))
    res[name] <- "\n".join([ title, descText ], true)
  }
  return res.len() ? res : null
}

function onFinishLoad() {
  let actions = clone onFinishActions
  onFinishActions.clear()
  if (loadAllItemsProgress == null)
    return
  let { res } = loadAllItemsProgress
  loadAllItemsProgress = null
  foreach(action in actions)
    action(res)
}

function loadNextItems() {
  if (loadAllItemsProgress == null) {
    clearTimer(loadNextItems)
    onFinishLoad()
    return
  }
  let frameStartTimeMs = get_time_msec()
  let { res, todo, params } = loadAllItemsProgress
  let { partsWhitelist, exportStartTimeMs } = params
  let total = res.len() + todo.len()
  while(todo.len() > 0) {
    let i = res.len()
    let prc = (100.0 * i / total).tointeger()
    let passedMs = get_time_msec() - exportStartTimeMs
    let eta = msToTimeStr(max(0, (1.0 * passedMs / (i || 1) * total).tointeger() - passedMs))
    command($"console.progress_indicator {progressId} {i}/{total}{nbsp}({prc}%),{nbsp}ETA:{nbsp}{eta}")

    let unitName = todo.pop()
    let info = collectItemInfo(unitName, partsWhitelist)
    if (info != null)
      res[unitName] <- info
    if (get_time_msec() - frameStartTimeMs >= 10)
      return
  }
  let totalTimeMs = get_time_msec() - exportStartTimeMs
  command($"console.progress_indicator {progressId} Finished{nbsp}{total}{nbsp}items{nbsp}in{nbsp}{msToTimeStr(totalTimeMs)}")
  command($"console.progress_indicator {progressId}")
  clearTimer(loadNextItems)
  onFinishLoad()
}

function loadAllItemsAndDo(params, onFinishCb) {
  onFinishActions.append(onFinishCb)
  if (loadAllItemsProgress != null)
    return
  loadAllItemsProgress = { res = {}, todo = [], params }
  let { unitsWhitelist, unitsBlacklist } = params
  eachBlock(get_wpcost_blk(), function(blk) {
    let unitName = blk.getBlockName()
    if (unitsWhitelist != null && !unitsWhitelist.contains(unitName))
      return
    if (unitsBlacklist?.contains(unitName) ?? false)
      return
    if (!getAircraftByName(unitName)?.isInShop || !file_exists(getUnitFileName(unitName)))
      return
    loadAllItemsProgress.todo.append(unitName)
  })
  setInterval(0.001, loadNextItems)
}

function exportXrayPartsDescs(nullOrPartIdWhitelist = null, nullOrUnitIdWhitelist = null, nullOrUnitIdBlacklist = null) {
  dmViewer.isDebugBatchExportProcess = true
  dmViewer.toggle(DM_VIEWER_XRAY)
  let params = {
    partsWhitelist = nullOrPartIdWhitelist
    unitsWhitelist = nullOrUnitIdWhitelist
    unitsBlacklist = nullOrUnitIdBlacklist
    exportStartTimeMs = get_time_msec()
  }

  loadAllItemsAndDo(params, function(res) {
    dmViewer.isDebugBatchExportProcess = false
    dmViewer.toggle(DM_VIEWER_NONE)

    let filePath = "export/unitsXray.json"
    mkpath(filePath)
    let fp = file(filePath, "wt+")
    fp.writestring(object_to_json_string(res, true))
    fp.close()
  })
}

register_command(exportXrayPartsDescs, "ui.debug.export_xray_parts_descs")
