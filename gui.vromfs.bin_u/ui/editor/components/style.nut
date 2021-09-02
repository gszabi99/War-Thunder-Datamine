local margin = sh(0.3)
local height = ::calc_comp_size({size= SIZE_TO_CONTENT children = {rendObj = ROBJ_DTEXT text="A" margin=margin}})[1]

return {
  gridMargin = margin
  gridHeight = height
  colors = {
    HighlightSuccess = Color(100,255,100)
    HighlightFailure = Color(255,100,100)

    ControlBg = Color(10, 10, 10, 160)
    Interactive = Color(80, 120, 200, 80)
    Hover = Color(110, 110, 150, 50)
    Active = Color(100, 120, 200, 120)

    FrameActive = Color(250,200,50,200)
    FrameDefault =  Color(100,100,100,100)

    TextDefault = Color(255,255,255)
    TextError = Color(255, 20, 20)

    GridBg = [
      Color(15,15,15,140)
      Color(10,10,10,160)
    ]
    GridRowHover = Color(50,50,50,160)
  }
}