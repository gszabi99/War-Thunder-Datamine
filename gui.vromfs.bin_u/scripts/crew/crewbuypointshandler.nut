from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { floor } = require("math")

::gui_handlers.CrewBuyPointsHandler <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/emptyFrame.blk"
  sceneTplName = "%gui/crew/crewBuyPoints"
  buyPointsPacks = null
  crew = null

  function initScreen()
  {
    buyPointsPacks = ::g_crew_points.getSkillPointsPacks(::g_crew.getCrewCountry(crew))
    this.scene.findObject("wnd_title").setValue(loc("mainmenu/btnBuySkillPoints"))

    let rootObj = this.scene.findObject("wnd_frame")
    rootObj["class"] = "wnd"
    loadSceneTpl()
    ::move_mouse_on_child(this.scene.findObject("buy_table"), 0)
  }

  function loadSceneTpl()
  {
    let rows = []
    let price = getBasePrice()
    foreach(idx, pack in buyPointsPacks)
    {
      let skills = pack.skills || 1
      let bonusDiscount = price ? floor(100.5 - 100.0 * pack.cost.gold / skills / price) : 0
      let bonusText = bonusDiscount ? format(loc("charServer/entitlement/discount"), bonusDiscount) : ""

      rows.append({
        id = getRowId(idx)
        rowIdx = idx
        even = idx % 2 == 0
        skills = ::get_crew_sp_text(skills)
        bonusText = bonusText
        cost = pack.cost.tostring()
      })
    }

    let view = { rows = rows }
    let data = ::handyman.renderCached(sceneTplName, view)
    this.guiScene.replaceContentFromText(this.scene.findObject("wnd_content"), data, data.len(), this)

    updateRows()
  }

  function updateRows()
  {
    let tblObj = this.scene.findObject("buy_table")
    foreach(idx, pack in buyPointsPacks)
      ::showDiscount(tblObj.findObject("buy_discount_" + idx),
                     "skills", ::g_crews_list.get()[crew.idCountry].country, pack.name)
  }

  function getRowId(i)
  {
    return "buy_row" + i
  }

  function getBasePrice()
  {
    foreach(_idx, pack in buyPointsPacks)
      if (pack.cost.gold)
        return pack.cost.gold.tofloat() / (pack.skills || 1)
    return 0
  }

  function onButtonRowApply(obj)
  {
    if (!checkObj(obj) || obj?.id != "buttonRowApply")
    {
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
      doBuyPoints(obj)
  }

  function doBuyPoints(obj)
  {
    let row = ::g_crew.getButtonRow(obj, this.scene, this.scene.findObject("buy_table"))
    if (!(row in buyPointsPacks))
      return

    ::g_crew_points.buyPack(crew, buyPointsPacks[row],
      Callback(this.goBack, this),
      Callback(@() ::move_mouse_on_child(this.scene.findObject("buy_table"), row), this))
  }

  function onEventModalWndDestroy(_params)
  {
    if (this.isSceneActiveNoModals())
      ::move_mouse_on_child_by_value(this.getObj("buy_table"))
  }
}
