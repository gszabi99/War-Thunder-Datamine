<<#items>>
<<#image>>
img {
  id:t='<<id>>'
  size:t='@checkboxSize, @checkboxSize'
  margin:t='1@blockInterval, 0'
  background-image:t='<<image>>'
  background-svg-size:t='@checkboxSize, @checkboxSize'
  tooltip:t='<<tooltip>>'
  <<^value>>
  display:t='hide'
  enable:t='no'
  <</value>>
}
<</image>>
<<^image>>
textareaNoTab {
  id:t='<<id>>'
  height:t='@checkboxSize'
  text:t='  <<text>>  |'
  <<^value>>
  display:t='hide'
  enable:t='no'
  <</value>>
}
<</image>>
<</items>>
