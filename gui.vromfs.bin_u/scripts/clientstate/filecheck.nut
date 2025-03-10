from "%scripts/dagui_natives.nut" import web_vromfs_is_file_prefetched, web_vromfs_prefetch_file
from "%scripts/dagui_library.nut" import *

let regexp2 = require("regexp2")

let removeImgPostfixRegexpList = [
  regexp2("\\?P1$")
  regexp2("\\?x1ac$")
]
let removeImgPrefixRegexp = regexp2("^#")

function isImagePrefetched(img) {
  if (img == "")
    return true

  foreach (rg in removeImgPostfixRegexpList)
    img = rg.replace("", img)

  if (regexp2("^#[^\\s]+#[^\\s]").match(img)) 
    return true 

  img = removeImgPrefixRegexp.replace("", img)

  local res = true
  if (!web_vromfs_is_file_prefetched(img)) {
    res = false
    web_vromfs_prefetch_file(img)
  }
  return res
}

function isAllBlkImagesPrefetched(blk) {
  local res = true
  foreach (tag in ["background-image", "foreground-image"])
    foreach (img in (blk % tag))
      if (type(img) == "string")
        if (!isImagePrefetched(img))
          res = false

  let totalBlocks = blk.blockCount()
  for (local i = 0; i < totalBlocks; i++)
    if (!isAllBlkImagesPrefetched(blk.getBlock(i)))
      res = false

  return res
}

return {
  isAllBlkImagesPrefetched = isAllBlkImagesPrefetched
}