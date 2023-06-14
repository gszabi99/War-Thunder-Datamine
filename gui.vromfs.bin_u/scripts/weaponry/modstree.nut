//-file:plus-string
from "%scripts/dagui_library.nut" import *

let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getModificationByName, getModificationBulletsGroup
} = require("%scripts/weaponry/modificationInfo.nut")

let isModificationInTree = @(unit, mod) !mod.isHidden
  && !::wp_get_modification_cost_gold(unit.name, mod.name)
  && getModificationBulletsGroup(mod.name) == ""

let modsTree = {
  tree = null
  ignoreGoldMods = true
  air = null

  function findPathToMod(branch, modName) {
    foreach (idx, item in branch)
      if (type(item) == "table") { //modification
        if (item.name == modName)
          return [idx]
      }
      else if (type(item) == "array") { //branch
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

    if (!prevMod) { //generate only by first modification
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

    //put in right place
    local branch = this.tree
    for (local i = 0; i < path.len() - 1; i++)
      branch = branch[path[i]]
    let curIdx = path[path.len() - 1]
    if (curIdx == 0) //this mod depends on branch root
      branch.append(mod)
    else
      branch[curIdx] = [branch[curIdx], mod]
    return true
  }

  function generateTree(genAir) {
    this.air = genAir
    this.tree = [null] //root
    if (!("modifications" in this.air))
      return this.tree

    foreach (ctg in genAir.unitType.modClassOrder)
      this.tree.append([ctg])

    let notInTreeMods = []
    foreach (_idx, mod in this.air.modifications)
      if (getModificationBulletsGroup(mod.name) == "" &&
          this.mustBeInModTree(mod) &&
          (!this.ignoreGoldMods || !::wp_get_modification_cost_gold(this.air.name, mod.name))
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
    this.generatePositions(this.tree)
    return this.tree
  }

  function clearEmptyClasses(tree) {
    for (local i = tree.len() - 1; i >= 0; i--) {
      let branch = tree[i]
      if (branch != null && branch.len() <= 1)
        tree.remove(i)
    }
  }

  function shiftBranchX(branch, offsetX) {
    if (type(branch) == "table") //modification
      branch.guiPosX <- (("guiPosX" in branch) ? branch.guiPosX : 0.0) + offsetX
    else if (type(branch) == "array") //branch
      foreach (_idx, item in branch)
        this.shiftBranchX(item, offsetX)
  }

  function getMergeBranchXOffset(branch, tiersTable) {
    if (type(branch) == "table") { //modification
      let curOffset = (tiersTable && (branch.tier in tiersTable)) ? tiersTable[branch.tier] : 0
      return curOffset - branch.guiPosX
    }
    else if (type(branch) == "array") { //branch
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

  function generatePositions(branch, tiersTable = null) {
    let isRoot = !branch[0] || type(branch[0]) == "string"
    let isCategory = branch[0] && type(branch[0]) == "string"
    let rootTier = isRoot ? -1 : branch[0].tier
    let sideBranches = [] //mods with same tier with they req mod tier
                            //in tree root here is mods without any branch
    let sideTiers = []

    if (!tiersTable && (!isRoot || isCategory))
      tiersTable = {}

    for (local i = 1; i < branch.len(); i++) {  //0 = root
      let item = branch[i]
      local isSide = false
      local itemTiers = null
      if (type(item) == "table") { //modification
        item.guiPosX <- 0.0
        itemTiers = { [item.tier] = 1.0 }
        if (rootTier >= 0)
          for (local j = rootTier + 1; j < item.tier; j++) //place for lines
            itemTiers[j] <- 1.0
        isSide = isRoot || isCategory || item.tier == rootTier
      }
      else if (type(item) == "array") { //branch
        itemTiers = this.generatePositions(item)
        if (type(item[0]) == "table") {
          isSide = item[0].tier == rootTier
          if (rootTier >= 0)
            for (local j = rootTier + 1; j < item[0].tier; j++) //place for lines
              itemTiers[j] <- 1.0
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
      tiersTable[branch[0].tier] <- 1.0 //all items with same tier are side-tiers
      branch[0].guiPosX <- 0.0 //0.5 * (width - 1)
      if (sideBranches.len()) {
        assert(sideBranches.len() <= 2, "Error: mod " + branch[0].name + " for " + this.air.name + " have more than 2 child modifications with same tier")
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
    else if (isCategory) { //category
      foreach (freeMod in sideBranches) {
        freeMod.guiPosX = freeMod.tier in tiersTable ? tiersTable[freeMod.tier] : 0
        tiersTable[freeMod.tier] <- freeMod.guiPosX + 1.0
      }
    }
    else { //mainRoot
      local width = 0
      foreach (idx, item in sideBranches) {
        if (width > 0)
          this.shiftBranchX(item, width)
        width += this.getTiersWidth(sideTiers[idx], 1)
      }
    }
    return tiersTable
  }

  function getBranchCorners(branch, curCorners = null) {
    if (!curCorners)
      curCorners = [{ guiPosX = -1, tier = -1 }, { guiPosX = -1, tier = -1 }]
    foreach (_idx, item in branch)
      if (type(item) == "table") { //modification
        foreach (p in ["guiPosX", "tier"]) {
          if (item[p] < curCorners[0][p] || curCorners[0][p] < 0)
            curCorners[0][p] = item[p]
          if (item[p] + 1 > curCorners[1][p] || curCorners[1][p] < 0)
            curCorners[1][p] = item[p] + 1
        }
      }
      else if (type(item) == "array") //branch
        curCorners = this.getBranchCorners(item, curCorners)
    return curCorners
  }

  function getBranchArrows(branch, curArrows = null) {
    if (!curArrows)
      curArrows = []

    let reqName = (type(branch[0]) == "table") ? branch[0].name : null
    foreach (_idx, item in branch) {
      local checkItem = null
      if (type(item) == "table") //modification
        checkItem = item
      else if (type(item) == "array") { //branch
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
          from = [r(branch[0].guiPosX), branch[0].tier]
          to =   [r(checkItem.guiPosX), checkItem.tier]
        })
    }
    return curArrows
  }

  function generateBlocksAndArrows(genAir) {
    if (!this.air || this.air.name != genAir.name)
      this.generateTree(genAir)

    let res = { blocks = [], arrows = [] }
    if (!this.tree)
      return res

    foreach (_idx, item in this.tree)
      if (type(item) == "array") { //branch
        let corners = this.getBranchCorners(item)
        let block = {
          name = type(item[0]) == "string" ? loc("modification/category/" + item[0]) : ""
          width = max(corners[1].guiPosX - corners[0].guiPosX, 1)
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

  function debugTree(branch = null, addStr = "DD: ") { //!!debug only
    let debugLog = dlog // warning disable: -forbidden-function
    if (!branch)
      branch = this.tree
    foreach (_idx, item in branch)
      if (type(item) == "table") //modification
        debugLog($"{addStr}{item.name} ({item.tier}, {item?.guiPosX ?? 0})")
      else if (type(item) == "array") { //branch
        debugLog($"{addStr}[")
        this.debugTree(item, addStr + "  ")
        debugLog($"{addStr}]")
      }
      else if (type(item) == "string")
        debugLog($"{addStr}modClass = {item}")
  }

  function checkNotInTreeMods(notInTreeMods) { //for debug and assertion only
    if (notInTreeMods.len() == 0)
      return

    log("incorrect modification requirements for air " + this.air.name)
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
      else if (this.ignoreGoldMods && ::wp_get_modification_cost_gold(this.air.name, prevName))
        res = "is premium"
      else
        res = "have another incorrect requirement"
      log("modification " + prevName + " required for " + mod.name + " " + res)
    }
    assert(false, "Error: found incorrect modifications requirement for air " + this.air.name)
  }
}

return {
  generateModsTree    = @(air) modsTree.generateTree(air)
  generateModsBgElems = @(air) modsTree.generateBlocksAndArrows(air)
  getModsTreeSize     = @(air) modsTree.getTreeSize(air)
  isModificationInTree

  debugTree           = @(branch = null, addStr = "DD: ") modsTree.debugTree(branch, addStr)
}