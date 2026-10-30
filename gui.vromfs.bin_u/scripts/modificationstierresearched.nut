import "%sqStdLibs/helpers/u.nut" as u
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler, get_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/money.nut" import Cost
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/unit/unitInfo.nut" import getUnitTypeTextByUnit, getUnitName, getUnitCountry
from "%scripts/options/countryFlagsPreset.nut" import getCountryFlagImg
from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler
from "%scripts/researches/researchActions.nut" import checkNonApprovedResearches
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%scripts/dagui_natives.nut" import shop_get_researchable_module_name
from "%scripts/dagui_library.nut" import *

function guiStartModTierResearched(config) {
  foreach (param, value in config) {
    if (u.isArray(value) && value.len() == 1)
      config[param] = value[0]
  }

  let unit = getAircraftByName(config?.unit)
  if (!unit)
    return

  local wndParams = {
    unit = unit
    unitInResearch = config?.resUnit
    tier = config?.tier ?? []
    expReward = Cost().setRp(config?.expToInvUnit ?? 0)
  }
  loadHandler(get_gui_handler("ModificationsTierResearched"), wndParams)
}

let ModificationsTierResearched = class (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/showUnlock.blk"

  unit = null
  tier = null
  expReward = null
  unitInResearch = null

  function initScreen() {
    if (!this.expReward)
      this.expReward = Cost()

    if (u.isArray(this.unitInResearch))  
      this.unitInResearch = this.unitInResearch[0] 

    let isLastResearchedModule = shop_get_researchable_module_name(this.unit.name) == ""
    local locTextId = "modifications/full_tier_researched"
    if (isLastResearchedModule)
      locTextId = "modifications/full_unit_researched"

    let nameObj = this.scene.findObject("award_name")
    if (checkObj(nameObj))
      nameObj.setValue(loc($"{locTextId}/header"))

    let imgObj = this.scene.findObject("award_image")
    if (checkObj(imgObj)) {
      local imageId = "_".concat(getUnitCountry(this.unit), getUnitTypeTextByUnit(this.unit).tolower())
      if (isLastResearchedModule)
        imageId = $"{imageId}_unit"
      else
        imageId = $"{imageId}_modification"

      local imagePath = getCountryFlagImg(imageId)
      if (imagePath == "")
        imagePath = "".concat(
          "#ui/images/elite_",
          this.unit?.isTank() ? "tank" : "vehicle",
          "_revard?P1"
        )

      imgObj["background-image"] = imagePath
    }

    local tierText = ""
    if (u.isArray(this.tier)) {
      if (this.tier.len() == 1)
        tierText = this.tier.top()
      else if (this.tier.len() == 2)
        tierText = loc("ui/comma").concat(get_roman_numeral(this.tier[0]), get_roman_numeral(this.tier[1]))
      else {
        local maxTier = 0
        local minTier = this.tier.len()
        foreach (t in this.tier) {
          maxTier = max(maxTier, t)
          minTier = min(minTier, t)
        }
        tierText = loc("ui/mdash").concat(get_roman_numeral(minTier), get_roman_numeral(maxTier))
      }
    }
    else
      tierText = get_roman_numeral(this.tier)

    local msgText = loc(locTextId, { tier = tierText, unitName = getUnitName(this.unit) })
    if (!this.expReward.isZero()) {
      msgText = "".concat(
        msgText, "\n", loc("reward"), loc("ui/colon"),
        loc("userlog/open_all_in_tier/resName",
          { resUnitExpInvest = this.expReward.tostring(),
            resUnitName = getUnitName(this.unitInResearch)
          })
      )
    }

    let descObj = this.scene.findObject("award_desc")
    if (checkObj(descObj)) {
      descObj["text-align"] = "center"
      descObj.setValue(msgText)
    }
  }

  function onOk() {
    this.goBack()
  }

  function afterModalDestroy() {
    broadcastEvent("UpdateResearchingUnit", { unitName = this.unitInResearch })
    checkNonApprovedResearches(true)
  }

  function onUseDecorator() {}
  function onUnitActivate() {}
}
register_gui_handler("ModificationsTierResearched", ModificationsTierResearched)

return freeze({
  guiStartModTierResearched
})
