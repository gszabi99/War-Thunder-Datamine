<<#updateTime>>
activeText {
  id:t='lb_update_time'
  pos:t='0, 50%ph-50%h'; position:t='relative'
  margin-right:t='1@blockInterval'
  caption:t='no'
  text:t=''
  textHide:t='no'
}
<</updateTime>>
tdiv {
  id:t='top_checkboxes'
  pos:t='0, 50%ph-50%h'; position:t='relative'
  <<#filter>>
  CheckBox {
    id:t='<<id>>'
    text:t='<<text>>'
    on_change_value:t='<<cb>>'
    value:t='<<filterCbValue>>'
    margin:t='0.5@framePadding, 0'
    CheckBoxImg{}
  }
  <</filter>>
}