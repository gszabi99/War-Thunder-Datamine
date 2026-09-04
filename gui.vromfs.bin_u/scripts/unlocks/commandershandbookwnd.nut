from "%scripts/dagui_library.nut" import *

let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { buildConditionsConfig, getUnlockNameText } = require("%scripts/unlocks/unlocksState.nut")
let { fillReward, fillUnlockManualOpenButton } = require("%scripts/unlocks/unlocksViewModule.nut")
let { isUnlockOpened, findUnusableUnitForManualUnlock } = require("%scripts/unlocks/unlocksModule.nut")
let { openUnlockManually } = require("%scripts/unlocks/unlocksAction.nut")
let { initUnlockFavInContainer, toggleUnlockFavButton } = require("%scripts/unlocks/favoriteUnlocks.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let getNavigationImagesText = require("%scripts/utils/getNavigationImagesText.nut")
let { getAllCmhGroups, getCmhGroupUnlocks, getCmhUnlockProgressData, getCmhGroupCompletedTotal,
  getCurrentCmhGroup, mkCmhUnseenCfg } = require("%scripts/unlocks/commandersHandbookState.nut")

function splitDescVideo(desc) {
  const markerStart = "{{video:"
  const markerEnd = "}}"
  const markerStartLen = markerStart.len()
  const markerEndLen = markerEnd.len()

  let vStart = desc.indexof(markerStart)
  if (vStart == null)
    return { descBefore = desc.strip(), videoPath = "", descAfter = "" }
  let vEnd = desc.indexof(markerEnd, vStart)
  if (vEnd == null)
    return { descBefore = desc.strip(), videoPath = "", descAfter = "" }

  return {
    descBefore = desc.slice(0, vStart).strip()
    videoPath = desc.slice(vStart + markerStartLen, vEnd)
    descAfter = desc.slice(vEnd + markerEndLen).strip()
  }
}

let CommandersHandbookWnd = class (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/modalSceneWithGamercard.blk"
  sceneTplName = "%gui/unlocks/commandersHandbookWnd.tpl"

  openGroup = null

  groups = null
  selectedGroup = null
  curUnlockId = null

  getSceneTplContainerObj = @() this.scene.findObject("root-box")

  function getSceneTplView() {
    this.groups = getAllCmhGroups()
    let groupsCount = this.groups.len()
    let tabs = this.groups.map(@(g, idx) {
      id = $"cmh_tab_{g}"
      tabName = loc($"unlocks/group/{g}")
      unseenIcon = mkCmhUnseenCfg(getCmhGroupUnlocks(g).map(@(u) u.id))
      navImagesText = getNavigationImagesText(idx, groupsCount)
    })
    return { tabs = handyman.renderCached("%gui/frameHeaderTabs.tpl", { tabs }) }
  }

  function initScreen() {
    let startGroup = this.openGroup ?? getCurrentCmhGroup()
    let startIdx = (startGroup != null ? this.groups.indexof(startGroup) : null) ?? 0
    this.scene.findObject("cmh_tabs").setValue(startIdx)
  }

  function onSelectGroup(obj) {
    let idx = obj.getValue()
    if (idx < 0 || idx >= this.groups.len())
      return
    this.selectedGroup = this.groups[idx]
    this.fillUnlockList()
  }

  
  getActiveIdInGroup = @(unlocks) unlocks.findvalue(@(u) !isUnlockOpened(u.id))?.id

  function fillUnlockList(selectId = null) {
    let unlocks = getCmhGroupUnlocks(this.selectedGroup)
    let activeId = this.getActiveIdInGroup(unlocks)
    let items = unlocks.map(function(blk) {
      let isDone = isUnlockOpened(blk.id)
      return {
        id = blk.id
        name = getUnlockNameText(-1, blk.id)
        isDone
        isActive = !isDone && blk.id == activeId
        isLocked = !isDone && blk.id != activeId
        unseenIcon = mkCmhUnseenCfg(blk.id)
      }
    })
    let data = handyman.renderCached("%gui/unlocks/commandersHandbookListItem.tpl", { items })
    let listObj = this.scene.findObject("cmh_list")
    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)
    this.updateGroupProgress()

    if (listObj.childrenCount() == 0) {
      this.fillDetail(null)
      return
    }
    let targetId = selectId ?? activeId
    let selIdx = (targetId != null ? unlocks.findindex(@(u) u.id == targetId) : null) ?? 0
    listObj.setValue(selIdx)
  }

  function updateGroupProgress() {
    let { completed, total } = getCmhGroupCompletedTotal(this.selectedGroup)
    this.scene.findObject("cmh_group_count")
      .setValue($"{completed} / {total}")
    this.scene.findObject("cmh_group_progress")
      .setValue(total > 0 ? (1000 * completed / total) : 0)
  }

  function onSelectUnlock(obj) {
    let idx = obj.getValue()
    if (idx < 0 || idx >= obj.childrenCount())
      return
    this.fillDetail(obj.getChild(idx)?.unlockId)
  }

  function fillDetail(unlockId) {
    let detailObj = this.scene.findObject("cmh_detail")
    let blk = unlockId != null ? getUnlockById(unlockId) : null
    if (blk == null) {
      this.guiScene.replaceContentFromText(detailObj, "", 0, this)
      return
    }

    this.curUnlockId = unlockId
    let cfg = buildConditionsConfig(blk)
    let progress = getCmhUnlockProgressData(blk)
    let unlocks = getCmhGroupUnlocks(this.selectedGroup)
    let num = (unlocks.findindex(@(u) u.id == unlockId) ?? 0) + 1

    let descKey = $"{unlockId}/descFull"
    let { descBefore, videoPath, descAfter } = splitDescVideo(loc(descKey))

    let isDone = isUnlockOpened(unlockId)
    let isActive = !isDone && unlockId == this.getActiveIdInGroup(unlocks)

    let requirements = "\n".join([progress.mainCond, progress.condsDesc], true)

    let view = {
      assignment = loc("unlocks/cmh/assignment", { num, total = unlocks.len() })
      title = getUnlockNameText(-1, unlockId)
      requirements
      curVal = progress.curVal
      maxVal = progress.maxVal
      hasProgress = progress.hasProgress
      hasFavButton = isActive
      descBefore
      hasVideo = videoPath != ""
      videoPath
      hasDescAfter = descAfter != ""
      descAfter
    }
    let data = handyman.renderCached("%gui/unlocks/commandersHandbookWndDetail.tpl", { items = [view] })
    this.guiScene.replaceContentFromText(detailObj, data, data.len(), this)

    fillReward(cfg, detailObj)
    fillUnlockManualOpenButton(cfg, detailObj)
    
    if (isActive)
      initUnlockFavInContainer(unlockId, detailObj)
  }

  function onManualOpenUnlock(obj) {
    let unlockId = obj?.unlockId ?? ""
    if (unlockId == "")
      return

    let unit = findUnusableUnitForManualUnlock(unlockId)
    if (unit) {
      this.msgBox("cantClaimReward", loc("msgbox/cantClaimManualUnlockPrize",
        { unitname = getUnitName(unit) }), [["ok"]], "ok")
      return
    }

    openUnlockManually(unlockId, Callback(@() this.fillUnlockList(unlockId), this))
  }

  unlockToFavorites = toggleUnlockFavButton

  onEventUnlocksCacheInvalidate = @(_p) this.fillUnlockList(this.curUnlockId)
}
register_gui_handler("CommandersHandbookWnd", CommandersHandbookWnd)

return {
  openCommandersHandbookWnd = @(params = {}) loadHandler(CommandersHandbookWnd, params)
}
