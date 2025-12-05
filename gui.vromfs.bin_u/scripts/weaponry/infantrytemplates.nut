from "%scripts/dagui_library.nut" import *

let { getFullUnitBlk } = require("%scripts/unit/unitParams.nut")
let { getTemplateCompValue } = require("%globalScripts/templates.nut")

let infantryTemplates = {}
function getUnitTemplateNames(unit) {
  if (infantryTemplates?[unit.name] != null)
    return infantryTemplates[unit.name]

  let res = {
    mainTemplateName = ""
    unitTemplateName= ""
    primaryWeaponTemplateName = ""
  }

  infantryTemplates[unit.name] <- res

  let fullUnitBlk = getFullUnitBlk(unit.name)
  let templateName = fullUnitBlk?.ecsTemplate ?? ""
  if (templateName == "")
    return res

  res.mainTemplateName = templateName

  let unitTemplateName = templateName.replace("squad_spawner+", "")
  res.unitTemplateName = unitTemplateName

  let unitWeaponTemplateData = getTemplateCompValue(unitTemplateName, "human_weap__weapTemplates")
  if (!unitWeaponTemplateData)
    return res

  res.primaryWeaponTemplateName = unitWeaponTemplateData?["primary"] ?? ""
  return res
}

return {
  getUnitTemplateNames
}