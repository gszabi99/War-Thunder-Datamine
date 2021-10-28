const COUNT_REQ_FOR_FAKE_UNIT = 2

local fakeUnitConfig = {
  name = ""
  image = "!#ui/unitskin#random_unit"
  rank = 1
  isFakeUnit = true
}

local function genFakeUnitRanges(airBlk, country) {
  local ranges = []
  local fakeReqUnitsType = airBlk % "fakeReqUnitType"
  local fakeReqUnitsImage = airBlk % "fakeReqUnitImage"
  local fakeReqUnitsRank = airBlk % "fakeReqUnitRank"
  local fakeReqUnitsPosXY = airBlk % "fakeReqUnitPosXY"
  foreach(idx, unitType in fakeReqUnitsType)
  {
    local range = []
    local fakeUnitParams = fakeUnitConfig.__merge({
      name = unitType
      image = fakeReqUnitsImage?[idx] ?? "!#ui/unitskin#random_unit"
      rank = fakeReqUnitsRank?[idx] ?? 2
      country = country
    })
    if (fakeReqUnitsPosXY?[idx])
      fakeUnitParams.rankPosXY <-fakeReqUnitsPosXY[idx]
    for(local i = 0; i < COUNT_REQ_FOR_FAKE_UNIT; i++)
    {
      local reqForFakeUnitParams = fakeUnitConfig.__merge({
        name = fakeUnitParams.name + "_" + i
        image = fakeUnitParams.image
        rank = fakeUnitParams.rank - 1
        country = country
        isReqForFakeUnit = true })
      local rankPosXY = fakeUnitParams?.rankPosXY
      if (rankPosXY)
        reqForFakeUnitParams.rankPosXY <- Point2(rankPosXY.x + (rankPosXY.x < 3 ? -i : i), 1)

      range.append(reqForFakeUnitParams)
    }
    fakeUnitParams.fakeReqUnits <- range.map(@(fakeReqUnit) fakeReqUnit.name)
    range.append(fakeUnitParams)
    ranges.append(range)
  }
  return ranges
}

local function getShopBlkTable(selAirName = "") {
  local shopData = []
  local curCountry = null
  local curPage = null

  local blk = ::get_shop_blk()

  local totalCountries = blk.blockCount()
  local selAir = ::getAircraftByName(selAirName)
  for(local c = 0; c < totalCountries; c++)  //country
  {
    local cblk = blk.getBlock(c)
    local countryData = {
      name = cblk.getBlockName()
      pages = []
    }

    local hasSquadronUnitsInCountry = false
    if (selAir && selAir.shopCountry == countryData.name)
      curCountry = countryData.name

    local totalPages = cblk.blockCount()
    for(local p = 0; p < totalPages; p++)
    {
      local pblk = cblk.getBlock(p)
      local pageData = {
        name = pblk.getBlockName()
        airList = []
        tree = null
        lines = []
      }
      local selected = false
      local hasRankPosXY =false
      local hasFakeUnits =false
      local hasSquadronUnits =false

      local totalRanges = pblk.blockCount()
      for(local r = 0; r < totalRanges; r++)
      {
        local rblk = pblk.getBlock(r)
        local rangeData = []
        local totalAirs = rblk.blockCount()

        for(local a = 0; a < totalAirs; a++)
        {
          local airBlk = rblk.getBlock(a)
          local airData = { name = airBlk.getBlockName() }
          local air = getAircraftByName(airBlk.getBlockName())
          if (air)
          {
            selected = selected || air.name == selAirName

            if (!air.isVisibleInShop())
              continue

            airData.air <- air
            airData.rank <- air.rank
            hasSquadronUnits = hasSquadronUnits || air.isSquadronVehicle()
          }
          else  //aircraft group
          {
            airData.airsGroup <- []
            local groupTotal = airBlk.blockCount()
            for(local ga = 0; ga < groupTotal; ga++)
            {
              local gAirBlk = airBlk.getBlock(ga)
              air = getAircraftByName(gAirBlk.getBlockName())
              if (!air || !air.isVisibleInShop())
                continue

              if (!("rank" in airData))
                airData.rank <- air.rank
              airData.airsGroup.append(air)
              selected = selected || air.name == selAirName
              hasSquadronUnits = hasSquadronUnits || air.isSquadronVehicle()
            }
            if (airData.airsGroup.len()==0)
              continue

            if (airData.airsGroup.len()==1)
            {
              airData.air <- airData.airsGroup[0]
              airData.rawdelete("airsGroup")
            }

            airData.image <- airBlk?.image
          }
          if (airBlk?.reqAir != null)
            airData.reqAir <- airBlk.reqAir
          if (airBlk?.rankPosXY)
          {
            airData.rankPosXY <- airBlk.rankPosXY
            hasRankPosXY = true
          }
          if (airBlk?.fakeReqUnitType)
          {
            local fakeUnitRanges = genFakeUnitRanges(airBlk, countryData.name)
            airData.fakeReqUnits <- fakeUnitRanges.map(@(range) (range.top()).name)
            pageData.airList = fakeUnitRanges.extend(pageData.airList)
            hasFakeUnits = true
          }
          rangeData.append(airData)
        }
        if (rangeData.len() > 0)
          pageData.airList.append(rangeData)
        if (hasRankPosXY)
          pageData.hasRankPosXY <- hasRankPosXY
        if (hasFakeUnits)
          pageData.hasFakeUnits <- hasFakeUnits
        if (hasSquadronUnits)
        {
          pageData.hasSquadronUnits <- hasSquadronUnits
          hasSquadronUnitsInCountry = hasSquadronUnits
        }
      }
      if (selected)
      {
        curCountry = countryData.name
        curPage = pageData.name
      }

      if (pageData.airList.len() > 0)
        countryData.pages.append(pageData)
      if (hasSquadronUnitsInCountry)
        countryData.hasSquadronUnits <- hasSquadronUnitsInCountry
    }
    if (countryData.pages.len() > 0)
      shopData.append(countryData)
  }

  return {
    shopData
    curCountry
    curPage
  }
}

return getShopBlkTable
