from "%scripts/dagui_library.nut" import *

let { resetTimeout } = require("dagor.workcycle")
let { get_time_msec } = require("dagor.time")
let { saveJson } = require("%sqstd/json.nut")
let { object_to_json_string } = require("json")
let { file } = require("io")
let { copyParamsToTable } = require("%sqstd/datablock.nut")
let { mkpath } = require("dagor.fs")
let { register_command } = require("console")
let { web_rpc } = require("%scripts/webRPC.nut")
let { isDataBlock, appendOnce } = require("%sqStdLibs/helpers/u.nut")
let { calculate_tank_bullet_parameters } = require("unitCalculcation")
let { blkOptFromPathCachedByUnit } = require("%scripts/unit/unitBlkCache.nut")
let { getFullUnitBlk } = require("%scripts/unit/unitParams.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { getLocalLanguage } = require("language")
let { doesLocTextExist } = require("dagor.localize")
let buildWeaponsLoc = require("%scripts/exportInfo/weaponsLocExporter.nut")
let { get_bullets_locId_by_caliber } = require("%scripts/options/optionsStorage.nut")
let {
  getUnitWeapons,
  getUnitPresets,
  getWeaponsByTypes,
  getPresetWeapons,
  getWeaponBlkParams
} = require("%scripts/weaponry/weaponryPresets.nut")
let {
  getBulletsSearchName,
  getModificationBulletsEffect
} = require("%scripts/weaponry/bulletsInfo.nut")
let { buildBulletsData } = require("%scripts/weaponry/bulletsVisual.nut")
let { getMaxArmorPiercing } = require("%scripts/weaponry/dmgModel.nut")
let { getWeaponNameByBlkPath } = require("%scripts/weaponry/weaponryInfo.nut")

let RAW_FIELDS = [
  "bulletName", "bulletType", "mass", "speed", "caliber",
  "explosiveType", "explosiveMass",
  "ricochetPreset", "fuseDelayDist", "fuseDelay",
  "normalizationPreset", "groundRicochetPreset", "stabilityThreshold",
  "stabilityCaliberToArmorThreshold", "stabilityReductionAfterRicochet",
  "stabilityReductionAfterPenetration", "slopeEffectPreset",
  "cumulativeDamage", "cumulativeByNormal",
  "operated", "guidanceType", "rangeMax", "timeLife", "endSpeed",
  "selfDestructionInAir", "maxDistance", "damageMass", "damageCaliber",
  "ballisticCaliber", "Cx"
]

let WEAPON_RAW_FIELDS = [
  "cannon", "rocketGun", "bombGun", "torpedoGun", "weaponType", "shotFreq", "traceFreq",
  "bullets", "bulletsCluster", "bulletsCartridge", "reloadTime",
  "caliber", "isBulletBelt", "bUseHookAsRel", "aimMinDist", "aimMaxDist",
  "maxDeltaAngle", "maxDeltaAngleVertical", "fxType", "sfxReloadBullet", "mesh", "bombCart",
  "offsetForDemonstration", "rollForDemonstration", "preset_cost", "mass"
]

let MUNITION_RAW_FIELDS = [
  "bulletName", "bulletType", "mass", "mass_lbs", "caliber", "length",
  "guidanceType", "operated", "autoAiming", "isBeamRider",
  "rangeMax", "minDistance", "maxDistance", "timeLife",
  "machMax", "maxSpeed", "endSpeed", "loadFactorMax",
  "explosiveType", "explosiveMass", "cumulativeByNormal",
  "explodeArmorPower", "explodeRadius", "shutterDamageRadius",
  "shutterArmorPower", "armDistance", "dropSpeedRange", "dropHeightRange",
  "maxSpeedInWater", "distToLive", "diveDepth", "iconType", "yield"
]

const TARGET_WEAPONS_INFO = "weaponsInfo"

let class ExporterStatus {
  static DETAILS_FIELD = "details"
  static SUCCESS_FIELD = "success"

  lastFlushTimeMsec = -1

  flushPeriodMsec = 5000
  filename = ""
  status = null

  constructor(filename_) {
    this.filename = filename_
    this.status = {}
  }

  function setTargetField(target, field, value) {
    if (!(target in this.status))
      this.status[target] <- {}
    this.status[target][field] <- value
  }

  function setTargetDetails(target, details) {
    this.setTargetField(target, this.DETAILS_FIELD, details)
  }

  function getTargetDetails(target) {
    return this.status[target][this.DETAILS_FIELD]
  }

  function finishTarget(target, isSuccess) {
    this.setTargetField(target, this.SUCCESS_FIELD, isSuccess)
  }

  function periodicFlushToFile() {
    if (this.lastFlushTimeMsec + this.flushPeriodMsec < get_time_msec())
      this.forceFlushToFile()
  }

  function forceFlushToFile() {
    if (this.filename == "")
      return

    this.lastFlushTimeMsec = get_time_msec()
    mkpath(this.filename)
    saveJson(this.filename, this.status)
  }
}

function normalizeValue(v) { 
  if (v == null)
    return null

  let t = type(v)

  if (t == "integer" || t == "float" || t == "bool" || t == "string")
    return v

  if (t == "array" || t == "table") {
    let localNormalize = normalizeValue
    return v.map(@(val) localNormalize(val))
  }

  if (t == "instance") {
    try {
      if (isDataBlock(v))
        return normalizeValue(copyParamsToTable(v))
    } catch (e) {}

    try { if ("w" in v && "x" in v && "y" in v && "z" in v) return [v.x, v.y, v.z, v.w] } catch (e) {}
    try { if ("x" in v && "y" in v && "z" in v) return [v.x, v.y, v.z] } catch (e) {}
    try { if ("x" in v && "y" in v) return [v.x, v.y] } catch (e) {}
    try { if ("r" in v && "g" in v && "b" in v) return [v.r, v.g, v.b, v?.a ?? 255] } catch (e) {}

    try { return v.tostring() } catch (e) { return "<instance>" }
  }

  try { return v.tostring() } catch (e) { return $"<{t}>" }
}

function readParamsBlock(b) {
  let res = {}
  let duplicated = {}
  let pc = b.paramCount()

  for (local i = 0; i < pc; i++) {
    let name = b.getParamName(i)
    let val = normalizeValue(b.getParamValue(i))

    if (name in res) {
      if (!(name in duplicated)) {
        res[name] = [res[name]]
        duplicated[name] <- true
      }
      res[name].append(val)
    }
    else
      res[name] <- val
  }

  return res
}

function readRawFields(b, fields) {
  let out = {}
  foreach (p in fields) {
    let val = b?[p]
    if (val != null)
      out[p] <- normalizeValue(val)
  }

  return out
}

function readNamedChildBlocks(b, names) {
  let res = {}
  foreach (name in names) {
    let child = b?[name]
    if (isDataBlock(child))
      res[name] <- readParamsBlock(child)
  }
  return res
}

function makePenetrationData(data) {
  if (data == null)
    return null
  if ((data?.bulletType ?? "") == "aam")
    return null

  let res = {}
  let dist = data?.armorPiercingDist ?? []
  let kinetic = (data?.armorPiercingKinetic ?? []).len() > 0
    ? data.armorPiercingKinetic
    : (data?.armorPiercing ?? [])
  if (dist.len() > 0 && kinetic.len() > 0)
    res.kinetic <- {
      distances = normalizeValue(dist)
      values = normalizeValue(kinetic)
    }

  let rawCumulativeDamage = data?.cumulativeDamage ?? 0
  let cumulativeDamage = type(rawCumulativeDamage) == "table"
    ? (rawCumulativeDamage?.armorPower ?? 0)
    : rawCumulativeDamage
  if (cumulativeDamage > 0) {
    res.cumulativeDamage <- cumulativeDamage
    res.cumulativeByNormal <- data?.cumulativeByNormal ?? false
  }

  let explosiveType = data?.explosiveType
  let explosiveMass = data?.explosiveMass ?? 0
  if (explosiveType != null && explosiveMass > 0) {
    local highExplosive = null
    try {
      highExplosive = getMaxArmorPiercing(explosiveType, explosiveMass)
    } catch (e) {
      highExplosive = null
    }
    if (highExplosive != null && highExplosive > 0)
      res.highExplosive <- highExplosive
  }

  return res.len() == 0 ? null : res
}

function makeGuiArmorpowerPenetrationData(guiArmorpower) {
  if (guiArmorpower == null)
    return null

  let rows = []
  let appendRow = function(value) {
    let v = normalizeValue(value)
    if (type(v) == "array" && v.len() >= 4)
      rows.append({
        distance = v[3]
        values = {
          ["0"] = v[0],
          ["30"] = v[1],
          ["60"] = v[2]
        }
      })
  }

  if (type(guiArmorpower) == "table")
    foreach (_key, value in guiArmorpower)
      appendRow(value)
  else if (type(guiArmorpower) == "array")
    foreach (value in guiArmorpower)
      appendRow(value)
  else
    appendRow(guiArmorpower)

  if (rows.len() == 0)
    return null

  rows.sort(@(a, b) a.distance <=> b.distance)

  let distances = []
  let values = []
  foreach (row in rows) {
    distances.append(row.distance)
    values.append(row.values)
  }

  return {
    kinetic = {
      distances = distances
      values = values
    }
  }
}

function mergePenetrationData(baseData, extraData) {
  if (baseData == null)
    return extraData
  if (extraData == null)
    return baseData

  foreach (key, value in extraData)
    if (!(key in baseData))
      baseData[key] <- value

  return baseData
}

function makePenetrationDataFromParamsArray(paramsArray) {
  if (type(paramsArray) != "array")
    return makePenetrationData(paramsArray)

  local res = null
  foreach (params in paramsArray)
    res = mergePenetrationData(res, makePenetrationData(params))

  return res
}

function writeJsonTableEntries(fp, tbl) {
  local first = true
  foreach (key, value in tbl) {
    if (!first)
      fp.writestring(",")
    first = false
    fp.writestring(object_to_json_string(key.tostring(), false))
    fp.writestring(":")
    fp.writestring(object_to_json_string(value, false))
  }
}

function writeJsonTableField(fp, fieldName, tbl) {
  fp.writestring(object_to_json_string(fieldName, false))
  fp.writestring(":{")
  writeJsonTableEntries(fp, tbl ?? {})
  fp.writestring("}")
}

function saveExportDbJson(filePath, exportDb) {
  let weapons = exportDb?.weapons ?? {}

  mkpath(filePath)
  let fp = file(filePath, "wt+")
  try {
    fp.writestring("{")
    writeJsonTableField(fp, "bullets", exportDb?.bullets)
    fp.writestring(",")
    writeJsonTableField(fp, "projectileRefs", exportDb?.projectileRefs)
    fp.writestring(",\"weapons\":{")
    writeJsonTableField(fp, "barrels", weapons?.barrels)
    fp.writestring(",")
    writeJsonTableField(fp, "munitions", weapons?.munitions)
    fp.writestring("}}")
    fp.close()
  } catch (e) {
    fp.close()
    throw e
  }
}

function isSkippedExportKey(skipKeys, key) {
  return skipKeys.indexof(key) != null
}

function removeEmptyValues(value) {
  let valueType = type(value)
  if (valueType == "table") {
    let res = {}
    foreach (key, nestedValue in value) {
      let cleanValue = removeEmptyValues(nestedValue)
      let cleanType = type(cleanValue)
      if ((cleanType == "table" || cleanType == "array") && cleanValue.len() == 0)
        continue
      res[key] <- cleanValue
    }
    return res
  }

  if (valueType == "array") {
    let res = []
    foreach (nestedValue in value) {
      let cleanValue = removeEmptyValues(nestedValue)
      let cleanType = type(cleanValue)
      if ((cleanType == "table" || cleanType == "array") && cleanValue.len() == 0)
        continue
      res.append(cleanValue)
    }
    return res
  }

  return value
}

function copyWithoutKeys(src, skipKeys) {
  let res = {}
  if (src == null)
    return res

  foreach (key, value in src)
    if (!isSkippedExportKey(skipKeys, key))
      res[key] <- removeEmptyValues(value)

  return res
}

function makeIdPart(value) {
  return (value ?? "").tostring()
    .replace("\\", "_")
    .replace("/", "_")
    .replace(" ", "_")
    .replace(":", "_")
    .replace("=", "_")
    .replace(".", "_")
    .replace("-", "m")
}

function makeNumberIdPart(value, scale = 1.0) {
  return makeIdPart(value * scale)
}

function readRawBullet(b) {
  let rocket = b?.rocket
  let hasRocket = isDataBlock(rocket)
  let src = hasRocket ? rocket : b
  let out = { blockName = b.getBlockName() }

  foreach (p in RAW_FIELDS) {
    let val = src?[p] ?? b?[p]
    if (val != null)
      out[p] <- normalizeValue(val)
  }

  if (hasRocket)
    out.hasRocketBlock <- true

  foreach (nested in ["armorpower", "guiArmorpower", "damage", "explosion", "shatter", "hitpower", "ricochetPreset", "visual"]) {
    let srcChild = src?[nested]
    if (isDataBlock(srcChild)) {
      out[nested] <- readParamsBlock(srcChild)
      continue
    }
    let bChild = b?[nested]
    if (isDataBlock(bChild))
      out[nested] <- readParamsBlock(bChild)
  }

  return out
}

function makeBulletFingerprint(raw, bName) {
  let bulletName = raw?.bulletName ?? ""
  if (bulletName != "")
    return bulletName

  let { bulletType = "", caliber = 0, mass = 0, speed = 0 } = raw

  return $"{makeIdPart(bulletType)}_{makeNumberIdPart(caliber, 1000.0)}mm_{makeNumberIdPart(mass, 1000.0)}g_{makeNumberIdPart(speed)}mps_{makeIdPart(bName)}"
}

function makeBulletDbKey(weaponBlkPath, subName, raw, bName, bulletIndex) {
  let bulletName = raw?.bulletName ?? ""
  if (bulletName != "")
    return bulletName

  let fp = makeBulletFingerprint(raw, bName)
  if (fp != "")
    return fp

  let setPart = (subName == null || subName == "") ? "default" : makeIdPart(subName)
  return $"{makeIdPart(getWeaponNameByBlkPath(weaponBlkPath))}_{setPart}_{bulletIndex}_{makeIdPart(bName)}"
}

function getProjectileId(raw) {
  let bulletName = raw?.bulletName ?? ""
  if (bulletName != "")
    return bulletName

  return makeBulletFingerprint(raw, "")
}

function collectAvailableBulletSetNames(unitName) {
  let res = {}

  let unit = getAircraftByName(unitName)
  if (unit == null)
    return res

  foreach (m in unit.getModifications()) {
    let modName = m.name

    let effect = getModificationBulletsEffect(modName)
    if (effect != null && effect != "")
      res[effect] <- true

    let searchName = getBulletsSearchName(unit, modName)
    if (searchName != null && searchName != "")
      res[searchName] <- true
  }

  return res
}

function addWeaponPath(paths, unitName, weapon) {
  if (weapon?.dummy)
    return

  let blkPath = weapon?.blk ?? ""
  if (blkPath == "")
    return

  let { weaponBlkPath = "" } = getWeaponBlkParams(unitName, blkPath)
  if (weaponBlkPath != "")
    paths[weaponBlkPath] <- true
}

function collectWeaponPathsFromUnitBlk(unitName) {
  let unitBlk = getFullUnitBlk(unitName)
  if (unitBlk == null)
    return {}

  let paths = {}

  if (unitBlk?.commonWeapons != null) {
    let common = getWeaponsByTypes(unitName, unitBlk, unitBlk.commonWeapons, unitBlk?.WeaponPilons)
    foreach (w in common)
      addWeaponPath(paths, unitName, w)
  }

  foreach (preset in getUnitPresets(unitBlk)) {
    let weapons = getPresetWeapons(unitBlk, preset, unitName)
    foreach (w in weapons)
      addWeaponPath(paths, unitName, w)
  }

  foreach (w in getUnitWeapons(unitName, unitBlk))
    addWeaponPath(paths, unitName, w)

  return paths
}

function getBulletAnimationsFromBlock(b) {
  let paramsBlk = isDataBlock(b?.rocket) ? b.rocket : b
  let animations = []
  foreach (anim in paramsBlk % "shellAnimation")
    animations.append(anim)
  return animations
}

function findCaliberSuffixCI(id) {
  if (id == null || id == "")
    return null
  let low = id.tolower()
  foreach (ending in get_bullets_locId_by_caliber()) {
    let el = ending.tolower()
    if (low.len() > el.len() && low.slice(low.len() - el.len()) == el)
      return ending
  }
  return null
}

function locKeyExists(key) {
  return key != null && key != "" && doesLocTextExist(key)
}

function firstExistingLocKey(keys) {
  foreach (key in keys)
    if (locKeyExists(key))
      return key
  return ""
}

function pushNonEmptyUnique(arr, value) {
  if (value != null && value != "" && arr.indexof(value) == null)
    arr.append(value)
}

function resolveNameLocId(candidates, physicalId = "") {
  foreach (c in candidates) {
    let key = firstExistingLocKey([ c, $"{c}/name", $"weapons/{c}", $"weapons/{c}/short", $"modification/{c}" ])
    if (key != "")
      return key
  }
  let suffix = findCaliberSuffixCI(physicalId)
  if (suffix != null) {
    let key = firstExistingLocKey([ $"{suffix}/name", suffix ])
    if (key != "")
      return key
  }
  return ""
}

function resolveShortLocId(candidates, physicalId = "") {
  foreach (c in candidates) {
    let key = firstExistingLocKey([ $"{c}/name/short", $"weapons/{c}/short", $"modification/{c}/short" ])
    if (key != "")
      return key
  }
  let suffix = findCaliberSuffixCI(physicalId)
  if (suffix != null) {
    let key = firstExistingLocKey([ $"{suffix}/name/short" ])
    if (key != "")
      return key
  }
  return ""
}

function resolveDescLocId(candidates) {
  foreach (c in candidates) {
    let key = firstExistingLocKey([ $"{c}/desc", $"weapons/{c}/desc", $"modification/{c}/desc" ])
    if (key != "")
      return key
  }
  return ""
}

function storeLocIds(entry, candidates, physicalId = "") {
  if (entry == null)
    return
  if ((entry?.nameLocId ?? "") == "") {
    let nameLocId = resolveNameLocId(candidates, physicalId)
    if (nameLocId != "")
      entry.nameLocId <- nameLocId
  }
  if ((entry?.nameShortLocId ?? "") == "") {
    let shortLocId = resolveShortLocId(candidates, physicalId)
    if (shortLocId != "")
      entry.nameShortLocId <- shortLocId
  }
  if ((entry?.descLocId ?? "") == "") {
    let descLocId = resolveDescLocId(candidates)
    if (descLocId != "")
      entry.descLocId <- descLocId
  }
}

function buildEffectToModMap(unitName) {
  let res = {}
  let unit = getAircraftByName(unitName)
  if (unit == null)
    return res

  foreach (m in unit.getModifications()) {
    let modName = m.name

    let effect = getModificationBulletsEffect(modName)
    if (effect != null && effect != "" && !(effect in res))
      res[effect] <- modName

    let searchName = getBulletsSearchName(unit, modName)
    if (searchName != null && searchName != "" && !(searchName in res))
      res[searchName] <- modName

    if (!(modName in res))
      res[modName] <- modName
  }

  return res
}

function addProjectileRef(projectilesDb, bulletId, raw) {
  if (projectilesDb == null)
    return

  let projectileId = getProjectileId(raw)
  if (projectileId == "")
    return

  if (!(projectileId in projectilesDb)) {
    let entry = {
      id = projectileId
      sourceBulletIds = []
    }
    let ricochetPreset = raw?.ricochetPreset
    if (ricochetPreset != null)
      entry.ricochetPreset <- ricochetPreset
    projectilesDb[projectileId] <- entry
  }

  appendOnce(bulletId, projectilesDb[projectileId].sourceBulletIds)
}

function getWeaponKind(wBlk) {
  if (wBlk?.rocketGun)
    return "rocketGun"
  if (wBlk?.bombGun)
    return "bombGun"
  if (wBlk?.torpedoGun)
    return "torpedoGun"
  if (wBlk?.cannon == false)
    return "machineGun"
  if (wBlk?.cannon == true)
    return "cannon"
  return "weapon"
}

function isMunitionWeaponKind(weaponKind) {
  return weaponKind == "rocketGun" || weaponKind == "bombGun" || weaponKind == "torpedoGun"
}

function makeExportRawBulletData(raw) {
  let skipRawKeys = [
    "bulletName", "bulletType",
    "ricochetPreset", "sound", "sound_inside", "sound_path", "sound_pathStudio"
  ]

  return copyWithoutKeys(raw, skipRawKeys)
}

function makeExportBulletsDb(rawBulletsDb) {
  let res = {}

  foreach (id, bulletData in rawBulletsDb)
    res[id] <- removeEmptyValues(bulletData)

  return res
}

function makeExportProjectileRefsDb(rawProjectilesDb) {
  let skipKeys = [ "id" ]
  let res = {}

  foreach (id, projectileData in rawProjectilesDb)
    res[id] <- copyWithoutKeys(projectileData, skipKeys)

  return res
}

function shouldSkipWeaponExport(id) {
  return id.tolower() == "dummy_weapon"
}

function makeWeaponsDb(rawWeaponsDb) {
  let res = {
    barrels = {}
    munitions = {}
  }

  foreach (id, weaponData in rawWeaponsDb) {
    if (shouldSkipWeaponExport(id))
      continue

    let target = weaponData?.munition != null || isMunitionWeaponKind(weaponData?.weaponKind ?? "")
      ? res.munitions
      : res.barrels
    target[id] <- removeEmptyValues(weaponData)
  }

  return res
}

function makeExportDb(db, projectilesDb, barrelsDb) {
  return {
    bullets = makeExportBulletsDb(db)
    projectileRefs = makeExportProjectileRefsDb(projectilesDb)
    weapons = makeWeaponsDb(barrelsDb)
  }
}

function getWeaponMunitionBlock(wBlk) {
  if (isDataBlock(wBlk?.rocket))
    return wBlk.rocket
  if (isDataBlock(wBlk?.bomb))
    return wBlk.bomb
  if (isDataBlock(wBlk?.payload) && (wBlk?.bombGun || wBlk?.rocketGun || wBlk?.torpedoGun))
    return wBlk.payload
  if (isDataBlock(wBlk?.torpedo))
    return wBlk.torpedo
  return null
}

function weaponHasAnyBulletBlock(wBlk) {
  if ((wBlk % "bullet").len() > 0)
    return true
  let n = wBlk.blockCount()
  for (local i = 0; i < n; i++)
    if ((wBlk.getBlock(i) % "bullet").len() > 0)
      return true
  return false
}

function isNonBulletThrowableWeapon(wBlk) {
  return getWeaponMunitionBlock(wBlk) == null && !weaponHasAnyBulletBlock(wBlk)
}

function readGuiArmorpower(wBlk) {
  let munitionBlk = getWeaponMunitionBlock(wBlk)
  if (isDataBlock(munitionBlk?.guiArmorpower))
    return copyParamsToTable(munitionBlk.guiArmorpower)

  return null
}

function getWeaponDbKey(weaponBlkPath, _wBlk) {
  return getWeaponNameByBlkPath(weaponBlkPath)
}

function readCompactGuidance(guidanceBlk) {
  if (!isDataBlock(guidanceBlk))
    return null

  let res = readRawFields(guidanceBlk, [
    "launchAngleMax", "breakLockMaxTime", "inertialNavigation",
    "inertialNavigationDriftSpeed", "datalink", "beamRider", "beaconBand"
  ])

  if (isDataBlock(guidanceBlk?.opticalSeeker)) {
    let seeker = readRawFields(guidanceBlk.opticalSeeker, [
      "targetSignatureType", "rangeBand0", "rangeBand1", "rangeBand2",
      "rangeBand3", "rangeBand6", "rangeBand7", "rangeBand8", "rangeMax",
      "rangeSurface", "fov", "gateWidth", "lockAngleMax", "angleMax",
      "rateMax", "groundVehiclesAsTarget", "surfaceAsTarget"
    ])
    if (seeker.len() > 0)
      res.opticalSeeker <- seeker
  }

  if (isDataBlock(guidanceBlk?.radarSeeker)) {
    let seeker = readRawFields(guidanceBlk.radarSeeker, [
      "active", "band", "groundClutter"
    ])
    if (isDataBlock(guidanceBlk.radarSeeker?.receiver)) {
      let receiver = readRawFields(guidanceBlk.radarSeeker.receiver, [
        "range", "rangeMax"
      ])
      if (receiver.len() > 0)
        seeker.receiver <- receiver
    }
    if (seeker.len() > 0)
      res.radarSeeker <- seeker
  }

  return res.len() == 0 ? null : res
}

function readMunitionData(wBlk) {
  let munitionBlk = getWeaponMunitionBlock(wBlk)
  if (munitionBlk == null)
    return null

  let res = readRawFields(munitionBlk, MUNITION_RAW_FIELDS)

  let nestedNames = (munitionBlk?.bulletType ?? "") == "aam"
    ? [ "proximityFuse", "cumulativeDamage", "kineticDamage" ]
    : [ "armorpower", "proximityFuse", "cumulativeDamage", "kineticDamage" ]
  let nested = readNamedChildBlocks(munitionBlk, nestedNames)
  foreach (name, value in nested)
    res[name] <- value

  let guidance = readCompactGuidance(munitionBlk?.guidance)
  if (guidance != null)
    res.guidance <- guidance

  return res
}

function calcWeaponPenetration(unitName, weaponBlkPath, munitionData, wBlk = null) {
  if ((munitionData?.bulletType ?? "") == "aam")
    return null

  let guiArmorpower = wBlk == null ? null : readGuiArmorpower(wBlk)
  let guiPenetration = makeGuiArmorpowerPenetrationData(guiArmorpower)

  let bulletsSet = {
    explosiveType = munitionData?.explosiveType
    explosiveMass = munitionData?.explosiveMass ?? 0
    cumulativeDamage = munitionData?.cumulativeDamage?.armorPower ?? 0
    cumulativeByNormal = munitionData?.cumulativeByNormal ?? false
  }
  if (guiArmorpower != null)
    bulletsSet.guiArmorpower <- guiArmorpower

  let bulletParams = calculate_tank_bullet_parameters(unitName, weaponBlkPath, true, false)
  let paramsPenetration = makePenetrationDataFromParamsArray(bulletParams)
  let bulletsData = buildBulletsData(bulletParams, bulletsSet)
  let penetration = mergePenetrationData(guiPenetration,
    mergePenetrationData(makePenetrationData(bulletsData), paramsPenetration))
  if (penetration != null)
    return penetration

  return mergePenetrationData(guiPenetration, makePenetrationData(munitionData))
}

function addSetToDb(db, unitName, weaponBlkPath, subName, container, availableSets,
  projectilesDb = null, effectToMod = null, errors = null) {
  let bullets = container % "bullet"
  if (bullets.len() == 0)
    return

  let useDefault = (subName == null || subName == "")
  let effectOrBlk = useDefault ? weaponBlkPath : subName

  let isBulletSequence = useDefault && bullets.len() > 1

  let availableOnUnit = isBulletSequence || useDefault || (subName in availableSets)
  if (!availableOnUnit)
    return

  local calcResult = null
  local calcError = null

  try {
    calcResult = calculate_tank_bullet_parameters(unitName, effectOrBlk, useDefault, false)
  } catch (e) {
    calcError = e.tostring()
    if (errors != null)
      errors.append($"unit {unitName} weapon {weaponBlkPath} bullet set '{effectOrBlk}': {calcError}")
  }

  for (local idx = 0; idx < bullets.len(); idx++) {
    let b = bullets[idx]
    let bName = b.getBlockName()
    let raw = readRawBullet(b)
    raw.animations <- normalizeValue(getBulletAnimationsFromBlock(b))
    let key = makeBulletDbKey(weaponBlkPath, subName, raw, bName, idx)

    if (bullets.len() > 1)
      addProjectileRef(projectilesDb, key, raw)

    local ttxForBullet = null
    if (type(calcResult) == "array")
      ttxForBullet = (idx < calcResult.len()) ? calcResult[idx] : null
    else if (calcResult != null)
      ttxForBullet = calcResult

    if (!(key in db)) {
      db[key] <- {
        bulletTypeId = raw?.bulletType ?? ""
        raw = makeExportRawBulletData(raw)
        units = []
        ttxByUnit = {}
        penetrationByUnit = {}
      }
    }

    let modName = (!useDefault && effectToMod != null && subName in effectToMod)
      ? effectToMod[subName]
      : ""
    let candidates = []
    pushNonEmptyUnique(candidates, raw?.bulletName ?? "")
    pushNonEmptyUnique(candidates, modName)
    if (!useDefault)
      pushNonEmptyUnique(candidates, subName)
    pushNonEmptyUnique(candidates, raw?.bulletType ?? "")
    storeLocIds(db[key], candidates, key)

    appendOnce(unitName, db[key].units)

    if (calcError != null)
      db[key].ttxByUnit[unitName] <- { error = calcError }
    else if (ttxForBullet != null) {
      db[key].ttxByUnit[unitName] <- normalizeValue(ttxForBullet)
      let penetration = makePenetrationData(ttxForBullet)
      if (penetration != null)
        db[key].penetrationByUnit[unitName] <- penetration
    }
  }
}

function addBarrelToDb(barrelsDb, unitName, weaponBlkPath, wBlk) {
  if (barrelsDb == null)
    return

  let key = getWeaponDbKey(weaponBlkPath, wBlk)
  let activeBulletIndex = wBlk?.weaponType ?? -1

  if (!(key in barrelsDb)) {
    let munitionData = readMunitionData(wBlk)
    barrelsDb[key] <- {
      raw = readRawFields(wBlk, WEAPON_RAW_FIELDS)
      weaponKind = getWeaponKind(wBlk)
      munition = munitionData
      weaponType = activeBulletIndex
      units = []
    }

    let candidates = []
    pushNonEmptyUnique(candidates, munitionData?.bulletName ?? "")
    pushNonEmptyUnique(candidates, key)
    pushNonEmptyUnique(candidates, munitionData?.bulletType ?? "")
    storeLocIds(barrelsDb[key], candidates, key)
  }

  appendOnce(unitName, barrelsDb[key].units)

  if (barrelsDb[key].munition != null) {
    let penetration = calcWeaponPenetration(unitName, weaponBlkPath, barrelsDb[key].munition, wBlk)
    if (penetration != null) {
      if (!("penetrationByUnit" in barrelsDb[key].munition))
        barrelsDb[key].munition.penetrationByUnit <- {}
      barrelsDb[key].munition.penetrationByUnit[unitName] <- penetration
    }
  }
}

function processUnitIntoDb(db, unitName, errors, barrelsDb = null, projectilesDb = null) {
  let paths = collectWeaponPathsFromUnitBlk(unitName)
  let availableSets = collectAvailableBulletSetNames(unitName)
  let effectToMod = buildEffectToModMap(unitName)
  let errorsBefore = errors.len()

  foreach (path, _meta in paths) {
    try {
      let wBlk = blkOptFromPathCachedByUnit(path, unitName)
      if (wBlk == null)
        continue

      if (isNonBulletThrowableWeapon(wBlk)) {
        log($"weapons export: skipping non-bullet weapon (grenade/selector stub): unit={unitName} {path}")
        continue
      }

      addSetToDb(db, unitName, path, "", wBlk,
        availableSets, projectilesDb, effectToMod, errors)

      let n = wBlk.blockCount()
      for (local i = 0; i < n; i++) {
        let sub = wBlk.getBlock(i)
        let name = sub.getBlockName()

        if (name == "bullet")
          continue
        if (name.indexof("@override:") == 0)
          continue
        if ((sub % "bullet").len() == 0)
          continue

        addSetToDb(db, unitName, path, name, sub,
          availableSets, projectilesDb, effectToMod, errors)
      }

      addBarrelToDb(barrelsDb, unitName, path, wBlk)
    } catch (e) {
      errors.append($"unit {unitName} weapon {path}: {e}")
    }
  }

  return errors.len() - errorsBefore
}

function debug_build_weapons_db_one(unitName) {
  let outPath = "export/weapons_db.json"
  let db = {}
  let barrelsDb = {}
  let projectilesDb = {}
  let errors = []

  processUnitIntoDb(db, unitName, errors, barrelsDb, projectilesDb)
  saveExportDbJson(outPath, makeExportDb(db, projectilesDb, barrelsDb))

  log($"DONE one unit={unitName}: bullets={db.len()} projectileRefs={projectilesDb.len()} barrels={barrelsDb.len()} errors={errors.len()} -> {outPath}")
}

let exportRunningState = { running = false }

function startBuildWeaponsDbAsync(onlyUnitName, outPath, batchSize, delay, statusPath = null, onDone = null) {
  if (exportRunningState.running) {
    logerr("weapons DB export rejected: another weapons export (DB or loc) is already running")
    return false
  }
  exportRunningState.running = true

  let db = {}
  let barrelsDb = {}
  let projectilesDb = {}
  let errors = []
  let units = onlyUnitName != "" ? [getAllUnits()?[onlyUnitName]] : getAllUnits().values()

  let total = units.len()
  local idx = 0
  local processedUnits = 0
  let status = ExporterStatus(statusPath ?? "")
  status.setTargetDetails(TARGET_WEAPONS_INFO, {
    state = "processing"
    totalUnitsLen = total
    leftUnitsLen = total
    processedUnitsLen = processedUnits
    failedUnits = []
    outPath = outPath
    onlyUnitName = onlyUnitName
    bullets = 0
    projectileRefs = 0
    weapons = 0
    errors = 0
  })
  function safeFlushStatus() {
    try {
      status.forceFlushToFile()
    } catch (e) {
      logerr($"failed to write weapons DB status: {e}")
    }
  }

  safeFlushStatus()

  log($"building weapons DB: totalUnits={total} onlyUnit={onlyUnitName}")

  function failBuild(phase, e) {
    let errText = $"weapons DB export failed at {phase}: {e}"
    errors.append(errText)

    let details = status.getTargetDetails(TARGET_WEAPONS_INFO)
    details.state = "failed"
    details.error <- errText
    details.errors = errors.len()
    details.leftUnitsLen = total - idx
    details.processedUnitsLen = processedUnits
    details.bullets = db.len()
    details.projectileRefs = projectilesDb.len()
    details.weapons = barrelsDb.len()
    status.finishTarget(TARGET_WEAPONS_INFO, false)
    safeFlushStatus()

    exportRunningState.running = false
    logerr(errText)
  }

  function step() {
    try {
      let end = min(idx + batchSize, total)

      for (local i = idx; i < end; i++) {
        let unit = units[i]
        if (unit == null)
          continue
        try {
          let unitErrors = processUnitIntoDb(db, unit.name, errors, barrelsDb, projectilesDb)
          processedUnits++
          if (unitErrors > 0)
            status.getTargetDetails(TARGET_WEAPONS_INFO).failedUnits.append(unit.name)
        } catch (e) {
          errors.append($"unit {unit.name}: {e}")
          status.getTargetDetails(TARGET_WEAPONS_INFO).failedUnits.append(unit.name)
        }
      }

      let details = status.getTargetDetails(TARGET_WEAPONS_INFO)
      details.leftUnitsLen = total - end
      details.processedUnitsLen = processedUnits
      details.bullets = db.len()
      details.projectileRefs = projectilesDb.len()
      details.weapons = barrelsDb.len()
      details.errors = errors.len()
      try {
        status.periodicFlushToFile()
      } catch (e) {
        logerr($"failed to write periodic weapons DB status: {e}")
      }

      log($"[{end}/{total}] bullets={db.len()} projectileRefs={projectilesDb.len()} weapons={barrelsDb.len()} errors={errors.len()}")
      idx = end

      if (idx < total) {
        try {
          resetTimeout(delay, step)
        } catch (e) {
          failBuild("reschedule", e)
        }
        return
      }

      try {
        let exportDb = makeExportDb(db, projectilesDb, barrelsDb)
        let weapons = exportDb.weapons
        let exportBarrels = weapons.barrels
        let exportMunitions = weapons.munitions

        saveExportDbJson(outPath, exportDb)

        details.leftUnitsLen = 0
        details.state = "done"
        details.processedUnitsLen = processedUnits
        details.bullets = db.len()
        details.projectileRefs = projectilesDb.len()
        details.barrels <- exportBarrels.len()
        details.munitions <- exportMunitions.len()
        details.errors = errors.len()
        status.finishTarget(TARGET_WEAPONS_INFO, errors.len() == 0)
        safeFlushStatus()

        exportRunningState.running = false

        log($"DONE: bullets={db.len()} projectileRefs={projectilesDb.len()} barrels={exportBarrels.len()} munitions={exportMunitions.len()} errors={errors.len()} -> {outPath}")

        if (onDone != null) {
          try {
            onDone(exportDb)
          } catch (e) {
            logerr($"weapons DB export onDone failed: {e}")
          }
        }
      } catch (e) {
        failBuild("finalize", e)
      }
    } catch (e) {
      failBuild("step", e)
    }
  }

  step()
  return true
}


function makePath(path, fileName) {
  return path == "" ? fileName : $"{path}/{fileName}"
}

function build_weapons_db_async(params) {
  let path = params?.path ?? "export"
  let fileName = params?.fileName ?? params?.exportFileName ?? "weapons_db.json"
  let statusFileName = params?.statusFileName ?? params?.statusFile ?? "status.json"
  let onlyUnitName = params?.onlyUnitName ?? ""
  let batchSize = params?.batchSize ?? 5
  if (batchSize < 1)
    return "error: batchSize must be >= 1"
  let delay = params?.delay ?? 0.05
  let requestedLangs = params?.langs
  let locFileName = params?.locFileName ?? "weapons_loc.json"
  let locStatusFileName = params?.locStatusFileName ?? "weapons_loc_status.json"

  let curLang = getLocalLanguage()
  let onDone = (requestedLangs == null) ? null : function(exportDb) {
    buildWeaponsLoc({
      exportDb = exportDb
      path = path
      langs = requestedLangs
      locFileName = locFileName
      locStatusFileName = locStatusFileName
      curLang = curLang
      runningState = exportRunningState
    })
  }

  if (!startBuildWeaponsDbAsync(onlyUnitName, makePath(path, fileName), batchSize, delay, makePath(path, statusFileName), onDone))
    return "error: weapons DB export already running"
  return "ok"
}

function debug_build_weapons_db_async(onlyUnitName = "") {
  let outPath = "export/weapons_db.json"
  let batchSize = 5
  let delay = 0.05
  startBuildWeaponsDbAsync(onlyUnitName, outPath, batchSize, delay)
}

register_command(debug_build_weapons_db_one, "debug.build_weapons_db_one")
register_command(debug_build_weapons_db_async, "debug.build_weapons_db_async")

web_rpc.register_handler("exportWeaponsInfo", build_weapons_db_async)