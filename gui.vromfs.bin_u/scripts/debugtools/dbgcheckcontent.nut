from "%scripts/dagui_natives.nut" import utf8_strlen
from "%scripts/dagui_library.nut" import *
from "app" import is_dev_version
let u = require("%sqStdLibs/helpers/u.nut")




let { getLocalLanguage } = require("language")
let dagor_fs = require("dagor.fs")
let stdpath = require("%sqstd/path.nut")
let skinLocations = require("%scripts/customization/skinLocations.nut")
let { getUnitTooltipImage, getUnitClassIco } = require("%scripts/unit/unitInfoTexts.nut")
let { format, strip } = require("string")
let regexp2 = require("regexp2")
let { register_command } = require("console")
let { debug_get_skyquake_path } = require("%scripts/debugTools/dbgUtils.nut")
let { get_skins_for_unit } = require("unitCustomization")
let { getBestSkinsList } = require("%scripts/customization/skins.nut")
let { utf8ToLower, startsWith, lastIndexOf, replace } = require("%sqstd/string.nut")
let { get_decals_blk, get_current_mission_info_cached } = require("blkGetters")
let DataBlock = require("DataBlock")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { decoratorTypes } = require("%scripts/customization/types.nut")
let { isInFlight } = require("gameplayBinding")
let { is_harmonized_unit_image_required } = require("%scripts/langUtils/harmonized.nut")
let { image_for_air } = require("%scripts/unit/unitInfo.nut")

local skyquakePath = debug_get_skyquake_path()

function debug_check_unlocalized_resources() {
  if (!is_dev_version())
    return

  dlog($"debug_check_unlocalized_resources() // {getLocalLanguage()} // listed in log")
  local count = 0

  
  log("UNITS")
  count = 0
  foreach (unit in getAllUnits())
    if (unit.isInShop)
      foreach (suffix in ["_shop", "_0", "_1", "_2"]) {
        local localeId = $"{unit.name}{suffix}"
        if (loc(localeId, "") == "") {
          log($"    {localeId}")
          count++
        }
      }
  dlog($"{count} units")

  
  log("UNITDESC")
  count = 0
  local placeholder = loc("encyclopedia/no_unit_description")
  foreach (unit in getAllUnits())
    if (unit.isInShop) {
      local localeId = $"encyclopedia/{unit.name}/desc"
      local text = loc(localeId, "")
      if (text == "" || text == placeholder) {
        log($"    {localeId}")
        count++
      }
    }
  dlog($"{count} unitdescs")

  
  log("SKINS")
  count = 0
  foreach (unit in getAllUnits())
    if (unit.isInShop) {
      if (unit.skins.len() == 0)
        unit.skins = get_skins_for_unit(unit.name) 

      foreach (skin in unit.skins)
        if (skin.name.len()) {
          local localeId = $"{unit.name}/{skin.name}"
          if (loc(localeId, "") == "") {
            log($"    {localeId}")
            count++
          }
        }
    }
  dlog($"{count} skins")

  
  log("DECALS")
  count = 0
  local blk = DataBlock()
  get_decals_blk(blk)
  local total = blk.blockCount()
  for (local i = 0; i < total; i++) {
    local dblk = blk.getBlock(i)
    local localeId = "".concat("decals/", dblk.getBlockName())
    if (loc(localeId, "") == "") {
      log($"    {localeId}")
      count++
    }
  }
  dlog($"{count} decals")
}

function debug_check_unit_naming() {
  if (!is_dev_version())
    return 0

  local ids = {}
  local names = {}
  local suffixes = ["_shop", "_0", "_1", "_2"]
  local count = 0
  local total = 0
  local brief = []

  brief.append($"debug_check_unit_naming() // {getLocalLanguage()}")
  log(brief[brief.len() - 1])

  foreach (unit in getAllUnits())
    if (unit.isInShop) {
      if (!ids?[unit.shopCountry])
        ids[unit.shopCountry] <- []
      ids[unit.shopCountry].append(unit.name)
    }
  foreach (c, unitIds in ids) {
    unitIds.sort()
    names[c] <- {}
    foreach (suffix in suffixes)
      names[c][suffix] <- []
  }

  log("UNLOCALIZED UNIT NAMES:")
  count = 0
  foreach (c, unitIds in ids)
    foreach (unitId in unitIds)
      foreach (suffix in suffixes) {
        local locId = $"{unitId}{suffix}"
        local locName = loc(locId)
        if (locName == locId) {
          locName = ""
          log(format("    \"%s\" - not found in localization", locId))
          count++
        }
        names[c][suffix].append(locName)
      }
  brief.append($"{count} unlocalized unit names")
  log(brief[brief.len() - 1])
  total += count

  log("NAME_SHOP CONFLICTS (IMPORTANT!):")
  count = 0
  foreach (c, unitIds in ids)
    for (local i = 0; i < unitIds.len(); i++)
      for (local j = i + 1; j < unitIds.len(); j++)
        if (names[c]._shop[i] != "" && names[c]._shop[j] != "" && names[c]._shop[i] == names[c]._shop[j]) {
          log(format("    '%s_shop', '%s_shop' - both units named \"%s\"",
            unitIds[i], unitIds[j], names[c]._shop[i]))
          count++
        }
  brief.append($"{count} name_shop conflicts:")
  log(brief[brief.len() - 1])
  total += count

  log("NAME_0 CONFLICTS:")
  count = 0
  foreach (c, unitIds in ids)
    for (local i = 0; i < unitIds.len(); i++)
      for (local j = i + 1; j < unitIds.len(); j++)
        if (names[c]._0[i] != "" && names[c]._0[j] != "" && names[c]._0[i] == names[c]._0[j]) {
          log(format("    '%s_0', '%s_0' - both units named \"%s\"",
            unitIds[i], unitIds[j], names[c]._0[i]))
          count++
        }
  brief.append($"{count} name_0 conflicts")
  log(brief[brief.len() - 1])
  total += count

  log("MIXED-UP _SHOP AND _0 NAMES:") 
  count = 0
  foreach (c, unitIds in ids)
    for (local i = 0; i < unitIds.len(); i++)
      if (names[c]._shop[i] != "" && names[c]._0[i] != "" &&
        utf8_strlen(names[c]._shop[i]) > utf8_strlen(names[c]._0[i])) {
        log(format("    '%s_shop' (\"%s\") is longer than '%s_0' (\"%s\"), probably names are mixed up",
          unitIds[i], names[c]._shop[i], unitIds[i], names[c]._0[i]))
        count++
      }
  brief.append($"{count} _shop and _0 names mixed-up")
  log(brief[brief.len() - 1])
  total += count

  log("MIXED-UP _SHOP AND _1 NAMES:")
  count = 0
  foreach (c, unitIds in ids)
    for (local i = 0; i < unitIds.len(); i++)
      if (names[c]._shop[i] != "" && names[c]._1[i] != "" &&
        utf8_strlen(names[c]._1[i]) > utf8_strlen(names[c]._shop[i])) {
        log(format("    '%s_1' (\"%s\") is longer than '%s_shop' (\"%s\"), probably names are mixed up",
          unitIds[i], names[c]._1[i], unitIds[i], names[c]._shop[i]))
        count++
      }
  brief.append($"{count} _shop and _1 names mixed-up")
  log(brief[brief.len() - 1])
  total += count

  log("NAMES WITH WASTED SPACE:")
  count = 0
  foreach (c, unitIds in ids)
    foreach (idx, unitId in unitIds)
      foreach (suffix in suffixes) {
        local name = names[c][suffix][idx]
        local fixed = regexp2(@"\s\s").replace(" ", strip(name))
        if (name.len() > fixed.len()) {
          log(format("    \"%s%s\" - need to trim space characters here: \"%s\"",
            unitId, suffix, name))
          count++
        }
      }
  brief.append($"{count} names with wasted space")
  log(brief[brief.len() - 1])
  total += count

  log($"NAMES WITH SUSPICIOUS CHARACTERS ({getLocalLanguage}):")
  count = 0
  local locale = getLocalLanguage()
  local configs = {
    Russian = {
      suspiciousChars = regexp2(@"[abcehkmoptx]")
      unsuspiciousChars = regexp2(@"[dfgijlnqrsuvwyz]")
      foreignAbc = regexp2(@"[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz]")
      foreignName = "Latin"
      allowWithPrefix = "▂"
      countriesCheck = [ "country_ussr" ]
    }
    Other = {
      suspiciousChars = regexp2(@"[абвгдеёжзийклмнопрстуфхцчшщъыьэюя]")
      foreignAbc = regexp2(@"[АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюя]")
      foreignName = "Cyrillic"
    }
  }
  local cfg = configs?[locale] ?? configs.Other
  foreach (c, unitIds in ids) {
    if (cfg?.countriesCheck && !isInArray(c, cfg.countriesCheck))
      continue
    foreach (idx, unitId in unitIds)
      foreach (suffix in suffixes) {
        local origName = names[c][suffix][idx]
        local nameLow = utf8ToLower(origName)
        local fixed = cfg.suspiciousChars.replace("_", nameLow)

        if (fixed == nameLow)
          continue
        if (cfg?.allowWithPrefix && startsWith(nameLow, cfg.allowWithPrefix))
          continue
        if (cfg?.unsuspiciousChars && cfg.unsuspiciousChars.match(nameLow))
          continue

        local allForeignChars = cfg.foreignAbc.replace("_", origName)
        log(format("    \"%s%s\" - %s chars in name: \"%s\" -> \"%s\"",
          unitId, suffix, cfg.foreignName, origName, allForeignChars))
        count++
      }
  }
  brief.append($"{count} names with suspicious characters")
  log(brief[brief.len() - 1])
  total += count

  brief.append($"TOTAL: {total}")
  log(brief[brief.len() - 1])
  foreach (str in brief)
    dlog(str)
  return total
}

local unitImagesCheckCfgs = [
  {
    imgType = "Icon"
    mask = "*.svg"
    pathRel = $"{skyquakePath}/develop/gui/units/icons"
    pathDev = $"{skyquakePath}/develop/gui/units_pkgdev/icons"
    subDirs  = { air = "aircraft", helicopter = "aircraft", tank = "tanks", ship = "ships" }
    placeholderFn = "image_in_progress_ico.svg"
    getUnitIdByImgFn = @(fn) fn.indexof("_ico.svg") != null ? fn.slice(0, fn.indexof("_ico.svg")) : ""
    getImgFnByUnitId = @(unitId) $"{unitId}_ico.svg"
    getImgFnForUnit = function(unit) {
      local img = getUnitClassIco(unit)
      return img.slice(lastIndexOf(img, "#") + 1)
    }
  },
  {
    imgType = "Slot image"
    mask = "*.tga"
    pathRel = $"{skyquakePath}/develop/gui/units/slots"
    pathDev = $"{skyquakePath}/develop/gui/units_pkgdev/slots"
    subDirs  = { air = "aircraft", helicopter = "aircraft", tank = "tanks", ship = "ships" }
    placeholderFn = "image_in_progress.tga"
    getUnitIdByImgFn = @(fn) fn.indexof(".") != null ? fn.slice(0, fn.indexof(".")) : ""
    getImgFnByUnitId = @(unitId) $"{unitId}.tga"
    getImgFnForUnit = function(unit) {
      local img = image_for_air(unit)
      return "".concat(img.slice(lastIndexOf(img, "#") + 1), ".tga")
    }
  },
  {
    imgType = "Tomoe slot image"
    mask = "*.tga"
    pathRel = $"{skyquakePath}/develop/gui/units/tomoe"
    pathDev = $""
    subDirs  = { air = "aircraft", helicopter = "aircraft", tank = "tanks", ship = "ships" }
    placeholderFn = "image_in_progress.tga"
    getUnitIdByImgFn = @(fn) fn.indexof(".") != null ? fn.slice(0, fn.indexof(".")) : ""
    getImgFnByUnitId = @(unitId) $"{unitId}.tga"
    getImgFnForUnit = function(unit) {
      local img = image_for_air(unit)
      return "".concat(img.slice(lastIndexOf(img, "#") + 1), ".tga")
    }
    filterUnits = @(unit) is_harmonized_unit_image_required(unit)
    onStart  = function() {
    }
    onFinish = function() {
    }
  },
  {
    imgType = "Photo image"
    mask = "*.dds"
    pathRel = $"{skyquakePath}/develop/gui/menu/tex"
    pathDev = $"{skyquakePath}/develop/gui/menu/pkg_dev"
    subDirs  = { air = "aircrafts", helicopter = "aircrafts", tank = "tanks", ship = "ships" }
    placeholderFn = "image_in_progress.dds"
    getUnitIdByImgFn = @(fn) fn.indexof(".") != null ? fn.slice(0, fn.indexof(".")) : ""
    getImgFnByUnitId = @(unitId) $"{unitId}.dds"
    getImgFnForUnit = function(unit) {
      local img = getUnitTooltipImage(unit)
      return "".concat(img.slice(lastIndexOf(img, "/") + 1), ".dds")
    }
  },
]

function unitImagesSearchEverywhere(fn, files, unit, cfg) {
  local res = []
  foreach (pathKey in [ "pathRel", "pathDev" ])
    foreach (unitTag, subDir in cfg.subDirs)
      if (files[unitTag][pathKey].indexof(fn) != null) {
        local path = replace("/".concat(cfg[pathKey], subDir, fn), "/", "\\")
        if (res.findvalue(@(v) v.path == path) == null)
          res.append({
            path = path
            isAccessible = unit.isPkgDev || pathKey == "pathRel"
          })
      }
  return res
}

function debug_check_unit_images(verbose = false) {
  local unitsList = getAllUnits().values().filter(@(unit) unit.isInShop)
  local errors    = 0
  local warnings  = 0
  local info      = 0
  local printFunc = console_print

  foreach (cfg in unitImagesCheckCfgs) {
    local files = {}
    foreach (unitTag, subDir in cfg.subDirs) {
      files[unitTag] <- {}
      foreach (pathKey in [ "pathRel", "pathDev" ]) {
        local list = dagor_fs.scan_folder({ root = $"{cfg[pathKey]}/{subDir}",
          files_suffix = cfg.mask, vromfs = false, realfs = true, recursive = true })
        files[unitTag][pathKey] <- list.map(@(path) stdpath.fileName(path).tolower()).sort()
      }
    }

    cfg?.onStart()
    local units = cfg?.filterUnits ? unitsList.filter(cfg.filterUnits) : unitsList
    foreach (_idx, unit in units) {
      local fn = cfg.getImgFnForUnit(unit).tolower()
      local unitTag = unit.unitType.getCrewTag()
      local unitSrc = unit.isPkgDev ? "pkg_dev" : "release"
      local pathKey = unit.isPkgDev ? "pathDev" : "pathRel"

      if (fn == "" || fn == cfg.placeholderFn) {
        local valueTxt = fn == "" ? "empty string" : $"placeholder: \"{fn}\""
        local expectedFn = cfg.getImgFnByUnitId(unit.name).tolower()
        local located = unitImagesSearchEverywhere(expectedFn, files, unit, cfg)?[0]

        if (located != null) {
          
          errors++
          printFunc($"ERROR: {cfg.imgType} for {unitSrc} unit \"{unit.name}\" is {valueTxt} (but image exists: \"{located.path}\")")
        }
        else {
          
          local isError = !unit.isPkgDev
          if (isError)
            errors++
          else
            info++
          local accidentType = isError ? "ERROR" : "INFO"
          if (isError || verbose)
            printFunc($"{accidentType}: {cfg.imgType} for {unitSrc} unit \"{unit.name}\" is {valueTxt}")
        }
        continue
      }

      if (files[unitTag][pathKey].indexof(fn) == null) {
        
        local imgUnit = getAircraftByName(cfg.getUnitIdByImgFn(fn))
        if (imgUnit != null && imgUnit != unit && unit.isPkgDev && !imgUnit.isPkgDev) {
          local unitTag2 = imgUnit.unitType.getCrewTag()
          local pathKey2 = imgUnit.isPkgDev ? "pathDev" : "pathRel"
          if (files[unitTag2][pathKey2].indexof(fn) != null)
            continue
        }

        local located = unitImagesSearchEverywhere(fn, files, unit, cfg)?[0]
        local isError = located == null || !located.isAccessible
        if (isError)
          errors++
        else
          warnings++
        local accidentType = isError ? "ERROR" : "WARNING"
        local accidentText = located == null ? "NOT FOUND"
          : !located.isAccessible ? "MUST be here"
          : "should be here"
        local comment = located != null ? $" (wrong location: \"{located.path}\")" : ""
        local expectedPath = "/".concat(cfg[pathKey], cfg.subDirs[unitTag], fn)
        expectedPath = replace(expectedPath, "/", "\\")
        printFunc($"{accidentType}: {cfg.imgType} for {unitSrc} unit \"{unit.name}\" {accidentText}: \"{expectedPath}\"{comment}")
      }
      else {
        
        local locatedList = unitImagesSearchEverywhere(fn, files, unit, cfg)
        if (locatedList.len() > 1) {
          local expectedPath = "/".concat(cfg[pathKey], cfg.subDirs[unitTag], fn)
          expectedPath = replace(expectedPath, "/", "\\")
          foreach (located in locatedList)
            if (located.path != expectedPath) {
              warnings++
              printFunc($"WARNING: {cfg.imgType} for {unitSrc} unit \"{unit.name}\" exists: \"{expectedPath}\" (but has a DUPLICATE: \"{located.path}\")")
            }
        }
      }
    }
    cfg?.onFinish()
  }

  local infos = verbose ? $"{info} info, " : ""
  printFunc($"Done ({errors} errors, {warnings} warnings, {infos}{unitsList.len()} total)")
  return errors
}

function debug_cur_level_auto_skins() {
  local level = isInFlight() ? get_current_mission_info_cached()?.level : null
  local fullDebugtext = "".concat("Auto skins for ", (level || "TestFlight"))
  if (level)
    fullDebugtext = "".concat(fullDebugtext, " ( ",
      skinLocations.debugLocationMask(skinLocations.getMaskByLevel(level)), " )")

  local total = 0
  foreach (unit in getAllUnits())
    if (unit.unitType.isSkinAutoSelectAvailable()) {
      total++
      fullDebugtext = "".concat(fullDebugtext, "\n", unit.name, " -> ",
        ", ".join(getBestSkinsList(unit.name, true), true))
    }

  log(fullDebugtext)
  dlog($"Total units found = {total}")
}

function debug_all_skins_without_location_mask() {
  local totalList = []
  foreach (unit in getAllUnits())
    if (unit.unitType.isSkinAutoSelectAvailable())
      foreach (skin in unit.getSkins()) {
        if (skin.name == "")
          continue
        local mask = skinLocations.getSkinLocationsMask(skin.name, unit.name, decoratorTypes.SKINS)
        if (!mask)
          u.appendOnce(skin.name, totalList)
      }
  dlog($"Total skins without location mask = {totalList.len()}\n{", ".join(totalList, true)}")
}

register_command(debug_check_unlocalized_resources, "debug.check_unlocalized_resources")
register_command(debug_check_unit_naming, "debug.check_unit_naming")
register_command(@() debug_check_unit_images(), "debug.check_unit_images")
register_command(@() debug_check_unit_images(true), "debug.check_unit_images_verbose")
register_command(debug_cur_level_auto_skins, "debug.cur_level_auto_skins")
register_command(debug_all_skins_without_location_mask, "debug.all_skins_without_location_mask")
