
















let isIntersectRect = @(a, b) (a.y < b.y + b.h && a.y + a.h > b.y && a.x < b.x + b.w && a.x + a.w > b.x)
let isRectAInRectB  = @(a, b) (a.y > b.y && a.y + a.h < b.y + b.h && a.x > b.x && a.x + a.w < b.x + b.w)

function hasFreePlace(rects, rect, safeAreaRect = null) {
  if (safeAreaRect && !isRectAInRectB(rect, safeAreaRect))
    return false
  foreach (r in rects) {
    if (isIntersectRect(r, rect))
      return false
  }
  return true
}

function findPlaceForHintByRect(itemRect, rects, hintSize, padding, safeAreaRect = null) {
  if (!hasFreePlace(rects, itemRect))
    return null

  let w = hintSize.w
  let h = hintSize.h
  let candidates = [
    { x = itemRect.x + itemRect.w + padding,     y = itemRect.y,                            w, h }
    { x = itemRect.x + itemRect.w + padding,     y = itemRect.y + itemRect.h - h,           w, h }
    { x = itemRect.x,                            y = itemRect.y + itemRect.h + padding,     w, h }
    { x = itemRect.x,                            y = itemRect.y - padding - h,              w, h }
    { x = itemRect.x + itemRect.w - w,           y = itemRect.y + itemRect.h + padding,     w, h }
    { x = itemRect.x + itemRect.w - w,           y = itemRect.y - padding - h,              w, h }
  ]

  foreach (cand in candidates) {
    if (hasFreePlace(rects, cand, safeAreaRect)) {
      rects.append(itemRect)
      rects.append(cand)
      return cand
    }
  }
  return null
}

return {
  isIntersectRect
  isRectAInRectB
  hasFreePlace
  findPlaceForHintByRect
}