local removeImgPostfixRegexpList = [
  regexp2("\\?P1$")
  regexp2("\\?x1ac$")
]
local removeImgPrefixRegexp = regexp2("^#")

local function isImagePrefetched(img)
{
  if (img == "")
    return true

  foreach(rg in removeImgPostfixRegexpList)
    img = rg.replace("", img)

  if (regexp2("^#[^\\s]+#[^\\s]").match(img)) //skin
    return true //small skin icons not require to prefetch. But if so, need to correct check dynamic skins

  img = removeImgPrefixRegexp.replace("", img)

  local res = true
  if (!::web_vromfs_is_file_prefetched(img))
  {
    res = false
    ::web_vromfs_prefetch_file(img)
  }
  return res
}

local function isAllBlkImagesPrefetched(blk)
{
  local res = true
  foreach(tag in ["background-image", "foreground-image"])
    foreach(img in (blk % tag))
      if (typeof(img) == "string")
        if (!isImagePrefetched(img))
          res = false

  local totalBlocks = blk.blockCount()
  for(local i = 0; i < totalBlocks; i++)
    if (!isAllBlkImagesPrefetched(blk.getBlock(i)))
      res = false

  return res
}

return {
  isAllBlkImagesPrefetched = isAllBlkImagesPrefetched
}