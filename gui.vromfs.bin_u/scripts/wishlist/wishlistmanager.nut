import "DataBlock" as DataBlock
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, CONFIG_VALIDATION, broadcastEvent
from "chard" import getWishList, getMaxWishListSize, charSendBlk
from "%scripts/dagui_library.nut" import *

let { addTask } = require("%scripts/tasker.nut")

local wishlist = null

let updateWishList = @() wishlist = getWishList().units

function getCurrentWishListSize() {
  if (wishlist == null)
    updateWishList()
  return wishlist.len()
}

function hasInWishlist(unitName) {
  if (wishlist == null)
    updateWishList()
  return wishlist.findvalue(@(value) (value.unit == unitName)) != null
}

function isWishlistFull() {
  if (wishlist == null)
    updateWishList()
  return wishlist.len() >= getMaxWishListSize()
}

let canAddUnitToWishlist = @(unit) unit != null && hasFeature("Wishlist")
  && !unit.isSlave() && !hasInWishlist(unit.name) && !unit.isBought()

let invalidateWishList = @() wishlist = null

function requestAddToWishlist(unitName, comment = "") {
  let blk = DataBlock()
  blk.setStr("type", "unit")
  blk.setStr("unit", unitName)
  blk.setStr("comment", comment)
  let taskId = charSendBlk("cln_add_to_wish_list", blk)
  let taskOptions = { showProgressBox = true }
  addTask(taskId, taskOptions, @() broadcastEvent("AddedToWishlist"))
}

function requestRemoveFromWishlist(unitName) {
  let blk = DataBlock()
  blk.setStr("type", "unit")
  blk.setStr("unit", unitName)
  let taskId = charSendBlk("cln_remove_from_wish_list", blk)
  let taskOptions = { showProgressBox = true }
  addTask(taskId, taskOptions)
}

addListenersWithoutEnv({ProfileUpdated = @(_p) invalidateWishList()}, CONFIG_VALIDATION)

return {
  hasInWishlist
  isWishlistFull
  canAddUnitToWishlist
  requestAddToWishlist
  requestRemoveFromWishlist
  getCurrentWishListSize
}
