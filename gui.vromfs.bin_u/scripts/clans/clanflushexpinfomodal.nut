from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { saveLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")
let { disableSeenUserlogs } = require("%scripts/userLog/userlogUtils.nut")
let { format } = require("string")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { canResearchUnit } = require("%scripts/unit/unitStatus.nut")
let { buildUnitSlot } = require("%scripts/slotbar/slotbarView.nut")

const SKIP_CLAN_FLUSH_EXP_INFO_SAVE_ID = "skipped_msg/clanFlushExpInfo"

let handlerClass = class (gui_handlers.clanVehiclesModal) {
  sceneTplName  = "%gui/clans/clanFlushExpInfoModal.tpl"
  maxSlotCountY = 2
  userlog = null
  needChoseResearch = true

  unitsFilter = @(u) u.isVisibleInShop() && u.isSquadronVehicle()
    && canResearchUnit(u) && u.name != this.userlog.body.unit

  function getSceneTplView() {
    this.canQuitByGoBack = !this.needChoseResearch
    let flushExpText = "".concat(loc("userlog/clanUnits/flush/desc", {
        unit = getUnitName(this.userlog.body.unit)
        rp = Cost().setSap(this.userlog.body.rp).tostring()
      }),
      this.needChoseResearch ? $"\n{loc("mainmenu/nextResearchSquadronVehicle")}" : ""
    )
    return base.getSceneTplView().__update({
      flushExpText
      flushExpUnit = this.getFlushExpUnitView()
    })
  }

  function getFlushExpUnitView() {
    let unit = getAircraftByName(this.userlog.body.unit)
    if (unit == null)
      return ""
    return format("unitItemContainer{id:t='cont_%s' %s}", unit.name,
      buildUnitSlot(unit.name, unit, this.getUnitItemParams(unit)))
  }

  function updateFlushExpUnit() {
    let data = this.getFlushExpUnitView()
    this.guiScene.replaceContentFromText(this.scene.findObject("flush_exp_unit_nest"), data, data.len(), this)
  }

  getWndTitle = @() loc("clan/research_vehicles")

  initPopupFilter = @() null

  function updateButtons() {
    this.updateBuyBtn()
    this.updateSpendExpBtn()
    showObjById("skip_info", !this.needChoseResearch, this.scene)
  }

  function onSkipInfo(obj) {
    saveLocalAccountSettings(SKIP_CLAN_FLUSH_EXP_INFO_SAVE_ID, obj.getValue())
  }

  function onUnitActivate(obj) {
    this.openUnitActionsList(obj.findObject(this.userlog.body.unit), true)
  }

  function onEventUnitBought(p) {
    if (p?.unitName == this.userlog.body.unit) {
      this.updateFlushExpUnit()
      return
    }

    base.onEventUnitBought(p)
  }

  function goBack() {
    disableSeenUserlogs([this.userlog.id])
    base.goBack()
  }
}

gui_handlers.clanFlushExpInfoModal <- handlerClass

return {
  SKIP_CLAN_FLUSH_EXP_INFO_SAVE_ID
  showClanFlushExpInfo = @(p) loadHandler(handlerClass, p)
}
