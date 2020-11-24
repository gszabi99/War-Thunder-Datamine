<<#chImages>>
img {
  size:t='pw, 0.125w'
  halign:t='center'
  background-image:t='<<chImages>>'
}
<</chImages>>

textarea {
  id:t = 'item_desc_text'
  width:t = '@onlineShopWidth'
  wrapRight:t='yes'
  font-bold:t='@fontMedium'
  padding-left:t='0.02@sf'
  margin:t='0, 1@blockInterval'
  <<#descText>>
  text:t='<<descText>>'
  <</descText>>
}

table {
  id:t='items_list'
  class:t='crewTable'
  pos:t='0.5(pw-w), 0'
  position:t='relative'
  behavior:t = 'HoverNavigator'
  selfFocusBorder:t='yes'
  margin-bottom:t='1@blockInterval'
  <<#rows>>
  tr {
    id:t='<<rowName>>'
    even:t='<<rowEven>>'
    <<#isDisabled>>
      enable:t='no'
    <</isDisabled>>

    include "gui/onlineShopRow"
  }
  <</rows>>
}