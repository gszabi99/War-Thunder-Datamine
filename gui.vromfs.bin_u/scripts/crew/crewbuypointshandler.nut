from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/sqDagui/daguiUtil.nut" import move_mouse_on_child_by_value, move_mouse_on_child
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/crew/crewPointsText.nut" import getCrewSpText
from "%scripts/crew/crew.nut" import getCrewCountry, getCrewButtonRow
from "%scripts/slotbar/crewsList.nut" import getCrewsList
from "%scripts/discounts/discountUtils.nut" import showDiscount
from "%scripts/crew/crewPoints.nut" import getSkillPointsPacks
from "%scripts/crew/crewPointsBuyActions.nut" import buySkillPointsPack
from "string" import format
from "math" import floor
from "%scripts/dagui_library.nut" import *

register_gui_handler("CrewBuyPointsHandler", class (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/emptyFrame.blk"
  sceneTplName = "%gui/crew/crewBuyPoints.tpl"
  buyPointsPacks = null
  crew = null

  function initScreen() {
    this.buyPointsPacks = getSkillPointsPacks(getCrewCountry(this.crew))
    this.scene.findObject("wnd_title").setValue(loc("mainmenu/btnBuySkillPoints"))

    let rootObj = this.scene.findObject("wnd_frame")
    rootObj["class"] = "wnd"
    this.loadSceneTpl()
    move_mouse_on_child(this.scene.findObject("buy_table"), 0)
  }

  function loadSceneTpl() {
    let rows = []
    let price = this.getBasePrice()
    foreach (idx, pack in this.buyPointsPacks) {
      let skills = max(pack.skills, 1)
      let bonusDiscount = price ? floor(100.5 - 100.0 * pack.cost.gold / skills / price) : 0
      let bonusText = bonusDiscount ? format(loc("charServer/entitlement/discount"), bonusDiscount) : ""

      rows.append({
        id = this.getRowId(idx)
        rowIdx = idx
        even = idx % 2 == 0
        skills = getCrewSpText(skills)
        bonusText = bonusText
        cost = pack.cost.tostring()
      })
    }

    let view = { rows = rows }
    let data = handyman.renderCached(this.sceneTplName, view)
    this.guiScene.replaceContentFromText(this.scene.findObject("wnd_content"), data, data.len(), this)

    this.updateRows()
  }

  function updateRows() {
    let tblObj = this.scene.findObject("buy_table")
    foreach (idx, pack in this.buyPointsPacks)
      showDiscount(tblObj.findObject($"buy_discount_{idx}"),
                     "skills", getCrewsList()[this.crew.idCountry].country, pack.name) 
  }

  function getRowId(i) {
    return $"buy_row{i}"
  }

  function getBasePrice() {
    foreach (_idx, pack in this.buyPointsPacks)
      if (pack.cost.gold)
        return pack.cost.gold.tofloat() / max(pack.skills, 1)
    return 0
  }

  function onButtonRowApply(obj) {
    if (!checkObj(obj) || obj?.id != "buttonRowApply") {
      let tblObj = this.scene.findObject("buy_table")
      if (!tblObj?.isValid())
        return
      let idx = tblObj.getValue()
      if (idx < 0 || idx >= tblObj.childrenCount())
        return
      let rowObj = tblObj.getChild(idx)
      if (rowObj?.isValid())
        obj = rowObj.findObject("buttonRowApply")
    }

    if (checkObj(obj))
      this.doBuyPoints(obj)
  }

  function doBuyPoints(obj) {
    let row = getCrewButtonRow(obj, this.scene, this.scene.findObject("buy_table"))
    if (!(row in this.buyPointsPacks))
      return

    buySkillPointsPack(this.crew, this.buyPointsPacks[row],
      Callback(this.goBack, this),
      Callback(@() move_mouse_on_child(this.scene.findObject("buy_table"), row), this))
  }

  function onEventModalWndDestroy(_params) {
    if (this.isSceneActiveNoModals())
      move_mouse_on_child_by_value(this.getObj("buy_table"))
  }
})
