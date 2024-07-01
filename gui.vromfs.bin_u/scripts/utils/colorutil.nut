from "math" import clamp

function color4ToInt(color) {
  let a = clamp((255 * color.a + 0.5).tointeger(), 0, 255)
  let r = clamp((255 * color.r + 0.5).tointeger(), 0, 255)
  let g = clamp((255 * color.g + 0.5).tointeger(), 0, 255)
  let b = clamp((255 * color.b + 0.5).tointeger(), 0, 255)
  return (a << 24) | (r << 16) | (g << 8) | b
}

return {
  color4ToInt
}