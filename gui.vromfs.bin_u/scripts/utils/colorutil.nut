//checked for plus_string
#explicit-this
#no-root-fallback

let function color4ToInt(color) {
  let a = clamp((255 * color.a).tointeger(), 0, 255)
  let r = clamp((255 * color.r).tointeger(), 0, 255)
  let g = clamp((255 * color.g).tointeger(), 0, 255)
  let b = clamp((255 * color.b).tointeger(), 0, 255)
  return (a << 24) | (r << 16) | (g << 8) | b
}

return {
  color4ToInt
}