from "%scripts/dagui_library.nut" import *

let { getTemplate, getTemplateCompValue } = require("%globalScripts/templates.nut")

let { getModificationsByModClass } = require("%scripts/weaponry/modificationInfo.nut")
let { shopIsModificationEnabled } = require("chardResearch")
let { get_modifications_blk } = require("blkGetters")
let { getFullUnitBlk } = require("%scripts/unit/unitParams.nut")
let { weaponsItem } = require("%scripts/weaponry/weaponryConsts.nut")

const INF_EQUIPMENT_MOD_CLASS = "equipment_common"
const INF_ARMOR_GROUP_NAME = "bulletproof_vest"

const infantryArmorTemplateMainKeyValue = {
  helmet = "helmetProtectionTemplate"
  body = "bodyProtectionTemplate"
}

const infantryArmorTemplateParams = [
  "item__weight"
  "item__armorAmount"
  "item__armorMaterialName"
]

function readTemplateData(templateName) {
  let res = {}
  let template = getTemplate(templateName)
  if (!template)
    return res
  foreach (param in infantryArmorTemplateParams) {
    let value = getTemplateCompValue(templateName, param)
    if (value != null)
      res[param] <- value
  }
  return res
}

function readComplexTemplateData(templateName) {
  let res = {}
  let template = getTemplate(templateName)
  if (!template)
    return res

  res["item__weight"] <- getTemplateCompValue(templateName, "item__weight")

  let armorSegmentsTemplates = getTemplateCompValue(templateName, "segmented_armor__segmentTemplates")
  let armorSegmentsNames = getTemplateCompValue(templateName, "segmented_armor__hudDMAssignment")
  if (!armorSegmentsTemplates || !armorSegmentsNames ||
    armorSegmentsTemplates.len() != armorSegmentsNames.len())
      return res

  res["complex"] <- []
  for (local i = 0; i < armorSegmentsTemplates.len(); i++) {
    if (armorSegmentsNames[i] == "")
      continue
    let armorSegmentTemplateData = readTemplateData(armorSegmentsTemplates[i])
    if (!armorSegmentTemplateData.len())
      continue
    res.complex.append({
      subPartName = armorSegmentsNames[i]
      subPartData = armorSegmentTemplateData
    })
  }

  return res
}

function readArmorTemplatesFromBlk(blk) {
  let res = {}
  foreach (key, value in infantryArmorTemplateMainKeyValue)
    if (blk?[value])
      res[key] <- blk[value]
  return res
}


function getArmorTemplatesDefault(unit) {
  let unitBlk = getFullUnitBlk(unit.name)
  let defaultArmorTemplate = readArmorTemplatesFromBlk(unitBlk)
  if (defaultArmorTemplate.len()) {
    defaultArmorTemplate.isDefaultArmor <- true
    defaultArmorTemplate.image <- unitBlk?.armorDefaultIcon ?? ""
    let templateName = unitBlk?.armorDefaultLangId.split("/").top() ?? "bulletproof_vest_default"
    return { [templateName] = defaultArmorTemplate }
  }
  return { "bulletproof_vest_empty": { isDefaultArmor = true } }
}


function getArmorTemplatesFromModifications(unit) {
  let equipmentMods = getModificationsByModClass(unit, INF_EQUIPMENT_MOD_CLASS)
  let res = {}

  if (!equipmentMods.len())
    return res

  let modificationsBlk = get_modifications_blk()

  foreach (mod in equipmentMods) {
    let modBlock = modificationsBlk?.modifications[mod.name]
    if (!modBlock?.effects || modBlock?.group != INF_ARMOR_GROUP_NAME)
      continue

    let templateData = readArmorTemplatesFromBlk(modBlock.effects)
    templateData["image"] <- modBlock?.image ?? ""
    res[mod.name] <- templateData
  }
  return res
}

function getUnitArmorTemplates(unit) {
  let baseArmorTemplates = getArmorTemplatesDefault(unit)
  let modsArmorTemplates = getArmorTemplatesFromModifications(unit)
  return baseArmorTemplates.__merge(modsArmorTemplates)
}

function getArmorDataByTemplate(template) {
  let armorData = {}
  foreach (key, templateName in template) {
    if (key == "helmet")
      armorData.helmet <- readTemplateData(templateName)
    else if (key == "body")
      armorData.body <- readComplexTemplateData(templateName)
  }
  return armorData
}

let calcArmorWeight = @(armorData) (armorData?.body.item__weight ?? 0) + (armorData?.helmet.item__weight ?? 0)

let unitArmorDataCache = {}

function getUnitArmorData(unit) {
  if (unitArmorDataCache?[unit.name])
    return unitArmorDataCache[unit.name]

  let res = []
  if (!unit?.isHuman())
    return res

  let armorTemplates = getUnitArmorTemplates(unit)
  foreach (templateName, template in armorTemplates) {
    let armorData = getArmorDataByTemplate(template)
    if (armorData)
      res.append({
        name = templateName
        image = template?.image ?? ""
        type = weaponsItem.infantryArmor
        isDefaultArmor = template?.isDefaultArmor ?? false
        armorWeight = calcArmorWeight(armorData)
        armorData
      })
  }
  unitArmorDataCache[unit.name] <- res

  return res.sort(@(a,b) a.armorWeight <=> b.armorWeight)
}

function getAppliedArmorForUnit(unit) {
  local res = null
  let unitArmorData = getUnitArmorData(unit)
  if (!unitArmorData.len())
    return res

  foreach (armData in unitArmorData) {
    if (armData?.isDefaultArmor)
      res = armData
    if (shopIsModificationEnabled(unit.name, armData.name))
      return armData
  }
  return res
}

return {
  getUnitArmorData
  getAppliedArmorForUnit
}