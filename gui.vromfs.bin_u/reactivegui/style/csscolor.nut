import "%appGlobals/style/cssColors.nut" as cssColors
import "%appGlobals/style/cssColorToInt.nut" as cssColorToInt
from "types" import String

function [pure] cssColor(name: string): int {
  local value = cssColors[name]
  while (value instanceof String) {
    if (!value.startswith("@"))
      return cssColorToInt(value)
    value = cssColors[value.slice(1)]
  }
  return value
}

return cssColor
