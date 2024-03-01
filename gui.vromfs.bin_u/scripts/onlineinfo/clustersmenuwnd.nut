from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { setPopupMenuPosAndAlign } = require("%sqDagui/daguiUtil.nut")
let { is_bit_set } = require("%sqstd/math.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { set_option } = require("%scripts/options/optionsExt.nut")
let { USEROPT_RANDB_CLUSTERS } = require("%scripts/options/optionsExtNames.nut")
let { getClusterFullName } = require("%scripts/onlineInfo/clustersManagement.nut")

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

let class ClustersMenuWnd (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/multiSelectMenu.tpl"
  needVoiceChat = false

  align = ""
  alignObj = null

  function getSceneTplView() {
    let clusterOpt = ::get_option(USEROPT_RANDB_CLUSTERS)
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
    let clusterOpt = ::get_option(USEROPT_RANDB_CLUSTERS)
    let prevVal = clusterOpt.value
    let curVal = obj.getValue()
    if (curVal == prevVal)
      return

    set_option(USEROPT_RANDB_CLUSTERS, curVal, clusterOpt)
    checkShowUnstableSelectedMsg(curVal, prevVal, clusterOpt)
  }

  function onEventClusterChange(_) {
    let clusterOpt = ::get_option(USEROPT_RANDB_CLUSTERS)
    let listObj = this.scene.findObject("multi_select")
    let prevVal = listObj.getValue()
    let curVal = clusterOpt.value
    if (curVal == prevVal)
      return

    listObj.setValue(curVal)
    checkShowUnstableSelectedMsg(curVal, prevVal, clusterOpt)
  }

  close = @() this.goBack()
}

gui_handlers.ClustersMenuWnd <- ClustersMenuWnd

function openClustersMenuWnd(alignObj, align = ALIGN.TOP) {
  handlersManager.loadHandler(ClustersMenuWnd, { alignObj, align })
}

return openClustersMenuWnd
