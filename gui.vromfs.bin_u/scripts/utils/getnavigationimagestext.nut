return function getNavigationImagesText(cur, total) {
  local res = ""
  if (total > 1) {
    local style = null
    if (cur > 0)
      style = (cur < total - 1) ? "all" : "left"
    else
      style = (cur < total - 1) ? "right" : null
    if (style)
      res = $"navImgStyle:t='{style}'; "
  }
  if (cur > 0)
    res = "".concat(res, "navigationImage{ type:t='left' } ")
  if (cur < total - 1)
    res = "".concat(res, "navigationImage{ type:t='right' } ")
  return res
}
