<<#airfields>>
imageButton {
  id:t='<<id>>'
  type:t='wwAirfield'
  <<#selected>>
    selected:t='yes'
  <</selected>>
  on_click:t='onAirfieldClick'
  size:t='40, 40'
  margin:t='0.01@scrn_tgt'

  textareaNoTab {
    pos:t='75%pw, ph-h+0.004@scrn_tgt'
    position:t='absolute'
    text:t='<<text>>'
    input-transparent:t='yes'
  }
}
<</airfields>>
