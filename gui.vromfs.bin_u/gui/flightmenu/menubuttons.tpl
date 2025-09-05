<<#buttons>>
menu_button
{
  id:t='<<buttonId>>'
  text:t='<<labelText>>'
  _on_click:t='<<onClickFuncName>>'
  <<#brBefore>>margin-top:t='@flightMenuBrHeight'<</brBefore>>
  <<#brAfter>>margin-bottom:t='@flightMenuBrHeight'<</brAfter>>
  on_hover:t='onMenuBtnHover'
  on_unhover:t='onMenuBtnHover'
  menu_button_bg {}
}
<</buttons>>
