from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { popupList } = require("%scripts/popups/popupList.nut")
let { setPopupMenuPosAndAlign } = require("%sqDagui/daguiUtil.nut")

let popupTreeList = class(popupList) {
  branches             = null
  onBranchCb           = null
  sceneTplName         = "%gui/popup/popupTreeList.tpl"
  closedBranches       = null

  function getSceneTplView() {
    return {
      branches = this.branches
      underPopupClick    = "hidePopupList"
      underPopupDblClick = "hidePopupList"
      btnWidth = this.btnWidth
      visualStyle = this.visualStyle
      clickPropagation = this.clickPropagation
    }
  }

  function initScreen() {
    let popupListObj = this.scene.findObject("popup_list")
    this.align = setPopupMenuPosAndAlign(this.parentObj, this.align, popupListObj)
    if (this.closedBranches)
      foreach (branchName, _val in this.closedBranches) {
        let obj = popupListObj.findObject(branchName)
        if (obj) {
          obj["isBranchOpened"] = "no"
          obj.findObject("collapse_text").setValue("+")
        }
      }
  }

  function onBranchBtnClick(branchObj) {
    let listBranchObj = branchObj.getParent()
    let isBranchOpened = listBranchObj["isBranchOpened"] == "yes"
    listBranchObj["isBranchOpened"] = isBranchOpened ? "no" : "yes"
    branchObj.findObject("collapse_text").setValue(isBranchOpened ? "+" : "-")
    if (this.onBranchCb)
      this.onBranchCb(listBranchObj)
  }
}

gui_handlers.popupTreeList <- popupTreeList

return {
  openPopupTreeList = @(params = {}) handlersManager.loadHandler(popupTreeList, params)
}
