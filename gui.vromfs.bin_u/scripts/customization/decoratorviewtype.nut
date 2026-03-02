from "%scripts/dagui_library.nut" import *

let guidParser = require("%scripts/guidParser.nut")
let { getPlaneBySkinId, getSkinNameBySkinId, isDefaultSkin } = require("%scripts/customization/skinUtils.nut")
let { isEmpty } = require("%sqStdLibs/helpers/u.nut")
let { getUnitName, getUnitCountry } = require("%scripts/unit/unitInfo.nut")
let { getDecorator } = require("%scripts/customization/decoratorGetters.nut")
let { enumsAddTypes, getCachedType } = require("%sqStdLibs/helpers/enums.nut")
let skinLocations = require("%scripts/customization/skinLocations.nut")
let { findItemById } = require("%scripts/items/itemsManagerModule.nut")
let { floor } = require("math")
let { format } = require("string")

let decoratorViewTypes = {
  cache = {
    byUnlockedItemType = {}
    byResourceType= {}
  }
  types = []

  template = {
    unlockedItemType = -1
    resourceType = ""
    categoryPathPrefix = ""
    groupPathPrefix = ""
    getLocName = function(decoratorName, _addUnitName = false) { return loc(decoratorName) }
    getLocDesc = function(decoratorName) { return loc($"{decoratorName}/desc", "") }
    prizeTypeIcon = "#ui/gameuiskin#item_type_unlock.svg"
    getSmallIcon = @(decorator) decorator ? this.prizeTypeIcon : ""
    getImage = function(_decorator) { return "" }
    getImageSize = function(_decorator) { return "0, 0" }
    getRatio = function(_decorator) { return 1 }
    getLocParamsDesc = @(_decorator) ""
    function getTypeDesc(decorator) {
      local text = loc($"trophy/unlockables_names/{this.resourceType}")
      if (decorator.category != "" && this.categoryPathPrefix != "")
        text = "".concat(text, loc("ui/comma"), loc($"{this.categoryPathPrefix}{decorator.category}"))
      if (decorator.group != "" && this.groupPathPrefix != "")
        text = "".concat(text, loc("ui/comma"), loc($"{this.groupPathPrefix}{decorator.group}"))
      return text
    }
  }
}

function addEnumDecoratorViewTypes(types) {
  enumsAddTypes(decoratorViewTypes, types, null, "name")
}

addEnumDecoratorViewTypes({
  UNKNOWN = {}

  FLAGS = {
    unlockedItemType = UNLOCKABLE_SHIP_FLAG
    resourceType = "ship_flag"
    categoryPathPrefix = "flags/category/"
    getLocName = @(decoratorName, ...) loc(getDecorator(decoratorName, this)?.blk.nameLocId ?? "")
    getLocDesc = @(decoratorName) loc(getDecorator(decoratorName, this)?.blk.descLocId ?? "")
    getImage = @(decorator) decorator ? $"@!{decorator.blk.texture}" : ""
    getImageSize = @(_decorator) "256@sf/@pf, 204@sf/@pf"
    getRatio = @(decorator) decorator?.aspect_ratio ?? 0.8
    getTypeDesc = @(_decorator) ""
  }

  DECALS = {
    unlockedItemType = UNLOCKABLE_DECAL
    resourceType = "decal"
    categoryPathPrefix = "decals/category/"
    groupPathPrefix = "decals/group/"
    getLocName = function(decoratorName, ...) { return loc($"decals/{decoratorName}") }
    getLocDesc = function(decoratorName) { return loc($"decals/{decoratorName}/desc", "") }
    prizeTypeIcon = "#ui/gameuiskin#item_type_decal.svg"
    getImage = @(decorator) decorator ? ($"@!{decorator.getTex()}*") : ""
    getImageSize = function(decorator) { return format("256@sf/@pf, %d@sf/@pf", floor(256.0 / this.getRatio(decorator) + 0.5)) }
    getRatio = function(decorator) { return decorator?.aspect_ratio ?? 1 }
  }

  ATTACHABLES= {
    unlockedItemType = UNLOCKABLE_ATTACHABLE
    resourceType = "attachable"
    categoryPathPrefix = "attachables/category/"
    groupPathPrefix = "attachables/group/"
    getLocName = function(decoratorName, ...) { return loc($"attachables/{decoratorName}") }
    getLocDesc = function(decoratorName) { return loc($"attachables/{decoratorName}/desc", "") }
    prizeTypeIcon = "#ui/gameuiskin#item_type_attachable.svg"
    getImage = @(decorator) decorator ? (decorator?.blk.image ?? $"#ui/images/attachables/{decorator.id}") : ""
    getImageSize = function(...) { return "128@sf/@pf, 128@sf/@pf" }
    getLocParamsDesc = function(decorator) {
      let paramPathPrefix = "attachables/param/"
      let angle = decorator.blk?.maxSurfaceAngle
      if (!angle)
        return ""

      return loc($"{paramPathPrefix}maxSurfaceAngle", { value = angle })
    }
  }

  SKINS = {
    unlockedItemType = UNLOCKABLE_SKIN
    resourceType = "skin"
    getLocName = function(decoratorName, addUnitName = false) {
      if (guidParser.isGuid(decoratorName))
        return loc(decoratorName, loc("default_live_skin_loc"))

      local name = ""

      let unitName = getPlaneBySkinId(decoratorName)
      let unit = getAircraftByName(unitName)
      if (unit) {
        let skinNameId = getSkinNameBySkinId(decoratorName)
        let skinBlock = unit.getSkinBlockById(skinNameId)
        if (skinBlock && (skinBlock?.nameLocId ?? "") != "")
          name = loc(skinBlock.nameLocId)
      }

      if (name == "") {
        if (isDefaultSkin(decoratorName))
          decoratorName = loc($"{unitName}/default", loc("default_skin_loc"))

        name = loc(decoratorName)
      }

      if (addUnitName && !isEmpty(unitName))
        name = "".concat(name, loc("ui/parentheses/space", { text = getUnitName(unit) }))

      return name
    }
    getLocDesc = function(decoratorName) {
      let unitName = getPlaneBySkinId(decoratorName)
      let unit = getAircraftByName(unitName)
      if (unit) {
        let skinNameId = getSkinNameBySkinId(decoratorName)
        let skinBlock = unit.getSkinBlockById(skinNameId)
        if (skinBlock && (skinBlock?.descLocId ?? "") != "")
          return loc(skinBlock.descLocId)
      }

      let defaultLocId = guidParser.isGuid(decoratorName) ? "default_live_skin_loc/desc" : "default_skin_loc/desc"
      return loc($"{decoratorName}/desc", loc(defaultLocId))
    }
    prizeTypeIcon = "#ui/gameuiskin#item_type_skin.svg"
    getSmallIcon = function(decorator) {
      if (!decorator)
        return ""
      return $"#ui/gameuiskin#icon_skin_{skinLocations.getIconTypeByMask(skinLocations.getSkinLocationsMaskBySkinId(decorator.id, this))}.svg"
    }
    getImage = function(decorator) {
      if (!decorator)
        return ""

      let item = findItemById(decorator.getCouponItemdefId())
      let itemIconName = (item?.getIconName() ?? "")
      if (itemIconName != "")
        return itemIconName

      let mask = skinLocations.getSkinLocationsMaskBySkinId(decorator.id, this)
      let iconType = skinLocations.getIconTypeByMask(mask)
      let suffix =  iconType == "forest" ? "" : $"_{iconType}"
      return $"#ui/gameuiskin/item_skin{suffix}"
    }
    function getTypeDesc(decorator) {
      let unit = getAircraftByName(getPlaneBySkinId(decorator.id))
      if (!unit)
        return loc("trophy/unlockables_names/skin")
      return "".concat(loc("reward/skin_for"), " ",
        getUnitName(unit), loc("ui/comma"), loc(getUnitCountry(unit)))
    }
  }
})

function getViewTypeByUnlockedItemType(unlockedItemType) {
  return getCachedType("unlockedItemType", unlockedItemType, decoratorViewTypes.cache.byUnlockedItemType, decoratorViewTypes, decoratorViewTypes.UNKNOWN)
}

function getViewTypeByResourceType(resourceType) {
  return getCachedType("resourceType", resourceType, decoratorViewTypes.cache.byResourceType, decoratorViewTypes, decoratorViewTypes.UNKNOWN)
}


return {
  decoratorViewTypes
  getViewTypeByUnlockedItemType
  getViewTypeByResourceType
}