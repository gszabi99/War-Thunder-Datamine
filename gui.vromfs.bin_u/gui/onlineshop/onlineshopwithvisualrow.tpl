<<#chImages>>
img {
  id:t = 'item_image'
  size:t='pw, 0.125w'
  halign:t='center'
  background-image:t='<<chImages>>'
}
<</chImages>>

tdiv {
  id:t='item_desc_text_nest'
  overflow-y:t='auto'
  scrollbarShortcuts:t='yes'
  max-height:t='0.45@maxWindowHeight'
  margin-top:t='1@blockInterval'

  textarea {
    id:t = 'item_desc_text'
    width:t = '@onlineShopWidth'
    wrapRight:t='yes'
    font-bold:t='@fontMedium'
    padding-left:t='0.02@sf'
    <<#descText>>
    text:t='<<descText>>'
    <</descText>>
  }
}

table {
  id:t='items_list'
  class:t='crewTable'
  pos:t='0.5(pw-w), 0'
  position:t='relative'
  behavior:t = 'HoverNavigator'
  selfFocusBorder:t='yes'
  padding:t='0, 1@blockInterval'
  <<#rows>>
  tr {
    id:t='<<rowName>>'
    even:t='<<rowEven>>'
    <<#isDisabled>>
      enable:t='no'
    <</isDisabled>>

    include "%gui/onlineShopRow.tpl"
  }
  <</rows>>
}