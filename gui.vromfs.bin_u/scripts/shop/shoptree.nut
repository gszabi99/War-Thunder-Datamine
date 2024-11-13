from "%scripts/dagui_library.nut" import *

let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let { format } = require("string")
let { fatal } = require("dagor.debug")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { isUnitGroup } = require("%scripts/unit/unitStatus.nut")
let { isUnitGift } = require("%scripts/unit/unitShopInfo.nut")
let { MAX_COUNTRY_RANK } = require("%scripts/ranks.nut")
let { get_shop_blk } = require("blkGetters")

function getReqAirPosInArray(reqName, arr) {
  foreach (r, row in arr)
    foreach (c, item in row)
      if (item && type(item) != "integer" && reqName == item.name)
        return [r, c]
  return null
}

function checkBranchPos(tree, branch, row, col) {
  for (local i = 0; i < branch.len(); i++) {
    local idxMax = branch[i].len()
    if (idxMax > tree[i + row].len() - col)
      idxMax = tree[i + row].len() - col
    for (local j = 0; j < idxMax; j++)
      if (tree[i + row][j + col] != null && branch[i][j] != null)
        return false
  }
  return true
}

function getGoodBranchPos(tree, branch, offset, headerPos) {
  //branch.
  if (headerPos) {
    if (checkBranchPos(tree, branch, headerPos[0], headerPos[1]))
      return headerPos[1]  //best place for header

    local colOffset = 0
    local pos = 0
    do {
      colOffset = -colOffset + ((colOffset <= 0) ? 1 : 0)
      pos = colOffset + headerPos[1]
      if ((pos in tree[0]) && checkBranchPos(tree, branch, offset, pos))
        return pos
    }
    while (pos < tree[0].len())
  }
  else
    for (local col = 0; col < tree[0].len(); col++)
      if (checkBranchPos(tree, branch, offset, col))
        return col
  return tree[0].len()
}

function makeTblByBranch(branch, ranksHeight, headRow = null) {
  if (branch.len() < 1)
    return null

  let res = {
    offset = (headRow != null) ? headRow : 0
    tbl = []
  }

  local prevAir = null
  foreach (_idx, item in branch) {
    local curAir = null
    if (!isUnitGroup(item))
      curAir = item.air
    else if (item?.isFakeUnit) {
      curAir = item
    }
    else {
      curAir = item
      if (item?.reqAir)
        prevAir = getAircraftByName(item.reqAir)
      if (prevAir)
        curAir.reqAir <- prevAir.name
    }

    //Line branch generation
    if (ranksHeight[curAir.rank - 1] > res.tbl.len())
      res.tbl.resize(ranksHeight[curAir.rank - 1], [])
    res.tbl.append([curAir])

    prevAir = curAir
    if (isUnitGroup(item)) {
      prevAir = null
      let unit = item.airsGroup?[0] //!!FIX ME: duplicate logic of generateUnitShopInfo
      if (unit && !isUnitSpecial(unit) && !isUnitGift(unit) && !unit.isSquadronVehicle()) {
        prevAir = unit
        item.searchReqName <- unit.name
      }
    }
  }

  return res
}

function appendBranches(rangeData, headIdx, branches, brIdxTbl, prevItem = null) {
  if (rangeData[headIdx].used)
    return

  if (prevItem != null)
    rangeData[headIdx].reqAir <- prevItem.name

  let headers = []
  let curBranch = []
  local idx = headIdx
  do {
    let item = rangeData[idx]
    item.used = true
    curBranch.append(item)

    let next = (item.name in brIdxTbl) ? brIdxTbl[item.name] : []
    if (idx < rangeData.len() - 1 && !rangeData[idx + 1]?.reqAir)
      next.append(idx + 1)
    if (next.len() == 0)
      idx = -1
    else if (rangeData[next[0]].used)
      fatal($"Cycled requirements in shop!!!  look at {rangeData[next[0]].name}")
    else if (next.len() == 1)
        idx = next[0]
    else {
      idx = next[next.len() - 1]
      for (local i = next.len() - 2; i >= 0; i--)
        if (rangeData[next[i]].childs > rangeData[idx].childs
            || (rangeData[next[i]].childs == rangeData[idx].childs && rangeData[next[i]].rank > rangeData[idx].rank))
          idx = next[i]
      foreach (id in next)
        if (id != idx)
          headers.append({ prevItem = item, id = id })
    }
  } while (idx >= 0)

  let lastItemCurBranch = curBranch.top()
  if (branches.len() > 0 && curBranch[0].rank == lastItemCurBranch.rank
      && (!lastItemCurBranch?.reqAir || lastItemCurBranch.reqAir == "")) {  //for line branch generation. If NoReq aircrafts or all aircrafts curBranch have one rank then last (previous branc)h.
    local placeFound = false
    foreach (bIdx, bItem in branches[branches.len() - 1])
      if (bItem?.reqAir && bItem.reqAir == "" && bItem.rank >= curBranch[0].rank) {
        foreach (k, _curItem in curBranch)
          branches[branches.len() - 1].insert(bIdx + k, curBranch[k]) //warning disable: -modified-container
        placeFound = true
        break
      }
    if (!placeFound)
      branches[branches.len() - 1].extend(curBranch)
  }
  else
    branches.append(curBranch)
  for (local h = headers.len() - 1; h >= 0; h--)
    appendBranches(rangeData, headers[h].id, branches, brIdxTbl, headers[h].prevItem)
}

function getBranchesTbl(rangeData) {
  let branches = []

  if (rangeData.len() < 2)
    return [rangeData]

  let addCount = {}
  let brIdxTbl = {}
  let rankK = 0.0 //the longer the tree is more important than a branched

  local maxCountId = rangeData.len() - 1
  for (local i = rangeData.len() - 1; i >= 0; i--) {
    let item = rangeData[i]
    item.childs <- 0
    item.used <- false
    item.header <- i == 0
    if ((i < rangeData.len() - 1) && !(rangeData[i + 1]?.reqAir))
      item.childs += rangeData[i + 1].childs + (1 + rankK * rangeData[i + 1].rank)
    if (item.name in addCount)
      item.childs += addCount.$rawdelete(item.name)
    let itemReqAir = item?.futureReqAir ?? item?.reqAir
    if (itemReqAir)
      if (itemReqAir == "")
        item.header = true
      else {
        addCount[itemReqAir] <- item.childs + (1 + rankK * item.rank) + ((itemReqAir in addCount) ? addCount[itemReqAir] : 0)
        if (itemReqAir in brIdxTbl)
          brIdxTbl[itemReqAir].append(i)
        else
          brIdxTbl[itemReqAir] <- [i]
      }

    if (item.childs > rangeData[maxCountId].childs)
      maxCountId = i
  }

  appendBranches(rangeData, maxCountId, branches, brIdxTbl)
  for (local i = rangeData.len() - 1; i >= 0; i--)
    if (rangeData[i].header)
      appendBranches(rangeData, i, branches, brIdxTbl)
/*
  //test debug!
  local test = "GP: branches:"
  foreach(b in branches)
    foreach(idx, item in b)
      test = "".concat(idx==0 ? "\n" : ", ", item.air.name, " (", item.air.rank, ",", item.childs, ")",
        item?.reqAir ? $"({item.reqAir})" : "")
  log(test)
*/
  return branches
}

//returns an array of positions of each rank in page and each vertical section in page
function calculateRanksAndSectionsPos(page) {
  let hasRankPosXY = page?.hasRankPosXY ?? false
  let res = array(MAX_COUNTRY_RANK + 1, 0)
  let fakeRes = array(MAX_COUNTRY_RANK + 1, 0)

  let sectionsPos = page.airList.len() ? [0, page.airList.len()] : [ 0 ]
  local foundPremium = false
  local maxColumns = 0

  for (local range = 0; range < page.airList.len(); range++) {
    let rangeRanks = array(MAX_COUNTRY_RANK + 1, 0)
    let branches = getBranchesTbl(page.airList[range])

    foreach (branch in branches) {
      local isFakeBranch = false
      foreach (airItem in branch) {
        if (airItem?.isFakeUnit)
          isFakeBranch = true
        rangeRanks[airItem.rank] = hasRankPosXY ?
          max(rangeRanks[airItem.rank], (airItem?.rankPosXY?.y ?? 1).tointeger())
          : rangeRanks[airItem.rank] + 1
        maxColumns = max(maxColumns, (airItem?.rankPosXY?.x ?? 1).tointeger())
      }
      foreach (rankNum, rank in rangeRanks)
        if (isFakeBranch) { // It is need for separate rows of fake units
          if (fakeRes[rankNum] < rank)
            fakeRes[rankNum] = rank
        }
        else if (res[rankNum] < rank)
            res[rankNum] = rank

      if (!foundPremium || hasRankPosXY)
        foreach (airItem in branch)
          if (("air" in airItem) && (isUnitSpecial(airItem.air) || isUnitGift(airItem.air)
            || airItem.air?.isSquadronVehicle?())) {
            if (!foundPremium) {
              sectionsPos.insert(1, hasRankPosXY ? (airItem?.rankPosXY?.x ?? 1).tointeger() - 1 : range)
              foundPremium = true
              if (!hasRankPosXY)
                break
            }
            else
              sectionsPos[1] = min(sectionsPos[1], (airItem?.rankPosXY?.x ?? 1).tointeger() - 1)
          }
    }
  }
  if (hasRankPosXY)
    sectionsPos[sectionsPos.len() - 1] = maxColumns
  // removing reserchable units section when only premium units found
  if (foundPremium && sectionsPos[1] == 0)
    sectionsPos.remove(0)

  //summ absolute height fr each rank
  for (local i = res.len() - 1; i >= 0; i--) {
    local rankStartPos = 0
    local j = 0
    while (j <= i) {
      rankStartPos += res[j] + fakeRes[j]
      j++
    }
    res[i] = rankStartPos
  }

  let sectionsResearchable = array(sectionsPos.len() - 1, true)
  if (foundPremium && sectionsResearchable.len())
    sectionsResearchable[sectionsResearchable.len() - 1] = false

  return {
    ranksHeight = res
    fakeRanksRowsCount = fakeRes
    sectionsPos = sectionsPos
    sectionsResearchable = sectionsResearchable
  }
}

function getReqAirs(page) {
  let reqAirs = {}
  for (local i = page.tree.len() - 1; i >= 0; i--)
    for (local j = page.tree[i].len() - 1; j >= 0; j--) {
      if (page.tree[i][j] == null)
        continue
      if (type(page.tree[i][j]) == "integer")
        page.tree[i][j] = null
      else {
        let air = page.tree[i][j]
        let reqUnit = []
        if (air?.fakeReqUnits)
          reqUnit.extend(air.fakeReqUnits)
        if (air?.reqAir)
          reqUnit.append(air.reqAir)
        if (air?.futureReqAir)
          reqUnit.append(air.futureReqAir)
        foreach (unitName in reqUnit)
          if (unitName in reqAirs)
            reqAirs[unitName].append({ air = air, pos = [i, j] })
          else
            reqAirs[unitName] <- [{ air = air, pos = [i, j] }]
      }
    }
  return reqAirs
}

function fillLinesInPage(page) {
  let reqAirs = getReqAirs(page)
  let futureReqAirsByBranch = []

  for (local i = page.tree.len() - 1; i >= 0; i--) {
    let branchsCount = page.tree[i].len()
    for (local j = branchsCount - 1; j >= 0; j--) {
      if (page.tree[i][j] == null)
        continue
      if (type(page.tree[i][j]) == "integer") {
        page.tree[i][j] = null
        continue
      }

      let air = page.tree[i][j]
      if (futureReqAirsByBranch.len() < branchsCount)
        futureReqAirsByBranch.resize(branchsCount)
      let searchName = isUnitGroup(air) ? air?.searchReqName : air.name
      if (searchName not in reqAirs) {
        futureReqAirsByBranch[j] = searchName == futureReqAirsByBranch[j] ? null
          : air?.futureReqAir != null ? (air?.reqAir ?? futureReqAirsByBranch[j])
          : futureReqAirsByBranch[j]
        continue
      }

      let arrowCount = reqAirs[searchName].len()
      let hasNextFutureReqLine = futureReqAirsByBranch[j] != null
      foreach (req in reqAirs[searchName])
        page.lines.append({
          air = req.air,
          line = [i, j, req.pos[0], req.pos[1]]
          group = [isUnitGroup(air), isUnitGroup(req.air)]
          reqAir = air
          arrowCount
          hasNextFutureReqLine
        })
      reqAirs.$rawdelete(searchName)
      futureReqAirsByBranch[j] = air?.futureReqAir != null && air?.reqAir != "" ? (air?.reqAir ?? futureReqAirsByBranch[j])
        : searchName == futureReqAirsByBranch[j] ? null
        : futureReqAirsByBranch[j]
    }
  }
}

function generatePageTreeByRank(page) {
  let treeSize = page.ranksHeight[page.ranksHeight.len() - 1]
  for (local range = 0; range < page.airList.len(); range++) {
    let rangeData = page.airList[range]
    let branches = getBranchesTbl(rangeData)
    let rangeTree = array(treeSize, null)
    foreach (idx, _ar in rangeTree)
      rangeTree[idx] = []

    foreach (bIdx, branch in branches) {
      local headPos = null
      if (bIdx != 0 && branch[0]?.reqAir)
        headPos = getReqAirPosInArray(branch[0].reqAir, rangeTree)
      let config = makeTblByBranch(branch, page.ranksHeight, headPos ? headPos[0] : null)
        //config.offset, config.tbl
      let firstCol = getGoodBranchPos(rangeTree, config.tbl, config.offset, headPos)

      //merge branch to tree
      local treeWidth = 0
      foreach (item in config.tbl)
        if (treeWidth < firstCol + item.len())
          treeWidth = firstCol + item.len()
      if (treeWidth < rangeTree[0].len())
        treeWidth = rangeTree[0].len()

      for (local i = 0; i < rangeTree.len(); i++) {
        if (rangeTree[i].len() < treeWidth)
          rangeTree[i].resize(treeWidth, null)

        let addRowIdx = i - config.offset
        if (addRowIdx in config.tbl) {
          let addRow = config.tbl[addRowIdx]
          foreach (j, item in addRow)
            if (item != null) {
              if (rangeTree[i][j + firstCol] != null)
                log("GP: try to fill not empty cell!!!!! ")
              rangeTree[i][j + firstCol] = item
            }
        }
      }
      //branch merged
    }

    //merge rangesTbl into tree and fill range lines
    foreach (r, _row in page.tree)
      page.tree[r].extend(rangeTree[r])
  }
}

function generatePageTreeByRankPosXY(page) {
  let unitsWithWrongPositions = []
  for (local range = 0; range < page.airList.len(); range++) {
    let rangeData = page.airList[range]
    let branches = getBranchesTbl(rangeData)

    foreach (_bIdx, branch in branches) {
      foreach (unit in branch) {
        let rankPosXY = unit?.rankPosXY
        if (!rankPosXY) {
          if (!isInArray(unit.name, unitsWithWrongPositions))
            unitsWithWrongPositions.append(unit.name)
          continue
        }
        let absolutePosX = rankPosXY.x
        let absolutePosY = rankPosXY.y + page.ranksHeight[unit.rank - 1]
          + (!unit?.isFakeUnit ? page.fakeRanksRowsCount[unit.rank] : 0)
        if (page.tree[absolutePosY - 1].len() < absolutePosX)
          page.tree[absolutePosY - 1].resize(absolutePosX, null)
        if (page.tree[absolutePosY - 1][absolutePosX - 1] != null) {
          let curUnit = page.tree[absolutePosY - 1][absolutePosX - 1]
          if (!isInArray(unit.name, unitsWithWrongPositions))
            unitsWithWrongPositions.append(unit.name)
          if (!isInArray(curUnit, unitsWithWrongPositions))
            unitsWithWrongPositions.append(curUnit.name)
        }
        page.tree[absolutePosY - 1][absolutePosX - 1] = unit?.air ?? unit
      }
    }
  }
  if (unitsWithWrongPositions.len() > 0) {
    let message = format("Error: Wrong rank position in shop config for unitType = %s\nunits: %s\n",
                             page.name,
                             "\n".join(unitsWithWrongPositions, true)
                            )
    script_net_assert_once("Wrong rank position in shop config", message)
  }
}

function generateTreeData(page) {
  if (page.tree != null) //already generated
    return page

  page.lines = []
  page.tree = []

  if (!("airList" in page) || !page.airList)
    return page

  let ranksAndSections = calculateRanksAndSectionsPos(page)
  page.ranksHeight <- ranksAndSections.ranksHeight
  page.sectionsPos <- ranksAndSections.sectionsPos
  page.sectionsResearchable <- ranksAndSections.sectionsResearchable
  page.fakeRanksRowsCount <- ranksAndSections.fakeRanksRowsCount
  let treeSize = page.ranksHeight[page.ranksHeight.len() - 1]
  page.tree.resize(treeSize, null)
  foreach (idx, _ar in page.tree)
    page.tree[idx] = []

  if (page?.hasRankPosXY)
    generatePageTreeByRankPosXY(page)
  else
    generatePageTreeByRank(page)

  //clear empty last lines
  local emptyLine = true
  for (local idx = page.tree.len() - 1; idx > 0; idx--) {
    foreach (_i, air in page.tree[idx])
      if (air) {
        emptyLine = false
        break
      }
    if (emptyLine)
      page.tree.remove(idx)
    else
      break
  }
/*
  //debug
  local testText = "GP: full table:"
  foreach(row in page.tree)
    foreach(idx, item in row)
    {
      testText = "".concat(testText, idx==0 ? "\n" : "")
      if (item==null)
        testText = $"{testText} "
      else if (type(item)=="integer")
        testText = $"{testText}."
      else
        testText = $"{testText}A"
    }
  log($"{testText}\n done.")
*/
  //fill Lines and clear table
  fillLinesInPage(page)

  page.$rawdelete("airList")
  return page
}

function checkShopBlk() {
  let resArray = []
  let shopBlk = get_shop_blk()
  for (local tree = 0; tree < shopBlk.blockCount(); tree++) {
    let tblk = shopBlk.getBlock(tree)
    let country = tblk.getBlockName()

    for (local page = 0; page < tblk.blockCount(); page++) {
      let pblk = tblk.getBlock(page)
      let groups = []
      for (local range = 0; range < pblk.blockCount(); range++) {
        let rblk = pblk.getBlock(range)
        for (local a = 0; a < rblk.blockCount(); a++) {
          let airBlk = rblk.getBlock(a)
          let airName = airBlk.getBlockName()
          local air = getAircraftByName(airName)
          if (!air) {
            let groupTotal = airBlk.blockCount()
            if (groupTotal == 0) {
              resArray.append($"Not found aircraft {airName} in {country}")
              continue
            }
            groups.append(airName)
            for (local ga = 0; ga < groupTotal; ga++) {
              let gAirBlk = airBlk.getBlock(ga)
              air = getAircraftByName(gAirBlk.getBlockName())
              if (!air)
                resArray.append($"Not found aircraft {gAirBlk.getBlockName()} in {country}")
            }
          }
          else if ((airBlk?.reqAir ?? "") != "") {
              let reqAir = getAircraftByName(airBlk.reqAir)
              if (!reqAir && !isInArray(airBlk.reqAir, groups))
                resArray.append($"Not found reqAir {airBlk.reqAir} for {airName} in {country}")
          }
        }
      }
    }
  }
  let resText = "\n".join(resArray, true)
  if (resText == "")
    log("Shop.blk checked.")
  else
    fatal($"Incorrect shop.blk!\n{resText}")
}

return {
  generateTreeData
  checkShopBlk
}
