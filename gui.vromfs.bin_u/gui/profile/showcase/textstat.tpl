tdiv {
  position:t='relative'
  background-color:t='@showcaseWhiteTransparent'
  size:t='<<scale>>*pw - <<scale>>*30@sf/@pf, <<scale>>*44@sf/@pf'
  left:t='(pw-w)/2'

  <<^isFirst>>
    margin-top:t='<<scale>>*11@sf/@pf'
  <</isFirst>>
  <<#isFirst>>
    margin-top:t='<<scale>>*46@sf/@pf'
  <</isFirst>>

  tdiv {
    re-type:t='textarea'
    behaviour:t='textArea'
    position:t='absolute'
    font:t="tiny_text_hud"
    text:t='<<text>>'
    color:t='@showcaseGreyText'
    left:t='<<scale>>*20@sf/@pf'
    font-pixht:t='<<scale>>*24@sf/@pf \ 1'
    top:t='(ph-h)/2'
  }
  <<#value>>
  tdiv {
    position:t='absolute'
    re-type:t='textarea'
    behaviour:t='textArea'
    font:t="tiny_text_hud"
    font-pixht:t='<<scale>>*24@sf/@pf \ 1'
    text:t='<<value>>'
    color:t='#FFFFFF'
    left:t='pw - w - <<scale>>*18@sf/@pf'
    top:t='(ph-h)/2'
  }
  <</value>>
  tooltip:t='<<tooltip>>'
}