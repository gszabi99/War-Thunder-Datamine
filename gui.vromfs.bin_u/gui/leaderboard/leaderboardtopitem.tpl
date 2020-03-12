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
<<#monthCheckbox>>
CheckBox {
  id:t='btn_type'
  behaviour:t='wrapBroadcast'
  pos:t='0, 50%ph-50%h'; position:t='relative'
  text:t='#mainmenu/btnMonthLb'
  on_change_value:t='onChangeType'
  value:t='<<monthCbValue>>'
  navigatorShortcuts:t='yes'
  on_wrap_up:t='onWrapUp'
  on_wrap_down:t='onWrapDown'
  CheckBoxImg{}
}
<</monthCheckbox>>