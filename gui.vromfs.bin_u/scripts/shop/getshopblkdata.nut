//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { Point2 } = require("dagor.math")
let { get_shop_blk } = require("blkGetters")
const COUNT_REQ_FOR_FAKE_UNIT = 2

let fakeUnitConfig = {
  name = ""
  image = "!#ui/unitskin#random_unit.ddsx"
  rank = 1
  isFakeUnit = true
}

function genFakeUnitRanges(airBlk, country) {
  let ranges = []
  let fakeReqUnitsType = airBlk % "fakeReqUnitType"
  let fakeReqUnitsImage = airBlk % "fakeReqUnitImage"
  let fakeReqUnitsRank = airBlk % "fakeReqUnitRank"
  let fakeReqUnitsPosXY = airBlk % "fakeReqUnitPosXY"
  foreach (idx, unitType in fakeReqUnitsType) {
    let range = []
    let fakeUnitParams = fakeUnitConfig.__merge({
      name = unitType
      image = fakeReqUnitsImage?[idx] ?? "!#ui/unitskin#random_unit.ddsx"
      rank = fakeReqUnitsRank?[idx] ?? 2
      country = country
    })
    if (fakeReqUnitsPosXY?[idx])
      fakeUnitParams.rankPosXY <- fakeReqUnitsPosXY[idx]
    for (local i = 0; i < COUNT_REQ_FOR_FAKE_UNIT; i++) {
      let reqForFakeUnitParams = fakeUnitConfig.__merge({
        name = fakeUnitParams.name + "_" + i
        image = fakeUnitParams.image
        rank = fakeUnitParams.rank - 1
        country = country
        isReqForFakeUnit = true })
      let rankPosXY = fakeUnitParams?.rankPosXY
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

function getShopBlkTable(selAirName = "") {
  let shopData = []
  local curCountry = null
  local curPage = null

  let blk = get_shop_blk()

  let totalCountries = blk.blockCount()
  let selAir = getAircraftByName(selAirName)
  for (local c = 0; c < totalCountries; c++) {  //country
    let cblk = blk.getBlock(c)
    let countryData = {
      name = cblk.getBlockName()
      pages = []
    }

    local hasSquadronUnitsInCountry = false
    if (selAir && selAir.shopCountry == countryData.name)
      curCountry = countryData.name

    let totalPages = cblk.blockCount()
    for (local p = 0; p < totalPages; p++) {
      let pblk = cblk.getBlock(p)
      let pageData = {
        name = pblk.getBlockName()
        airList = []
        tree = null
        lines = []
      }
      local selected = false
      local hasRankPosXY = false
      local hasFakeUnits = false
      local hasSquadronUnits = false

      let totalRanges = pblk.blockCount()
      for (local r = 0; r < totalRanges; r++) {
        let rblk = pblk.getBlock(r)
        let rangeData = []
        let totalAirs = rblk.blockCount()

        for (local a = 0; a < totalAirs; a++) {
          let airBlk = rblk.getBlock(a)
          let airData = { name = airBlk.getBlockName() }
          local air = getAircraftByName(airBlk.getBlockName())
          if (air) {
            selected = selected || air.name == selAirName

            if (!air.isVisibleInShop())
              continue

            airData.air <- air
            airData.rank <- air.rank
            hasSquadronUnits = hasSquadronUnits || air.isSquadronVehicle()
          }
          else {  //aircraft group
            airData.airsGroup <- []
            let groupTotal = airBlk.blockCount()
            for (local ga = 0; ga < groupTotal; ga++) {
              let gAirBlk = airBlk.getBlock(ga)
              air = getAircraftByName(gAirBlk.getBlockName())
              if (!air || !air.isVisibleInShop())
                continue

              if (!("rank" in airData))
                airData.rank <- air.rank
              airData.airsGroup.append(air)
              selected = selected || air.name == selAirName
              hasSquadronUnits = hasSquadronUnits || air.isSquadronVehicle()
            }
            if (airData.airsGroup.len() == 0)
              continue

            if (airData.airsGroup.len() == 1) {
              airData.air <- airData.airsGroup[0]
              airData.$rawdelete("airsGroup")
            }

            airData.image <- airBlk?.image
          }
          if (airBlk?.reqAir != null)
            airData.reqAir <- airBlk.reqAir
          if (airBlk?.futureReqAir != null)
            airData.futureReqAir <- airBlk.futureReqAir
          if (airBlk?.futureReqAirDesc != null)
            airData.futureReqAirDesc <- airBlk.futureReqAirDesc
          if (airBlk?.rankPosXY) {
            airData.rankPosXY <- airBlk.rankPosXY
            hasRankPosXY = true
          }
          if (airBlk?.fakeReqUnitType) {
            let fakeUnitRanges = genFakeUnitRanges(airBlk, countryData.name)
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
        if (hasSquadronUnits) {
          pageData.hasSquadronUnits <- hasSquadronUnits
          hasSquadronUnitsInCountry = hasSquadronUnits
        }
      }
      if (selected) {
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
