from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { disableSeenUserlogs } = require("%scripts/userLog/userlogUtils.nut")
let { format } = require("string")

const SKIP_CLAN_FLUSH_EXP_INFO_SAVE_ID = "skipped_msg/clanFlushExpInfo"

let handlerClass = class extends ::gui_handlers.clanVehiclesModal
{
  sceneTplName  = "%gui/clans/clanFlushExpInfoModal"
  maxSlotCountY = 2
  userlog = null
  needChoseResearch = true

  unitsFilter = @(u) u.isVisibleInShop() && u.isSquadronVehicle()
    && ::canResearchUnit(u) && u.name != userlog.body.unit

  function getSceneTplView() {
    canQuitByGoBack = !needChoseResearch
    let flushExpText = "".concat(loc("userlog/clanUnits/flush/desc", {
        unit = ::getUnitName(userlog.body.unit)
        rp = ::Cost().setSap(userlog.body.rp).tostring()
      }),
      needChoseResearch ? $"\n{loc("mainmenu/nextResearchSquadronVehicle")}" : ""
    )
    return base.getSceneTplView().__update({
      flushExpText
      flushExpUnit = getFlushExpUnitView()
    })
  }

  function getFlushExpUnitView() {
    let unit = ::getAircraftByName(userlog.body.unit)
    if (unit == null)
      return ""
    return format("unitItemContainer{id:t='cont_%s' %s}", unit.name,
      ::build_aircraft_item(unit.name, unit, getUnitItemParams(unit)))
  }

  function updateFlushExpUnit() {
    let data = getFlushExpUnitView()
    guiScene.replaceContentFromText(scene.findObject("flush_exp_unit_nest"), data, data.len(), this)
  }

  getWndTitle = @() loc("clan/research_vehicles")

  initPopupFilter = @() null

  function updateButtons() {
    updateBuyBtn()
    updateSpendExpBtn()
    this.showSceneBtn("skip_info", !needChoseResearch)
  }

  function onSkipInfo(obj) {
    ::save_local_account_settings(SKIP_CLAN_FLUSH_EXP_INFO_SAVE_ID, obj.getValue())
  }

  function onUnitActivate(obj)
  {
    openUnitActionsList(obj.findObject(userlog.body.unit), true)
  }

  function onEventUnitBought(p)
  {
    if (p?.unitName == userlog.body.unit) {
      updateFlushExpUnit()
      return
    }

    base.onEventUnitBought(p)
  }

  function goBack() {
    disableSeenUserlogs([userlog.id])
    base.goBack()
  }
}

::gui_handlers.clanFlushExpInfoModal <- handlerClass

return {
  SKIP_CLAN_FLUSH_EXP_INFO_SAVE_ID
  showClanFlushExpInfo = @(p) ::handlersManager.loadHandler(handlerClass, p)
}
