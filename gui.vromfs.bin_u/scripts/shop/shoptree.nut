local function getReqAirPosInArray(reqName, arr)
{
  foreach(r, row in arr)
    foreach(c, item in row)
      if (item && typeof item != "integer" && reqName == item.name)
        return [r, c]
  return null
}

local function checkBranchPos(tree, branch, row, col)
{
  for(local i = 0; i < branch.len(); i++)
  {
    local idxMax = branch[i].len()
    if (idxMax > tree[i+row].len() - col)
      idxMax = tree[i+row].len()-col
    for(local j = 0; j < idxMax; j++)
      if (tree[i+row][j+col] != null && branch[i][j] != null)
        return false
  }
  return true
}

local function getGoodBranchPos(tree, branch, offset, headerPos)
{
  //branch.
  if (headerPos)
  {
    if (checkBranchPos(tree, branch, headerPos[0], headerPos[1]))
      return headerPos[1]  //best place for header

    local colOffset = 0
    local pos = 0
    do
    {
      colOffset = -colOffset + ((colOffset<=0)? 1 : 0)
      pos = colOffset + headerPos[1]
      if ((pos in tree[0]) && checkBranchPos(tree, branch, offset, pos))
        return pos
    } while (pos < tree[0].len())
  }
  else
    for(local col=0; col<tree[0].len(); col++)
      if (checkBranchPos(tree, branch, offset, col))
        return col
  return tree[0].len()
}

local function makeTblByBranch(branch, ranksHeight, headRow = null)
{
  if (branch.len() < 1)
    return null

  local res = {
    offset = (headRow != null) ? headRow : 0/*branch[0].air.rank //for rowIdx==rank*/
    tbl = []
  }
  //if (headRow!=null)
  //  res.tbl.append([null])  //place for headAir in rowIdx==rank generation

  local prevAir = null
  foreach(idx, item in branch)
  {
    local curAir = null
    if (!::isUnitGroup(item))
      curAir = item.air
    else if(item?.isFakeUnit)
    {
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
    if (::isUnitGroup(item))
    {
      prevAir = null
      local unit = item.airsGroup?[0] //!!FIX ME: duplicate logic of generateUnitShopInfo
      if (unit && !::isUnitSpecial(unit) && !::isUnitGift(unit) && !unit.isSquadronVehicle())
      {
        prevAir = unit
        item.searchReqName <- unit.name
      }
    }
  }

  return res
}

local appendBranches
appendBranches = function(rangeData, headIdx, branches, brIdxTbl, prevItem=null)
{
  if (rangeData[headIdx].used)
    return

  if (prevItem!=null)
    rangeData[headIdx].reqAir <- prevItem.name

  local headers = []
  local curBranch = []
  local idx = headIdx
  do {
    local item = rangeData[idx]
    item.used = true
    curBranch.append(item)

    local next = (item.name in brIdxTbl)? brIdxTbl[item.name] : []
    if (idx < rangeData.len()-1 && !rangeData[idx+1]?.reqAir)
      next.append(idx+1)
    if (next.len()==0)
      idx=-1
    else if (rangeData[next[0]].used)
      ::dagor.fatal("Cycled requirements in shop!!!  look at " + rangeData[next[0]].name)
    else if (next.len()==1)
        idx=next[0]
    else
    {
      idx = next[next.len()-1]
      for(local i=next.len()-2; i>=0; i--)
        if (rangeData[next[i]].childs > rangeData[idx].childs
            || (rangeData[next[i]].childs == rangeData[idx].childs && rangeData[next[i]].rank > rangeData[idx].rank))
          idx = next[i]
      foreach(id in next)
        if (id!=idx)
          headers.append({prevItem = item, id=id})
    }
  } while (idx >= 0)

  local lastItemCurBranch = curBranch.top()
  if (branches.len()>0 && curBranch[0].rank == lastItemCurBranch.rank
      && (!lastItemCurBranch?.reqAir || lastItemCurBranch.reqAir==""))
  {  //for line branch generation. If NoReq aircrafts or all aircrafts curBranch have one rank then last extends previous branch.
    local placeFound = false
    foreach(bIdx, bItem in branches[branches.len()-1])
      if (bItem?.reqAir && bItem.reqAir=="" && bItem.rank >= curBranch[0].rank)
      {
        foreach(k, curItem in curBranch)
          branches[branches.len()-1].insert(bIdx+k, curBranch[k])
        placeFound = true
        break
      }
    if (!placeFound)
      branches[branches.len()-1].extend(curBranch)
  } else
    branches.append(curBranch)
  for(local h=headers.len()-1; h>=0; h--)
    appendBranches(rangeData, headers[h].id, branches, brIdxTbl, headers[h].prevItem)
}

local function getBranchesTbl(rangeData)
{
  local branches = []

  if (rangeData.len() < 2)
    return [rangeData]

  local addCount = {}
  local brIdxTbl = {}
  local rankK = 0.0 //the longer the tree is more important than a branched

  local maxCountId = rangeData.len() - 1
  for(local i = rangeData.len() - 1; i >= 0; i--)
  {
    local item = rangeData[i]
    item.childs <- 0
    item.used <- false
    item.header <- i == 0
    if ((i<rangeData.len() - 1) && !(rangeData[i + 1]?.reqAir))
      item.childs += rangeData[i + 1].childs + (1 + rankK * rangeData[i + 1].rank)
    if (item.name in addCount)
      item.childs += addCount.rawdelete(item.name)
    if (item?.reqAir)
      if (item.reqAir == "")
        item.header = true
      else
      {
        addCount[item.reqAir] <- item.childs + (1 + rankK*item.rank) + ((item.reqAir in addCount) ? addCount[item.reqAir] : 0)
        if (item.reqAir in brIdxTbl)
          brIdxTbl[item.reqAir].append(i)
        else
          brIdxTbl[item.reqAir] <- [i]
      }

    if (item.childs > rangeData[maxCountId].childs)
      maxCountId = i
  }

  appendBranches(rangeData, maxCountId, branches, brIdxTbl)
  for(local i = rangeData.len() - 1; i >= 0; i--)
    if (rangeData[i].header)
      appendBranches(rangeData, i, branches, brIdxTbl)
/*
  //test debug!
  local test = "GP: branches:"
  foreach(b in branches)
    foreach(idx, item in b)
      test += ((idx==0)? "\n" : ", ") + item.air.name + " ("+item.air.rank+","+item.childs+")"
               + (item?.reqAir ? "("+item.reqAir+")":"")
  dagor.debug(test)
*/
  return branches
}

//returns an array of positions of each rank in page and each vertical section in page
local function calculateRanksAndSectionsPos(page)
{
  local hasRankPosXY = page?.hasRankPosXY ?? false
  local res = array(::max_country_rank + 1, 0)
  local fakeRes = array(::max_country_rank + 1, 0)

  local sectionsPos = page.airList.len() ? [0, page.airList.len()] : [ 0 ]
  local foundPremium = false
  local maxColumns = 0

  for (local range = 0; range < page.airList.len(); range++)
  {
    local rangeRanks = array(::max_country_rank + 1, 0)
    local branches = getBranchesTbl(page.airList[range])

    foreach(branch in branches)
    {
      local isFakeBranch = false
      foreach(airItem in branch)
      {
        if (airItem?.isFakeUnit)
          isFakeBranch = true
        rangeRanks[airItem.rank] = hasRankPosXY?
          max(rangeRanks[airItem.rank], (airItem?.rankPosXY?.y ?? 1).tointeger())
          : rangeRanks[airItem.rank]+1
        maxColumns = max(maxColumns, (airItem?.rankPosXY?.x ?? 1).tointeger())
      }
      foreach(rankNum, rank in rangeRanks)
        if(isFakeBranch) // It is need for separate rows of fake units
        {
          if (fakeRes[rankNum] < rank)
            fakeRes[rankNum] = rank
        }
        else
          if (res[rankNum] < rank)
            res[rankNum] = rank

      if (!foundPremium || hasRankPosXY)
        foreach(airItem in branch)
          if (("air" in airItem) && (::isUnitSpecial(airItem.air) || ::isUnitGift(airItem.air)
            || airItem.air?.isSquadronVehicle?()))
          {
            if (!foundPremium)
            {
              sectionsPos.insert(1, hasRankPosXY? (airItem?.rankPosXY?.x ?? 1).tointeger()-1 : range)
              foundPremium = true
              if (!hasRankPosXY)
                break
            }
            else
              sectionsPos[1] = min(sectionsPos[1], (airItem?.rankPosXY?.x ?? 1).tointeger()-1)
          }
    }
  }
  if (hasRankPosXY)
    sectionsPos[sectionsPos.len()-1] = maxColumns
  //summ absolute height fr each rank
  for (local i = res.len() - 1; i >= 0; i--)
  {
    local rankStartPos = 0
    local j = 0
    while (j <= i)
    {
      rankStartPos += res[j] + fakeRes[j]
      j++
    }
    res[i] = rankStartPos
  }

  local sectionsResearchable = array(sectionsPos.len() - 1, true)
  if (foundPremium && sectionsResearchable.len())
    sectionsResearchable[sectionsResearchable.len() - 1] = false

  return {
    ranksHeight = res
    fakeRanksRowsCount = fakeRes
    sectionsPos = sectionsPos
    sectionsResearchable = sectionsResearchable
  }
}

local function getReqAirs(page)
{
  local reqAirs = {}
  for(local i = page.tree.len() - 1; i >= 0; i--)
    for(local j = page.tree[i].len() - 1; j >= 0; j--)
    {
      if(page.tree[i][j] == null)
        continue
      if(typeof(page.tree[i][j]) == "integer")
        page.tree[i][j] = null
      else
      {
        local air = page.tree[i][j]
        local reqUnit = []
        if (air?.fakeReqUnits)
          reqUnit.extend(air.fakeReqUnits)
        if (air?.reqAir)
          reqUnit.append(air.reqAir)
        foreach (unitName in reqUnit)
          if (unitName in reqAirs)
            reqAirs[unitName].append({ air = air, pos = [i,j] })
          else
            reqAirs[unitName] <- [{ air = air, pos = [i,j] }]
       }
    }
  return reqAirs
}

local function fillLinesInPage(page)
{
  local reqAirs = getReqAirs(page)

  for(local i = page.tree.len() - 1; i >= 0; i--)
    for(local j = page.tree[i].len() - 1; j >= 0; j--)
    {
      if(page.tree[i][j] == null)
        continue
      if(typeof(page.tree[i][j]) == "integer")
        page.tree[i][j] = null
      else
      {
        local air = page.tree[i][j]
        local searchName = ::isUnitGroup(air) ? air?.searchReqName : air.name
        if (searchName in reqAirs)
        {
          local arrowCount = reqAirs[searchName].len()
          foreach(req in reqAirs[searchName])
            page.lines.append({
              air = req.air,
              line = [i, j, req.pos[0], req.pos[1]]
              group = [::isUnitGroup(air), ::isUnitGroup(req.air)]
              reqAir = air
              arrowCount = arrowCount
            })
          reqAirs.rawdelete(searchName)
        }
      }
    }
}

local function generatePageTreeByRank(page)
{
  local treeSize = page.ranksHeight[page.ranksHeight.len() - 1]
  for (local range = 0; range < page.airList.len(); range++)
  {
    local rangeData = page.airList[range]
    local branches = getBranchesTbl(rangeData)
    local rangeTree = array(treeSize, null)
    foreach(idx, ar in rangeTree)
      rangeTree[idx] = []

    foreach(bIdx, branch in branches)
    {
      local headPos = null
      if (bIdx != 0 && branch[0]?.reqAir)
        headPos = getReqAirPosInArray(branch[0].reqAir, rangeTree)
      local config = makeTblByBranch(branch, page.ranksHeight, headPos ? headPos[0] : null)
        //config.offset, config.tbl
      local firstCol = getGoodBranchPos(rangeTree, config.tbl, config.offset, headPos)

      //merge branch to tree
      local treeWidth = 0
      foreach(item in config.tbl)
        if (treeWidth < firstCol + item.len())
          treeWidth = firstCol + item.len()
      if (treeWidth < rangeTree[0].len())
        treeWidth = rangeTree[0].len()

      for(local i = 0; i < rangeTree.len(); i++)
      {
        if (rangeTree[i].len() < treeWidth)
          rangeTree[i].resize(treeWidth, null)

        local addRowIdx = i - config.offset
        if (addRowIdx in config.tbl)
        {
          local addRow = config.tbl[addRowIdx]
          foreach(j, item in addRow)
            if (item != null)
            {
              if (rangeTree[i][j + firstCol] != null)
                dagor.debug("GP: try to fill not empty cell!!!!! ")
              rangeTree[i][j + firstCol] = item
            }
        }
      }
      //branch merged
    }

    //merge rangesTbl into tree and fill range lines
    foreach(r, row in page.tree)
      page.tree[r].extend(rangeTree[r])
  }
}

local function generatePageTreeByRankPosXY(page)
{
  local unitsWithWrongPositions = []
  for (local range = 0; range < page.airList.len(); range++)
  {
    local rangeData = page.airList[range]
    local branches = getBranchesTbl(rangeData)

    foreach(bIdx, branch in branches)
    {
      foreach (unit in branch)
      {
        local rankPosXY = unit?.rankPosXY
        if (!rankPosXY)
        {
          if (!::isInArray(unit.name, unitsWithWrongPositions))
            unitsWithWrongPositions.append(unit.name)
          continue
        }
        local absolutePosX= rankPosXY.x
        local absolutePosY= rankPosXY.y + page.ranksHeight[unit.rank-1]
          + (!unit?.isFakeUnit ? page.fakeRanksRowsCount[unit.rank] : 0)
        if (page.tree[absolutePosY-1].len() < absolutePosX)
          page.tree[absolutePosY-1].resize(absolutePosX, null)
        if (page.tree[absolutePosY-1][absolutePosX-1] != null)
        {
          local curUnit = page.tree[absolutePosY-1][absolutePosX-1]
          if (!::isInArray(unit.name, unitsWithWrongPositions))
            unitsWithWrongPositions.append(unit.name)
          if (!::isInArray(curUnit, unitsWithWrongPositions))
            unitsWithWrongPositions.append(curUnit.name)
        }
        page.tree[absolutePosY-1][absolutePosX-1] = unit?.air ?? unit
      }
    }
  }
  if (unitsWithWrongPositions.len() > 0)
  {
    local message = ::format("Error: Wrong rank position in shop config for unitType = %s\nunits: %s\n",
                             page.name,
                             ::g_string.implode(unitsWithWrongPositions, "\n")
                            )
    ::script_net_assert_once("Wrong rank position in shop config", message)
  }
}

local function generateTreeData(page)
{
  if (page.tree != null) //already generated
    return page

  page.lines = []
  page.tree = []

  if (!("airList" in page) || !page.airList)
    return page

  local ranksAndSections = calculateRanksAndSectionsPos(page)
  page.ranksHeight <- ranksAndSections.ranksHeight
  page.sectionsPos <- ranksAndSections.sectionsPos
  page.sectionsResearchable <- ranksAndSections.sectionsResearchable
  page.fakeRanksRowsCount <- ranksAndSections.fakeRanksRowsCount
  local treeSize = page.ranksHeight[page.ranksHeight.len() - 1]
  page.tree.resize(treeSize, null)
  foreach(idx, ar in page.tree)
    page.tree[idx] = []

  if (page?.hasRankPosXY)
    generatePageTreeByRankPosXY(page)
  else
    generatePageTreeByRank(page)

  //clear empty last lines
  local emptyLine = true
  for(local idx = page.tree.len() - 1; idx > 0; idx--)
  {
    foreach(i, air in page.tree[idx])
      if (air)
      {
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
      testText += ((idx==0)? "\n":"")
      if (item==null)
        testText+=" "
      else
      if (typeof(item)=="integer") testText += "."
      else testText += "A"
    }
  dagor.debug(testText + "\n done.")
*/
  //fill Lines and clear table
  fillLinesInPage(page)

  page.rawdelete("airList")
  return page
}

return {
  generateTreeData = generateTreeData
}
