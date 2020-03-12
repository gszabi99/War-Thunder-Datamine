<<#mapStateBox>>
mapStateBox {
  id:t='<<id>>'
  pos:t='0, 0'
  position:t='relative'
  value:t='<<#value>>yes<</value>><<^value>>no<</value>>'
  tooltip:t='<<tooltip>>'
  <<#funcName>>
    on_change_value:t='<<funcName>>'
  <</funcName>>

  <<@specialParams>>
  mapStateBoxText {text:t = '<<text>>'}
  mapStateBoxImg {}
}
<</mapStateBox>>
