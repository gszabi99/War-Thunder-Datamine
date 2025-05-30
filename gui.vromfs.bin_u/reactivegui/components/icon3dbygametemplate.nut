from "%rGui/globals/ui_library.nut" import *
import "%sqstd/ecs.nut" as ecs

let mkIcon3d = require("%rGui/components/icon3d.nut")
let { getLocalLanguage } = require("language")


function applyHarmonizationImpl(template, objTexReplace, objTexSet) {
  let objTexHarmonize = template.getCompValNullable("animchar__objTexHarmonize")
  if (objTexHarmonize == null)
    return

  objTexReplace.append(objTexHarmonize?["animchar__objTexReplace"]?.getAll() ?? {})
  objTexSet.append(objTexHarmonize?["animchar__objTexSet"]?.getAll() ?? {})
}

let applyHarmonization = getLocalLanguage() == "HChinese" ? applyHarmonizationImpl : @(...) null

let DB = ecs.g_entity_mgr.getTemplateDB()

function mkDecorAnimchar(decor) {
  let animchar = DB.getTemplateByName(decor?.template)?.getCompValNullable("animchar__res")
  return decor.__merge(animchar ? { animchar } : {})
}

function getIconInfoByGameTemplate(template, params = {}) {
  let reassign = @(value, key) key in params ? params[key] : value
  let decorators = template.getCompValNullable("attach_decorators__templates")?.getAll().map(mkDecorAnimchar)

  let objTexReplace = [template.getCompValNullable("animchar__objTexReplace")?.getAll() ?? {}]
  let objTexSet = [template.getCompValNullable("animchar__objTexSet")?.getAll() ?? {}]

  applyHarmonization(template, objTexReplace, objTexSet)

  return {
    iconName = template.getCompValNullable("animchar__res")
    objTexReplace
    objTexSet
    decorators
    iconPitch = reassign(template.getCompValNullable("item__iconPitch"), "itemPitch")
    iconYaw = reassign(template.getCompValNullable("item__iconYaw"), "itemYaw")
    iconRoll = reassign(template.getCompValNullable("item__iconRoll"), "itemRoll")
    iconOffsX = reassign(template.getCompValNullable("item__iconOffset")?.x, "itemOfsX")
    iconOffsY = reassign(template.getCompValNullable("item__iconOffset")?.y, "itemOfsY")
    iconScale = reassign(template.getCompValNullable("item__iconScale"), "itemScale")
    hideNodes = template.getCompValNullable("disableDMParts")?.getAll() ?? []
    paintColor = template.getCompValNullable("paintColor")
    headgenTex0 = template.getCompValNullable("headgen__tex0")
    headgenTex1 = template.getCompValNullable("headgen__tex1")
    blendFactor = template.getCompValNullable("headgen__blendFactor")
    lightZenith = reassign(template.getCompValNullable("item__lightZenith"), "lightZenith")
    lightAzimuth = reassign(template.getCompValNullable("item__lightAzimuth"), "lightAzimuth")
    silhouette = params?.silhouette
  }
}

function icon3dByGameTemplate(gametemplate, params = {}) {
  if (gametemplate == null)
    return null
  let template = DB.getTemplateByName(gametemplate)
  if (template == null)
    return null
  let itemInfo = getIconInfoByGameTemplate(template, params)
  itemInfo.__update(params?.genOverride ?? {})
  return mkIcon3d(itemInfo, params, itemInfo?.iconAttachments)
}

return icon3dByGameTemplate