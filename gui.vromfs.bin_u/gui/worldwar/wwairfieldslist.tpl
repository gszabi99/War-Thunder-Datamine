<<#airfields>>
imageButton {
  id:t='<<id>>'
  type:t='<<type>>'
  <<#selected>>
    selected:t='yes'
  <</selected>>
  focusBtnName:t='A'
  showConsoleImage:t='no'
  on_click:t='onAirfieldClick'
  on_hover:t='onHoverAirfieldItem'
  on_unhover:t='onHoverLostAirfieldItem'
  size:t='50@sf/@pf, 50@sf/@pf'
  background-svg-size:t='50@sf/@pf, 50@sf/@pf'
  margin:t='0.01@scrn_tgt'

  textareaNoTab {
    pos:t='75%pw, ph-h+0.004@scrn_tgt'
    position:t='absolute'
    text:t='<<text>>'
    input-transparent:t='yes'
  }
}
<</airfields>>
