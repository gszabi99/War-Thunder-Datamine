from "%scripts/dagui_natives.nut" import shop_get_module_exp, wp_get_modification_cost_gold
from "%scripts/dagui_library.nut" import *

let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getModificationByName, getModificationBulletsGroup, isModResearched
} = require("%scripts/weaponry/modificationInfo.nut")
let { Cost } = require("%scripts/money.nut")
let { getTiersOpenedAndAwarded } = require("chardResearch")
let { get_ranks_blk } = require("blkGetters")
let { roundToDigits } = require("%sqstd/math.nut")
let { dynamic_content } = require("%sqstd/analyzer.nut")

const PROGRESS_ROUND_DIGITS = 3
const PROGRESS_MIN_VALUE = 0.001

let isModificationInTree = @(unit, mod) !mod.isHidden
  && !wp_get_modification_cost_gold(unit.name, mod.name)
  && getModificationBulletsGroup(mod.name) == ""

let commonProgressMods = dynamic_content({ })
let modsWndWidthRestrictions = { min = 6, max = 8 }
let sizeByTier = {}

let categoryTooltips = {
  bonus = @() loc("modification/category/bonus/tooltip", { bonus = get_ranks_blk().modsTierExpToAircraftCoef * 100 })
}

function shiftBranchY(branch, treeXY) {
  if (type(branch) == "array") { 
    foreach (item in branch)
      shiftBranchY(item, treeXY)
    return
  }

  if (type(branch) != "table") 
    return

  let { guiPosX, tier } = branch
  let { tierHeight = 0, offsetY = 0 } = sizeByTier?[tier]
  if (guiPosX not in treeXY)
    treeXY.resize(guiPosX + 1)

  if (treeXY?[guiPosX] == null)
    treeXY[guiPosX] = []

  if (tier not in treeXY[guiPosX])
    treeXY[guiPosX].resize(tier + 1)

  if (treeXY[guiPosX]?[tier] == null)
    treeXY[guiPosX][tier] = array(tierHeight, null)

  foreach (posIdx, item in treeXY[guiPosX][tier])
    if (item == null) {
      treeXY[guiPosX][tier][posIdx] = branch
      branch.guiPosY = posIdx + offsetY
      return
    }
}

function shiftMaxTierHeight(heightByTier, categoryTierHeight) {
  foreach (tier, tierHeightByPosX in categoryTierHeight) {
    let maxHeight = tierHeightByPosX.reduce(@(res, v) max(res, v), 0)
    if (tier not in heightByTier)
      heightByTier.resize(tier + 1, 0)
    heightByTier[tier] = max(maxHeight, heightByTier[tier])
  }
}

let modsTree = {
  tree = null
  ignoreGoldMods = true
  air = null
  hasEmptyColumn = false

  function findPathToMod(branch, modName) {
    foreach (idx, item in branch)
      if (type(item) == "table") { 
        if (item.name == modName)
          return [idx]
      }
      else if (type(item) == "array") { 
        let res = this.findPathToMod(item, modName)
        if (res != null) {
          res.insert(0, idx)
          return res
        }
      }
    return null
  }

  function mustBeInModTree(mod) {
    if (mod.isHidden)
      return false

    foreach (unitType in unitTypes.types)
      if (unitType.modClassOrder.indexof(mod.modClass) != null)
        return true
    return false
  }

  function insertMod(mod) {
    local prevMod = null
    if ("reqModification" in mod && mod.reqModification.len())
      prevMod = mod.reqModification[0]
    else if ("prevModification" in mod)
      prevMod = mod.prevModification

    if (!prevMod) { 
      if (!this.mustBeInModTree(mod))
        return true

      foreach (branch in this.tree)
        if (type(branch) == "array" && branch[0] == mod.modClass) {
          branch.append(mod)
          return true
        }
      this.tree.append([mod.modClass, mod])
      return true
    }

    let path = this.findPathToMod(this.tree, prevMod)
    if (!path)
      return false

    
    local branch = this.tree
    for (local i = 0; i < path.len() - 1; i++)
      branch = branch[path[i]]
    let curIdx = path[path.len() - 1]
    if (curIdx == 0) 
      branch.append(mod)
    else
      branch[curIdx] = [branch[curIdx], mod]
    return true
  }

  function generateTree(genAir) {
    this.air = genAir
    this.tree = [null] 
    if (!("modifications" in this.air))
      return this.tree

    this.tree.extend(this.air.unitType.modClassOrder.map(@(v) [v]))

    let notInTreeMods = []
    foreach (_idx, mod in this.air.modifications)
      if (getModificationBulletsGroup(mod.name) == "" &&
          this.mustBeInModTree(mod) &&
          (!this.ignoreGoldMods || !wp_get_modification_cost_gold(this.air.name, mod.name))
         )
        if (!this.insertMod(mod))
          notInTreeMods.append(mod)

    local haveChanges = true
    while (notInTreeMods.len() && haveChanges) {
      haveChanges = false
      for (local i = notInTreeMods.len() - 1; i >= 0; i--)
        if (this.insertMod(notInTreeMods[i])) {
          notInTreeMods.remove(i)
          haveChanges = true
        }
    }

    this.checkNotInTreeMods(notInTreeMods)
    this.clearEmptyClasses(this.tree)
    this.generateBonuses(this.tree)
    this.generatePositions(this.tree)

    if(this.hasEmptyColumn)
      this.insertFakeMods(this.tree)

    return this.tree
  }

  function combineTiersExp(tierData, branchExp) {
    foreach(key, value in branchExp) {
      let { tierReqExp = 0, tierEarnedExp = 0 } = tierData?[key]
      tierData[key] <- { tierReqExp = tierReqExp + value.tierReqExp, tierEarnedExp = tierEarnedExp + value.tierEarnedExp}
    }
    return tierData
  }

  function collectTreeItems(branch, res) {
    foreach (_idx, item in branch)
      if (type(item) == "table")
        res.append(item)
      else if (type(item) == "array")
        this.collectTreeItems(item, res)
    return res
  }

  function generateBonuses(tree) {
    let modsArray = this.collectTreeItems(tree, [])
    let airName = this.air.name
    let unit = this.air
    let tiersExp = modsArray.reduce(function(branchData, value) {
      let tier = value.tier
      let { tierReqExp = 0, tierEarnedExp = 0 } = branchData?[tier]
      let modReqExp = value?.reqExp ?? 0
      let modEarnedExp = isModResearched(unit, value) ? modReqExp : shop_get_module_exp(airName, value.name)
      branchData[tier] <- { tierReqExp = tierReqExp + modReqExp, tierEarnedExp = tierEarnedExp + modEarnedExp }
      return branchData
    }, {}).filter(@(value) value.tierReqExp > 0)

    this.calcCommonProgressMods(tiersExp)
    if(tiersExp.len() == 0)
      return

    let coef = get_ranks_blk().modsTierExpToAircraftCoef
    let bonusBranch = ["bonus"]
    tiersExp.each(function(value, key) {
      let { tierEarnedExp, tierReqExp } = value
      let progress = tierReqExp == 0 ? 1 : roundToDigits(tierEarnedExp.tofloat() / tierReqExp, PROGRESS_ROUND_DIGITS)
      let tierEarnedExpCost = Cost().setRp(tierEarnedExp).toStringWithParams({ isRpAlwaysShown = true })
      let tierReqExpCost = Cost().setRp(tierReqExp).toStringWithParams({ isRpAlwaysShown = true })
      let id = $"bonus_tier_{key}"
      value.__update({
        id
        name = id
        tier = key,
        isBonusTier = true
        bonus = " ".concat(loc("modification/tierBonus"), Cost().setRp(tierReqExp * coef).toStringWithParams({ isRpAlwaysShown = true }))
        isBonusReceived = getTiersOpenedAndAwarded(airName)?[$"tier{key}"] ?? false
        progress = progress < PROGRESS_MIN_VALUE ? 0 : progress
        tooltip = $"{tierEarnedExpCost} / {tierReqExpCost}"
      })
      bonusBranch.append(value)
    })

    tree.append(bonusBranch)
  }

  function calcCommonProgressMods(tiersExp) {
    if(tiersExp.len() == 0) {
      commonProgressMods.clear()
      commonProgressMods.hasSummary <- false
      return
    }

    let summary = tiersExp.reduce(function(res, value) {
      res.earnedExp += value.tierEarnedExp
      res.reqExp += value.tierReqExp
      return res
    }, { earnedExp = 0, reqExp = 0 })

    if(summary.reqExp == 0) {
      commonProgressMods.clear()
      commonProgressMods.hasSummary <- false
      return
    }

    commonProgressMods.clear()
    commonProgressMods.__update(summary)
    let progress = roundToDigits(summary.earnedExp.tofloat() / summary.reqExp, PROGRESS_ROUND_DIGITS)
    commonProgressMods.progress <- progress < PROGRESS_MIN_VALUE ? 0 : progress
    commonProgressMods.hasSummary <- true
  }

  function clearEmptyClasses(tree) {
    for (local i = tree.len() - 1; i >= 0; i--) {
      let branch = tree[i]
      if (branch != null && branch.len() <= 1)
        tree.remove(i)
    }
  }

  function shiftBranchX(branch, offsetX) {
    if (type(branch) == "table") 
      branch.guiPosX <- (branch?.guiPosX ?? 0) + offsetX
    else if (type(branch) == "array") { 
      if(branch[0] == "bonus") {
        if(offsetX < modsWndWidthRestrictions.min - 1)
          this.hasEmptyColumn = true
        offsetX = max(offsetX, modsWndWidthRestrictions.min - 1)
      }
      foreach (_idx, item in branch)
        this.shiftBranchX(item, offsetX)
    }
  }

  function getMergeBranchXOffset(branch, tiersTable) {
    if (type(branch) == "table") { 
      let curOffset = (tiersTable && (branch.tier in tiersTable)) ? tiersTable[branch.tier] : 0
      return curOffset - branch.guiPosX
    }
    else if (type(branch) == "array") { 
      local mergeOffset = 0
      foreach (idx, item in branch) {
        let offset = this.getMergeBranchXOffset(item, tiersTable)
        if (idx == 0 || mergeOffset < offset)
          mergeOffset = offset
      }
      return mergeOffset
    }
    return 0
  }

  function getTiersWidth(tiersTable, minWidth = 0) {
    local width = minWidth
    foreach (w in tiersTable)
      if (width < w)
        width = w
    return width
  }

  function addTiers(baseTiers, tiersToAdd, offset) {
    foreach (tier, w in tiersToAdd)
      baseTiers[tier] <- offset + w
    return baseTiers
  }

  function insertFakeMods(branch) {
    let fakeMod = {
      name = "fake"
      isFakeMod = true
      tier = 1
      guiPosX = modsWndWidthRestrictions.min - 2
      guiPosY = 0
    }

    let lastBranch = branch[branch.len() - 2]
    lastBranch.append([fakeMod])
  }

  function generatePositions(branch, heightByTier = null) {
    heightByTier = heightByTier ?? []
    this.hasEmptyColumn = false
    local hasSeveralRowsOnTier = false
    



    let isRoot = !branch[0] || type(branch[0]) == "string"
    let isCategory = branch[0] && type(branch[0]) == "string"
    let rootTier = isRoot ? -1 : branch[0].tier
    let sideBranches = [] 
                            
    let sideTiers = []
    local tiersTable = !isRoot || isCategory ? {} : null

    for (local i = 1; i < branch.len(); i++) {  
      let item = branch[i]
      local isSide = false
      local itemTiers = null
      if (type(item) == "table") { 
        item.guiPosX <- 0
        item.guiPosY <- item.tier - 1
        itemTiers = { [item.tier] = 1 }
        if (rootTier >= 0)
          for (local j = rootTier + 1; j < item.tier; j++) 
            itemTiers[j] <- 1
        isSide = isRoot || isCategory || (item.tier == rootTier && !hasSeveralRowsOnTier)
      }
      else if (type(item) == "array") { 
        itemTiers = this.generatePositions(item, heightByTier)
        if (type(item[0]) == "table") {
          isSide = item[0].tier == rootTier && !hasSeveralRowsOnTier
          if (rootTier >= 0)
            for (local j = rootTier + 1; j < item[0].tier; j++) 
              itemTiers[j] <- 1
        }
        else {
          isSide = true
        }
      }

      if (isSide) {
        sideBranches.append(item)
        sideTiers.append(itemTiers)
      }
      else {
        let offset = tiersTable.len() ? this.getMergeBranchXOffset(item, tiersTable) : 0
        if (offset)
          this.shiftBranchX(item, offset)
        this.addTiers(tiersTable, itemTiers, offset)
      }
    }

    if (!isRoot) {
      tiersTable[branch[0].tier] <- 1 
      branch[0].guiPosX <- 0
      branch[0].guiPosY <- branch[0].tier - 1
      if (sideBranches.len()) {
        assert(sideBranches.len() <= 2, $"Error: mod {branch[0].name} for {this.air.name} have more than 2 child modifications with same tier")
        let haveLeft = sideBranches.len() > 1
        let lastRight = haveLeft ? sideBranches.len() - 1 : sideBranches.len()
        for (local i = 0; i < lastRight; i++) {
          let offset = tiersTable.len() ? this.getMergeBranchXOffset(sideBranches[i], tiersTable) : 0
          if (offset)
            this.shiftBranchX(sideBranches[i], offset)
          this.addTiers(tiersTable, sideTiers[i], offset)
        }

        if (haveLeft) {
          let leftIdx = sideBranches.len() - 1
          let offset = this.getTiersWidth(sideTiers[leftIdx])
          if (offset) {
            this.shiftBranchX(branch, offset)
            this.shiftBranchX(sideBranches[leftIdx], -offset)
            tiersTable = this.addTiers(sideTiers[leftIdx], tiersTable, offset)
          }
        }
      }
    }
    else if (isCategory) { 
      let categoryTierHeight = {}
      foreach (freeMod in sideBranches) {
        freeMod.guiPosX = hasSeveralRowsOnTier ? 0
          : tiersTable?[freeMod.tier] ?? 0
        tiersTable[freeMod.tier] <- freeMod.guiPosX + 1

        if (!hasSeveralRowsOnTier)
          continue

        let { guiPosX, tier } = freeMod
        if (tier not in categoryTierHeight)
          categoryTierHeight[tier] <- {}
        if (guiPosX in categoryTierHeight[tier])
          categoryTierHeight[tier][guiPosX] = categoryTierHeight[tier][guiPosX] + 1
        else
          categoryTierHeight[tier][guiPosX] <- 1
      }
      shiftMaxTierHeight(heightByTier, categoryTierHeight)
    }
    else { 
      local width = 0
      let treeXY = []
      sizeByTier.clear()
      foreach (tier, height in heightByTier) {
        let prevTier = sizeByTier?[tier - 1]
        sizeByTier[tier] <- { tierHeight = height,
          offsetY = (prevTier?.tierHeight ?? 0) + (prevTier?.offsetY ?? 0) }
      }

      foreach (idx, item in sideBranches) {
        if (width > 0)
          this.shiftBranchX(item, width)
        width += this.getTiersWidth(sideTiers[idx], 1)
        if (hasSeveralRowsOnTier)
          shiftBranchY(item, treeXY)
      }
    }
    return tiersTable
  }

  function getBranchCorners(branch, curCorners = null) {
    if (!curCorners)
      curCorners = [{ guiPosX = -1, guiPosY = -1, tier = -1 },
        { guiPosX = -1, guiPosY = -1, tier = -1 }]
    foreach (_idx, item in branch)
      if (type(item) == "table") { 
        foreach (p in ["guiPosX", "guiPosY", "tier"]) {
          if (item[p] < curCorners[0][p] || curCorners[0][p] < 0)
            curCorners[0][p] = item[p]
          if (item[p] + 1 > curCorners[1][p] || curCorners[1][p] < 0)
            curCorners[1][p] = item[p] + 1
        }
      }
      else if (type(item) == "array") 
        curCorners = this.getBranchCorners(item, curCorners)
    return curCorners
  }

  function getBranchArrows(branch, curArrows = null) {
    if (!curArrows)
      curArrows = []

    let reqName = (type(branch[0]) == "table") ? branch[0].name : null
    foreach (_idx, item in branch) {
      local checkItem = null
      if (type(item) == "table") 
        checkItem = item
      else if (type(item) == "array") { 
        this.getBranchArrows(item, curArrows)
        if (type(item[0]) == "table")
          checkItem = item[0]
      }

      let r = function(f) {
        return (f * 2.0).tointeger().tofloat() * 0.5
      }

      if (checkItem && reqName && "reqModification" in checkItem
          && checkItem.reqModification.len() && checkItem.reqModification[0] == reqName)
        curArrows.append({
          reqMod = reqName
          from = [r(branch[0].guiPosX), branch[0].guiPosY]
          to =   [r(checkItem.guiPosX), checkItem.guiPosY]
        })
    }
    return curArrows
  }

  function generateBlocksAndArrows(genAir) {
    if (!this.air || this.air.name != genAir.name)
      this.generateTree(genAir)

    let res = { blocks = [], arrows = [], sizeByTier }
    if (!this.tree)
      return res

    foreach (_idx, item in this.tree)
      if (type(item) == "array") { 
        let corners = this.getBranchCorners(item)
        let category = type(item[0]) == "string" ? item[0] : ""
        let tooltip = categoryTooltips?[category]() ?? ""
        let block = {
          name = type(item[0]) == "string" ? loc($"modification/category/{item[0]}") : ""
          width = max(corners[1].guiPosX - corners[0].guiPosX, 1)
          tooltip
          haveTooltip = tooltip != ""
        }
        res.blocks.append(block)
      }
    res.arrows = this.getBranchArrows(this.tree)
    return res
  }

  function getTreeSize(genAir) {
    if (!this.air || this.air.name != genAir.name)
      this.generateTree(genAir)
    local rightCorner = this.getBranchCorners(this.tree)[1]
    rightCorner.tier--
    return rightCorner
  }

  function debugTree(branch = null, addStr = "DD: ") { 
    let debugLog = dlog 
    if (!branch)
      branch = this.tree
    foreach (_idx, item in branch)
      if (type(item) == "table") 
        debugLog($"{addStr}{item.name} ({item.tier}, {item?.guiPosX ?? 0}, {item?.guiPosY ?? 0})") 
      else if (type(item) == "array") { 
        debugLog($"{addStr}[") 
        this.debugTree(item,$"{addStr}  ")
        debugLog($"{addStr}]") 
      }
      else if (type(item) == "string")
        debugLog($"{addStr}modClass = {item}") 
  }

  function checkNotInTreeMods(notInTreeMods) { 
    if (notInTreeMods.len() == 0)
      return

    log($"incorrect modification requirements for air {this.air.name}")
    debugTableData(notInTreeMods)
    foreach (mod in notInTreeMods) {
      local prevName = ""
      if ("reqModification" in mod && mod.reqModification.len())
        prevName = mod.reqModification[0]
      else if ("prevModification" in mod)
        prevName = mod.prevModification
      let prevMod = getModificationByName(this.air, prevName)
      local res = ""
      if (!prevMod)
        res = "does not exist"
      else if (getModificationBulletsGroup(prevName) != "")
        res = "is bullets"
      else if (this.ignoreGoldMods && wp_get_modification_cost_gold(this.air.name, prevName))
        res = "is premium"
      else
        res = "have another incorrect requirement"
      log($"modification {prevName} required for {mod.name} {res}")
    }
    assert(false,$"Error: found incorrect modifications requirement for air {this.air.name}")
  }
}

function getNextTierModsCount(unit, tier) {
  if (tier < 1 || tier > unit.needBuyToOpenNextInTier.len() || !("modifications" in unit))
    return 0

  local req = unit.needBuyToOpenNextInTier[tier - 1]
  foreach (mod in unit.modifications)
    if (("tier" in mod) && mod.tier == tier
      && isModificationInTree(unit, mod)
      && isModResearched(unit, mod)
    )
      req--
  return max(req, 0)
}

return {
  generateModsTree    = @(air) modsTree.generateTree(air)
  generateModsBgElems = @(air) modsTree.generateBlocksAndArrows(air)
  getModsTreeSize     = @(air) modsTree.getTreeSize(air)
  isModificationInTree
  commonProgressMods
  modsWndWidthRestrictions
  debugTree           = @(branch = null, addStr = "DD: ") modsTree.debugTree(branch, addStr)
  getNextTierModsCount
}