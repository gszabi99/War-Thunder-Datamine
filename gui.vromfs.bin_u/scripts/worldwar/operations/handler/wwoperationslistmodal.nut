//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")


let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getOperationById, getOperationGroupByMapId
} = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { actionWithGlobalStatusRequest,
  setDeveloperMode } = require("%scripts/worldWar/operations/model/wwGlobalStatus.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")


::gui_handlers.WwOperationsListModal <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName   = "%gui/worldWar/wwOperationsListModal.blk"

  map = null
  isDescrOnly = false

  selOperation = null
  isOperationJoining = false
  opListObj = null

  descHandlerWeak = null

  function initScreen() {
    if (!this.map)
      return this.goBack()

    if (hasFeature("WWOperationsList")) {
      setDeveloperMode(true)
      actionWithGlobalStatusRequest("cln_ww_global_status")
    }
    this.opListObj = this.scene.findObject("items_list")
    this.fillOperationList()
  }

  function getOpGroup() {
    return getOperationGroupByMapId(this.map.getId())
  }

  function getSortedOperationsData() {
    let opDataList = u.map(this.getOpGroup().getOperationsList(),
                               function(o) { return { operation = o, priority = o.getPriority() } })

    opDataList.sort(
      @(a, b) b.operation.isAvailableToJoin() <=> a.operation.isAvailableToJoin()
           || b.priority <=> a.priority
           || a.operation.id <=> b.operation.id
    )
    return opDataList
  }

  function getOperationsListView() {
    if (this.isDescrOnly)
      return null

    let sortedOperationsDataList = this.getSortedOperationsData()
    if (!sortedOperationsDataList.len())
      return null

    let view = { items = [] }
    local isActiveChapterAdded = false
    local isFinishedChapterAdded = false
    foreach (_idx, opData in sortedOperationsDataList) {
      let operation = opData.operation
      let isAvailableToJoin = operation.isAvailableToJoin()
      let itemColor = isAvailableToJoin ? "activeTextColor" : "commonTextColor"
      if (isAvailableToJoin) {
        if (!isActiveChapterAdded) {
          view.items.append({
            id = "active_group"
            itemText = colorize(itemColor, loc("worldwar/operation/active"))
            isCollapsable = true
          })
          isActiveChapterAdded = true
        }
      }
      else if (!isFinishedChapterAdded) {
        view.items.append({
          id = "finished_group"
          itemText = colorize(itemColor, loc("worldwar/operation/finished"))
          isCollapsable = true
        })
        isFinishedChapterAdded = true
      }

      local icon = null

      local isLastPlayed = false
      if (operation.isMyClanParticipate())
        icon = ::g_world_war.myClanParticipateIcon
      else if (operation.isLastPlayed()) {
        icon = ::g_world_war.lastPlayedIcon
        isLastPlayed = true
      }

      view.items.append({
        itemIcon = icon
        id = operation.id.tostring()
        itemText = colorize(itemColor, operation.getNameText(false))
        isLastPlayedIcon = isLastPlayed
      })
    }

    return view
  }

  function fillOperationList() {
    let view = this.getOperationsListView()
    let isOperationListVisible = view != null
    this.showSceneBtn("chapter_place", isOperationListVisible)
    this.showSceneBtn("separator_line", isOperationListVisible)
    let data = handyman.renderCached("%gui/worldWar/wwOperationsMapsItemsList.tpl", view)
    this.guiScene.replaceContentFromText(this.opListObj, data, data.len(), this)

    this.selectFirstItem(this.opListObj)
  }

  function selectFirstItem(containerObj) {
    for (local i = 0; i < containerObj.childrenCount(); i++) {
      let itemObj = containerObj.getChild(i)
      if (!itemObj?.collapse_header && itemObj.isEnabled()) {
        this.selOperation = null //force refresh description
        containerObj.setValue(i)
        break
      }
    }
    this.onItemSelect()
  }

  function refreshSelOperation() {
    let idx = this.opListObj.getValue()
    if (idx < 0 || idx >= this.opListObj.childrenCount())
      return false
    let opObj = this.opListObj.getChild(idx)
    if (!checkObj(opObj))
      return false

    let newOperation = opObj?.collapse_header ? null
      : getOperationById(::to_integer_safe(opObj?.id))
    if (newOperation == this.selOperation)
      return false
    let isChanged = !newOperation || !this.selOperation || !this.selOperation.isEqual(newOperation)
    this.selOperation = newOperation
    return isChanged
  }

  function onCollapse(obj) {
    if (!checkObj(obj))
      return

    let headerObj = obj.getParent()
    if (checkObj(headerObj))
      this.doCollapse(headerObj)
  }

  function onCollapsedChapter() {
    let rowObj = this.opListObj.getChild(this.opListObj.getValue())
    if (checkObj(rowObj))
      this.doCollapse(rowObj)
  }

  function doCollapse(obj) {
    let containerObj = obj.getParent()
    if (!checkObj(containerObj))
      return

    obj.collapsing = "yes"

    let containerLen = containerObj.childrenCount()
    local isHeaderFound = false
    let isShow = obj?.collapsed == "yes"
    let selectIdx = containerObj.getValue()
    local needReselect = false

    for (local i = 0; i < containerLen; i++) {
      let itemObj = containerObj.getChild(i)
      if (!isHeaderFound) {
        if (itemObj?.collapsing == "yes") {
          itemObj.collapsing = "no"
          itemObj.collapsed = isShow ? "no" : "yes"
          isHeaderFound = true
        }
      }
      else {
        if (itemObj?.collapse_header)
          break
        itemObj.show(isShow)
        itemObj.enable(isShow)
        if (!isShow && i == selectIdx)
          needReselect = true
      }
    }

    let selectedObj = containerObj.getChild(containerObj.getValue())
    if (needReselect || (checkObj(selectedObj) && !selectedObj.isVisible()))
      this.selectFirstItem(containerObj)

    this.updateButtons()
  }

  //operation select
  _wasSelectedOnce = false
  function onItemSelect() {
    if (!this.refreshSelOperation() && this._wasSelectedOnce)
      return this.updateButtons()

    this._wasSelectedOnce = true

    this.updateWindow()
  }

  function updateWindow() {
    this.updateTitle()
    this.updateDescription()
    this.updateButtons()
  }

  function updateTitle() {
    let titleObj = this.scene.findObject("wnd_title")
    if (!checkObj(titleObj))
      return

    titleObj.setValue(this.selOperation ?
      this.selOperation.getNameText() : this.map.getNameText())
  }

  function updateDescription() {
    if (this.descHandlerWeak)
      return this.descHandlerWeak.setDescItem(this.selOperation)

    let handler = ::gui_handlers.WwMapDescription.link(this.scene.findObject("item_desc"), this.selOperation, this.map)
    this.descHandlerWeak = handler.weakref()
    this.registerSubHandler(handler)
  }

  function updateButtons() {
    ::showBtn("operation_join_block", this.selOperation, this.scene)

    if (!this.selOperation) {
      let isListEmpty = this.opListObj.getValue() < 0
      let collapsedChapterBtnObj = ::showBtn("btn_collapsed_chapter", !isListEmpty, this.scene)
      if (!isListEmpty && collapsedChapterBtnObj != null) {
        let rowObj = this.opListObj.getChild(this.opListObj.getValue())
        if (rowObj?.isValid())
          collapsedChapterBtnObj.setValue(rowObj?.collapsed == "yes"
            ? loc("mainmenu/btnExpand")
            : loc("mainmenu/btnCollapse"))
      }

      let operationDescText = this.scene.findObject("operation_short_info_text")
      operationDescText.setValue(this.getOpGroup().getOperationsList().len() == 0
        ? loc("worldwar/msg/noActiveOperations")
        : "")
      return
    }

    foreach (side in ::g_world_war.getCommonSidesOrder()) {
      let cantJoinReasonData = this.selOperation.getCantJoinReasonDataBySide(side)

      let sideName = ::ww_side_val_to_name(side)
      let joinBtn = this.scene.findObject("btn_join_" + sideName)
      joinBtn.inactiveColor = cantJoinReasonData.canJoin ? "no" : "yes"
      joinBtn.findObject("is_clan_participate_img").show(this.selOperation.isMyClanSide(side))

      let joinBtnFlagsObj = joinBtn.findObject("side_countries")
      if (checkObj(joinBtnFlagsObj)) {
        let wwMap = this.selOperation.getMap()
        let markUpData = wwMap.getCountriesViewBySide(side, false)
        this.guiScene.replaceContentFromText(joinBtnFlagsObj, markUpData, markUpData.len(), this)
      }
    }
  }

  function onCreateOperation() {
    this.goBack()
    ::ww_event("CreateOperation")
  }

  function onJoinOperationSide1() {
    if (this.selOperation)
      this.joinOperationBySide(SIDE_1)
  }

  function onJoinOperationSide2() {
    if (this.selOperation)
      this.joinOperationBySide(SIDE_2)
  }

  function joinOperationBySide(side) {
    if (this.isOperationJoining)
      return

    let reasonData = this.selOperation.getCantJoinReasonDataBySide(side)
    if (reasonData.canJoin) {
      this.isOperationJoining = true
      return this.selOperation.join(reasonData.country)
    }

    ::scene_msg_box(
      "cant_join_operation",
      null,
      reasonData.reasonText,
      [["ok", function() {}]],
      "ok"
    )
  }

  function onEventWWStopWorldWar(_params) {
    this.isOperationJoining = false
  }

  function onEventWWGlobalStatusChanged(p) {
    if (p.changedListsMask & WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS)
      this.fillOperationList()
  }

  function onEventQueueChangeState(_params) {
    this.updateButtons()
  }

  function onModalWndDestroy() {
    base.onModalWndDestroy()
    ::ww_stop_preview()
    setDeveloperMode(false)
  }
}
