from "%rGui/globals/ui_library.nut" import *

function mkHudMessageStack(stack, mkContent, style) {
  let { entries } = stack
  let { vplace = null, entryPadding = null, transform = null, appearAnim = null, fadeAnim = null, faded = null } = style

  let mkEntry = @(entry) {
    key = entry.isFading ? $"fade{entry.id}" : entry.id
    size = FLEX_H
    padding = entryPadding
    transform
    animations = entry.isFading ? fadeAnim
      : entry.isNew ? appearAnim
      : null
    children = mkContent(entry)
    ...(entry.isFading ? faded : null)
  }

  return @() {
    watch = entries
    size = FLEX_H
    vplace
    flow = FLOW_VERTICAL
    children = entries.get().map(mkEntry)
  }
}

return mkHudMessageStack
