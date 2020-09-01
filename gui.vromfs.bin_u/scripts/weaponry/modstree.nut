local { getModificationBulletsGroup } = require("scripts/weaponry/bulletsInfo.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")

local modsTree = {
  tree = null
  ignoreGoldMods = true
  air = null

  function findPathToMod(branch, modName)
  {
    foreach(idx, item in branch)
      if (typeof(item)=="table") //modification
      {
        if (item.name == modName)
          return [idx]
      }
      else if (typeof(item)=="array") //branch
      {
        local res = findPathToMod(item, modName)
        if (res!=null)
        {
          res.insert(0, idx)
          return res
        }
      }
    return null
  }

  function mustBeInModTree(mod)
  {
    if (mod.isHidden)
      return false

    foreach(unitType in unitTypes.types)
      if (unitType.modClassOrder.indexof(mod.modClass) != null)
        return true
    return false
  }

  function insertMod(mod)
  {
    local prevMod = null
    if ("reqModification" in mod && mod.reqModification.len())
      prevMod = mod.reqModification[0]
    else
      if ("prevModification" in mod)
        prevMod = mod.prevModification

    if (!prevMod) //generate only by first modification
    {
      if (!mustBeInModTree(mod))
        return true

      foreach(branch in tree)
        if (typeof(branch)=="array" && branch[0]==mod.modClass)
        {
          branch.append(mod)
          return true
        }
      tree.append([mod.modClass, mod])
      return true
    }

    local path = findPathToMod(tree, prevMod)
    if (!path) return false

    //put in right place
    local branch = tree
    for(local i = 0; i < path.len()-1; i++)
      branch = branch[path[i]]
    local curIdx = path[path.len()-1]
    if (curIdx==0) //this mod depends on branch root
      branch.append(mod)
    else
      branch[curIdx] = [branch[curIdx], mod]
    return true
  }

  function generateTree(genAir)
  {
    air = genAir
    tree = [null] //root
    if (!("modifications" in air))
      return tree

    foreach(ctg in genAir.unitType.modClassOrder)
      tree.append([ctg])

    local notInTreeMods = []
    foreach(idx, mod in air.modifications)
      if (getModificationBulletsGroup(mod.name) == "" &&
          mustBeInModTree(mod) &&
          (!ignoreGoldMods || !::wp_get_modification_cost_gold(air.name, mod.name))
         )
        if (!insertMod(mod))
          notInTreeMods.append(mod)

    local haveChanges = true
    while (notInTreeMods.len() && haveChanges)
    {
      haveChanges = false
      for(local i = notInTreeMods.len()-1; i>=0; i--)
        if (insertMod(notInTreeMods[i]))
        {
          notInTreeMods.remove(i)
          haveChanges = true
        }
    }
    checkNotInTreeMods(notInTreeMods)

    clearEmptyClasses(tree)

    generatePositions(tree)
    return tree
  }

  function clearEmptyClasses(tree)
  {
    for (local i = tree.len() - 1; i >= 0; i--)
    {
      local branch = tree[i]
      if (branch != null && branch.len() <= 1)
        tree.remove(i)
    }
  }

  function shiftBranchX(branch, offsetX)
  {
    if (typeof(branch)=="table") //modification
      branch.guiPosX <- (("guiPosX" in branch)? branch.guiPosX : 0.0) + offsetX
    else if (typeof(branch)=="array") //branch
      foreach(idx, item in branch)
        shiftBranchX(item, offsetX)
  }

  function getMergeBranchXOffset(branch, tiersTable)
  {
    if (typeof(branch)=="table") //modification
    {
      local curOffset = (tiersTable && (branch.tier in tiersTable))? tiersTable[branch.tier] : 0
      return curOffset - branch.guiPosX
    } else
    if (typeof(branch)=="array") //branch
    {
      local mergeOffset = 0
      foreach(idx, item in branch)
      {
        local offset = getMergeBranchXOffset(item, tiersTable)
        if (idx==0 || mergeOffset < offset)
          mergeOffset = offset
      }
      return mergeOffset
    }
    return 0
  }

  function getTiersWidth(tiersTable, minWidth = 0)
  {
    local width = minWidth
    foreach(w in tiersTable)
      if (width<w)
        width = w
    return width
  }

  function addTiers(baseTiers, tiersToAdd, offset)
  {
    foreach(tier, w in tiersToAdd)
      baseTiers[tier] <- offset + w
    return baseTiers
  }

  function generatePositions(branch, tiersTable = null)
  {
    local isRoot = !branch[0] || typeof(branch[0])=="string"
    local isCategory = branch[0] && typeof(branch[0])=="string"
    local rootTier = isRoot? -1 : branch[0].tier
    local sideBranches = [] //mods with same tier with they req mod tier
                            //in tree root here is mods without any branch
    local sideTiers = []

    if (!tiersTable && (!isRoot || isCategory))
      tiersTable = {}

    for(local i = 1; i<branch.len(); i++)  //0 = root
    {
      local item = branch[i]
      local isSide = false
      local itemTiers = null
      if (typeof(item)=="table") //modification
      {
        item.guiPosX <- 0.0
        itemTiers = { [item.tier] = 1.0 }
        if (rootTier>=0)
          for(local j = rootTier+1; j<item.tier; j++) //place for lines
            itemTiers[j] <- 1.0
        isSide = isRoot || isCategory || item.tier == rootTier
      } else if (typeof(item)=="array") //branch
      {
        itemTiers = generatePositions(item)
        if (typeof(item[0])=="table")
        {
          isSide = item[0].tier == rootTier
          if (rootTier>=0)
            for(local j = rootTier+1; j<item[0].tier; j++) //place for lines
              itemTiers[j] <- 1.0
        }
        else
        {
          isSide = true
        }
      }

      if (isSide)
      {
        sideBranches.append(item)
        sideTiers.append(itemTiers)
      } else
      {
        local offset = tiersTable.len()? getMergeBranchXOffset(item, tiersTable) : 0
        if (offset)
          shiftBranchX(item, offset)
        addTiers(tiersTable, itemTiers, offset)
      }
    }

    if (!isRoot)
    {
      tiersTable[branch[0].tier] <- 1.0 //all items with same tier are side-tiers
      branch[0].guiPosX <- 0.0 //0.5 * (width - 1)
      if (sideBranches.len())
      {
        ::dagor.assertf(sideBranches.len() <= 2, "Error: mod " + branch[0].name + " for "+ air.name + " have more than 2 child modifications with same tier")
        local haveLeft = sideBranches.len()>1
        local lastRight = haveLeft? sideBranches.len()-1 : sideBranches.len()
        for(local i=0; i<lastRight; i++)
        {
          local offset = tiersTable.len()? getMergeBranchXOffset(sideBranches[i], tiersTable) : 0
          if (offset)
            shiftBranchX(sideBranches[i], offset)
          addTiers(tiersTable, sideTiers[i], offset)
        }

        if (haveLeft)
        {
          local leftIdx = sideBranches.len()-1
          local offset = getTiersWidth(sideTiers[leftIdx])
          if (offset)
          {
            shiftBranchX(branch, offset)
            shiftBranchX(sideBranches[leftIdx], -offset)
            tiersTable = addTiers(sideTiers[leftIdx], tiersTable, offset)
          }
        }
      }
    } else
    if (isCategory) //category
    {
      foreach(freeMod in sideBranches)
      {
        freeMod.guiPosX = freeMod.tier in tiersTable? tiersTable[freeMod.tier] : 0
        tiersTable[freeMod.tier] <- freeMod.guiPosX + 1.0
      }
    } else //mainRoot
    {
      local width = 0
      foreach(idx, item in sideBranches)
      {
        if (width>0)
          shiftBranchX(item, width)
        width += getTiersWidth(sideTiers[idx], 1)
      }
    }
    return tiersTable
  }

  function getBranchCorners(branch, curCorners = null)
  {
    if (!curCorners)
      curCorners = [{ guiPosX = -1, tier = -1}, { guiPosX = -1, tier = -1}]
    foreach(idx, item in branch)
      if (typeof(item)=="table") //modification
      {
        foreach(p in ["guiPosX", "tier"])
        {
          if (item[p] < curCorners[0][p] || curCorners[0][p] < 0)
            curCorners[0][p] = item[p]
          if (item[p] + 1 > curCorners[1][p] || curCorners[1][p] < 0)
            curCorners[1][p] = item[p] + 1
        }
      }
      else if (typeof(item)=="array") //branch
        curCorners = getBranchCorners(item, curCorners)
    return curCorners
  }

  function getBranchArrows(branch, curArrows = null)
  {
    if (!curArrows)
      curArrows = []

    local reqName = (typeof(branch[0])=="table")? branch[0].name : null
    foreach(idx, item in branch)
    {
      local checkItem = null
      if (typeof(item)=="table") //modification
        checkItem = item
      else if (typeof(item)=="array") //branch
      {
        getBranchArrows(item, curArrows)
        if (typeof(item[0])=="table")
          checkItem = item[0]
      }

      local r = function(f)
      {
        return (f*2.0).tointeger().tofloat()*0.5
      }

      if (checkItem && reqName && "reqModification" in checkItem
          && checkItem.reqModification.len() && checkItem.reqModification[0]==reqName)
        curArrows.append({
          reqMod = reqName
          from = [r(branch[0].guiPosX), branch[0].tier]
          to =   [r(checkItem.guiPosX), checkItem.tier]
        })
    }
    return curArrows
  }

  function generateBlocksAndArrows(genAir)
  {
    if (!air || air.name!=genAir.name)
      generateTree(genAir)

    local res = { blocks = [], arrows = [] }
    if (!tree)
      return res

    foreach(idx, item in tree)
      if (typeof(item)=="array") //branch
      {
        local corners = getBranchCorners(item)
        local block = {
          name = typeof(item[0])=="string"? ::loc("modification/category/" + item[0]) : ""
          width = ::max(corners[1].guiPosX - corners[0].guiPosX, 1)
        }
        res.blocks.append(block)
      }
    res.arrows = getBranchArrows(tree)
    return res
  }

  function getTreeSize(genAir)
  {
    if (!air || air.name!=genAir.name)
      generateTree(genAir)
    local rightCorner = getBranchCorners(tree)[1]
    rightCorner.tier--
    return rightCorner
  }

  function debugTree(branch=null, addStr="DD: ") //!!debug only
  {
    local debugLog = ::dlog // warning disable: -forbidden-function
    if (!branch)
      branch = tree
    foreach(idx, item in branch)
      if (typeof(item)=="table") //modification
        debugLog($"{addStr}{item.name} ({item.tier}, {item?.guiPosX ?? 0})")
      else if (typeof(item)=="array") //branch
      {
        debugLog($"{addStr}[")
        debugTree(item, addStr + "  ")
        debugLog($"{addStr}]")
      } else if (typeof(item)=="string")
        debugLog($"{addStr}modClass = {item}")
  }

  function checkNotInTreeMods(notInTreeMods) //for debug and assertion only
  {
    if (notInTreeMods.len()==0)
      return

    dagor.debug("incorrect modification requirements for air " + air.name)
    debugTableData(notInTreeMods)
    foreach(mod in notInTreeMods)
    {
      local prevName = ""
      if ("reqModification" in mod && mod.reqModification.len())
        prevName = mod.reqModification[0]
      else if ("prevModification" in mod)
        prevName = mod.prevModification
      local prevMod = ::getModificationByName(air, prevName)
      local res = ""
      if (!prevMod)
        res = "does not exist"
      else if (getModificationBulletsGroup(prevName) != "")
        res = "is bullets"
      else if (ignoreGoldMods && ::wp_get_modification_cost_gold(air.name, prevName))
        res = "is premium"
      else
        res = "have another incorrect requirement"
      dagor.debug("modification " + prevName + " required for " + mod.name + " " + res)
    }
    ::dagor.assertf(false, "Error: found incorrect modifications requirement for air " + air.name)
  }
}

return {
  generateModsTree    = @(air) modsTree.generateTree(air)
  generateModsBgElems = @(air) modsTree.generateBlocksAndArrows(air)
  getModsTreeSize     = @(air) modsTree.getTreeSize(air)

  debugTree           = @(branch=null, addStr="DD: ") modsTree.debugTree(branch, addStr)
}