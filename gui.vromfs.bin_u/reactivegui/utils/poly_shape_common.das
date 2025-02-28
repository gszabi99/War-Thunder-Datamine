require %rGui.utils.canvas_common

module poly_shape_common public

enum ShapeType
  PolyLine
  Poly
  PolyFilled
  PolyFilledOutlined


struct Poly
  scale : float2
  pos : float2
  points : array<float2>
  pointsAbs : array<float2>
  shapeType : ShapeType


def Poly(points : array<float2>& const;
         shapeType : ShapeType = ShapeType PolyLine;
         pos : float2 = float2(0.0);
         scale : float2 = float2(1.0)
         )
  var self =  Poly()
  self.scale = scale
  self.pos = pos
  self.points := points
  self.pointsAbs.resize(points.length())
  self.shapeType = shapeType
  self |> poly_recalc()
  return <- self


def private poly_recalc(var self : Poly&; pos : float2 = float2(0.0); scale : float2 = float2(1.0))
  if (pos == self.pos && scale == self.scale)
    return
  for p, pAbs in self.points, self.pointsAbs
    pAbs = p * scale + pos;
  self.scale = scale;
  self.pos = pos;


def private poly_render(self : Poly&; var canvas : Canvas&)
  if self.shapeType == ShapeType PolyLine
    canvas.drawPolyLine(self.pointsAbs)
    return
  if self.shapeType == ShapeType Poly
    canvas.drawClosedPolyLine(self.pointsAbs)
    return
  if self.shapeType == ShapeType PolyFilled
    canvas.drawFilledPoly(self.pointsAbs)
    return
  if self.shapeType == ShapeType PolyFilledOutlined
    canvas.drawFilledPoly(self.pointsAbs)
    canvas.drawClosedPolyLine(self.pointsAbs)
    return


def poly_draw(var self : Poly&; var canvas : Canvas&; pos : float2 = float2(0.0); scale : float2 = float2(1.0))
  self |> poly_recalc(pos, scale)
  self |> poly_render(canvas)


def poly_draw_flipped(var self : Poly&; var canvas : Canvas&; x : bool = false; y : bool = false; pos : float2 = float2(0.0); scale : float2 = float2(1.0))
  self |> poly_recalc(float2(0.0), scale) // recalc base pos
  for pAbs in self.pointsAbs
    pAbs *= float2(x ? -1 : 1, y ? -1 : 1)
    pAbs += pos
  self |> poly_render(canvas)


def poly_draw_symmetrical(var self : Poly&; var canvas : Canvas&; x : bool = false; y : bool = false; pos : float2 = float2(0.0); scale : float2 = float2(1.0))
  self |> poly_draw(canvas, pos, scale)
  self |> poly_draw_flipped(canvas, x, y, pos, scale)


// def poly_set_shape_type(var self : Poly&; shapeType : ShapeType)
//   self.shapeType = shapeType
