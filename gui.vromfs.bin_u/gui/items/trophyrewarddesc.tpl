textareaNoTab {
  width:t='pw'
  overlayTextColor:t='active'
  text-align:t='center'
  pos:t='50%pw-50%w, 0';
  position:t='relative'
  margin-bottom:t='1@blockInterval'
  text:t='<<textTitle>>'
}

img {
  pos:t='50%pw-50%w, 0';
  halign:t='center'
  doubleSize:t='yes'
  wideSize:t='no'
  overflow:t='hidden'
  margin-bottom:t='1@blockInterval'
  <<@prizeImg>>
}

<<#textDesc>>
textareaNoTab {
  text-align:t='left'
  width:t='pw'
  font-bold:t='@fontNormal'
  text:t='<<textDesc>>'
  hideEmptyText:t='yes'
}
<</textDesc>>

<<#markupDesc>>
tdiv {
  pos:t='50%pw-50%w, 0';
  halign:t='center'
  doubleSize:t='yes'
  wideSize:t='no'
  overflow:t='hidden'
  margin-bottom:t='1@blockInterval'
  <<@markupDesc>>
}
<</markupDesc>>