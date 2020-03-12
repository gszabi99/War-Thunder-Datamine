local function PictureAtlas(atlas_path_base) {
  local pictures = {}

  local cls = class {
    function _get(key) {
      if (key in pictures)
        return pictures[key]
      local pic = ::Picture(atlas_path_base+key)
      pictures[key] <- pic
      return pic
    }
  }

  return cls()
}


return PictureAtlas
