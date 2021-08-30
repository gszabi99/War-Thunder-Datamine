//https://developer.mozilla.org/en-US/docs/Web/SVG/Tutorial/Gradients
//see example at https://briangrinstead.com/gradient/

local {encodeString} = require("base64")

local function mkGradPointStyle(point, idx, points){
  local offset = point?.offset ?? (100 * idx/(points.len()-1))
  assert(offset<=100 && offset >=0 && (["integer", "float"].contains(::type(offset))))
  local color = point?.color
  if (color==null && ::type(point)=="array")
    color = point
  local opacity = color?.len()==4
    ? color[3]/255.0
    : point?.opacity
  local colorStr = ""
  if (color!=null){
    local [r,g,b] = color
    colorStr = $"stop-color:rgb({r}, {g}, {b});"
  }
  local opacityStr = (opacity!=null) ? $"stop-opacity:{opacity};" : ""
  assert(colorStr != "" || opacityStr != "", "point in gradient should have color and/or opacity! got '{point}'")
  return $"<stop offset='{offset}%' style='{opacityStr}{colorStr}'/>"
}

enum GRADSPREAD {
  PAD = "pad"
  REFLECT = "reflect"
  REPEAT = "repeat"
}

local function mkLinearGradSvgTxtImpl(points, width, height, x1=0, y1=0, x2=null, y2=0, spreadMethod=GRADSPREAD.PAD, transform=null){
  x2 = x2 ?? width
  assert(::type(points)=="array", "points should be array of objects with color=[r,g,b,optional alpha] and optional offset. If offset is missing points are evenly distributed")
  assert(width>1 && height>1 && width+height > 15, "gradient should be created with some reasonable sizes")
  spreadMethod=spreadMethod ?? GRADSPREAD.PAD
  if (transform != null)
    transform = " ".join(transform.reduce(@(prev, v, k) prev.append($"{k}({v}))", [])))
  local gradientTransformStr = transform!=null ? $"gradientTransform='{transform}'" : ""
  local header = $"<svg xmlns='http://www.w3.org/2000/svg' version='1.1'><defs>\n  <linearGradient spreadMethod='{spreadMethod}' id='gradient' {gradientTransformStr} x1='{x1}' y1='{y1}' x2='{x2}' y2='{y2}'>"
  local footer = $"  </linearGradient>\n</defs>\n<rect width='{width}' height='{height}' y='0' x='0' fill='url(#gradient)'/></svg>"
  assert(points.len()>1, "gradient can't be build with one point only")
  local body = "\n    ".join(points.map(mkGradPointStyle))
  return $"{header}\n    {body}\n{footer}"
}

local mkLinearGradientImg = ::kwarg(function(points, width, height, x1=0, y1=0, x2=null, y2=0, spreadMethod=GRADSPREAD.PAD, transform=null, premultiplied=false) {
  local svg = mkLinearGradSvgTxtImpl(points, width, height, x1,y1,x2,y2, spreadMethod, transform)
  local text = encodeString(svg)
  return ::Picture($"{premultiplied ? "" : "!"}b64://{text}.svg:{width}:{height}?Ac")
})

local function mkRadialGradSvgTxtImpl(points, width, height, cx=null, cy=null, r=null, fx=null, fy=null, spreadMethod=GRADSPREAD.PAD, transform=null){
  assert(::type(points)=="array", "points should be array of objects with color=[r,g,b,optional alpha] and optional offset. If offset is missing points are evenly distributed")
  assert(width>1 && height>1 && width+height > 15, "gradient should be created with some reasonable sizes")
  spreadMethod=spreadMethod ?? GRADSPREAD.PAD
  if (transform != null)
    transform = " ".join(transform.reduce(@(prev, v, k) prev.append($"{k}({v}))", [])))
  local focus = " ".join([
    fx != null ? $"fx='{fx}'" : "",
    fy != null ? $"fy='{fy}'" : ""
  ])
  r = r==null ? min(width, height) * 0.5 : r
  local center = " ".join([
    cx!=null ? $"cx='{cx}'" : "",
    cy!=null ? $"cy='{cy}'" : "",
  ])
  local gradientTransformStr = transform!=null ? $"gradientTransform='{transform}'" : ""
  local header = $"<svg xmlns='http://www.w3.org/2000/svg' version='1.1'><defs>\n  <radialGradient spreadMethod='{spreadMethod}' id='gradient' {gradientTransformStr} {center} r='{r}' {focus}>"
  local footer = $"  </radialGradient>\n</defs>\n<rect width='{width}' height='{height}' y='0' x='0' fill='url(#gradient)'/></svg>"
  assert(points.len()>1, "gradient can't be build with one point only")
  local body = "\n    ".join(points.map(mkGradPointStyle))
  return $"{header}\n    {body}\n{footer}"
}

/*Example:
local red = [255,0,0]
local green = [0, 255, 0]
local blue = [0, 0, 255]
{
  rendObj = ROBJ_IMAGE
  image = mkRadialGradientImg({points=[red, {color = green, offset=66}, blue], width=256, height=256}))
  size = flex()
}
*/
local mkRadialGradientImg = ::kwarg(function(points, width, height, cx=null, cy=null, r=null, fx=null, fy=null, spreadMethod=GRADSPREAD.PAD, transform=null, premultiplied=false){
  local svg = mkRadialGradSvgTxtImpl(points, width, height, cx,cy,r,fx,fy, spreadMethod, transform)
  local text = encodeString(svg)
  return ::Picture($"{premultiplied ? "" : "!"}b64://{text}.svg:{width}:{height}?Ac")
})

return {
  GRADSPREAD
  mkLinearGradientImg
  mkLinearGradSvgTxt = ::kwarg(mkLinearGradSvgTxtImpl)
  mkRadialGradientImg
  mkRadialGradSvgTxt = ::kwarg(mkRadialGradSvgTxtImpl)
}