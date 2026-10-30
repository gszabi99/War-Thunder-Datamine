from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/sqDagui/daguiUtil.nut" import setPopupMenuPosAndAlign, move_mouse_on_child
from "%scripts/options/optionsExt.nut" import set_option, get_option
from "%scripts/options/optionsExtNames.nut" import USEROPT_RANDB_CLUSTERS
from "%scripts/onlineInfo/clustersManagement.nut" import getClusterFullName
from "%sqstd/math.nut" import is_bit_set
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

function checkShowUnstableSelectedMsg(curVal, prevVal, clusterOpt) {
  for (local i = 0; i < clusterOpt.values.len(); ++i)
    if (is_bit_set(curVal, i) && !is_bit_set(prevVal, i) && clusterOpt.items[i].isUnstable) {
      showInfoMsgBox(loc("multiplayer/cluster_connection_unstable"))
      return
    }
}

function getAutoClusterName(opt) {
  let defaultClusters = opt.items.filter(@(c) c.isDefault).map(@(c) c.text)
  return "".concat(loc("options/auto"),
    loc("ui/parentheses/space", { text = ", ".join(defaultClusters) }))
}

class ClustersMenuWnd (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/multiSelectMenu.tpl"
  needVoiceChat = false

  align = ""
  alignObj = null
  callbackOnClose = null

  function getSceneTplView() {
    let clusterOpt = get_option(USEROPT_RANDB_CLUSTERS)
    return {
      value = clusterOpt.value
      list = clusterOpt.items.map(@(item, idx) {
        id = $"cluster_item_{idx}"
        value = idx
        text = item.isAuto ? getAutoClusterName(clusterOpt)
          : getClusterFullName(item.name)
        icon = item.image
        tooltip = item.tooltip
        enable = true
        isHiddenOpt = !item.isVisible
      })
    }
  }

  function initScreen() {
    setPopupMenuPosAndAlign(this.alignObj, this.align,
      this.scene.findObject("main_frame"))
    this.guiScene.applyPendingChanges(false)
    move_mouse_on_child(this.scene.findObject("multi_select"), 0)
  }

  function onChangeValue(obj) {
    let clusterOpt = get_option(USEROPT_RANDB_CLUSTERS)
    let prevVal = clusterOpt.value
    let curVal = obj.getValue()
    if (curVal == prevVal)
      return

    set_option(USEROPT_RANDB_CLUSTERS, curVal, clusterOpt)
    checkShowUnstableSelectedMsg(curVal, prevVal, clusterOpt)
  }

  function onEventClusterChange(_) {
    let clusterOpt = get_option(USEROPT_RANDB_CLUSTERS)
    let listObj = this.scene.findObject("multi_select")
    let prevVal = listObj.getValue()
    let curVal = clusterOpt.value
    if (curVal == prevVal)
      return

    listObj.setValue(curVal)
    checkShowUnstableSelectedMsg(curVal, prevVal, clusterOpt)
  }

  close = function() {
    if (this.callbackOnClose)
      this.callbackOnClose()
    this.goBack()
  }
}

register_gui_handler("ClustersMenuWnd", ClustersMenuWnd)

function openClustersMenuWnd(alignObj, params = {}) {
  let { align = ALIGN.TOP, callbackOnClose = null } = params
  handlersManager.loadHandler(ClustersMenuWnd, { alignObj, align, callbackOnClose })
}

return openClustersMenuWnd
