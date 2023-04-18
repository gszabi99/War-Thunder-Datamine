<<^hasSimpleNavButtons>>
Button_text
<</hasSimpleNavButtons>>
<<#hasSimpleNavButtons>>
button
<</hasSimpleNavButtons>>
{
  id:t='pag_next_page';
  class:t='image';
  nav:t='right';
  on_click:t='goToPage';
  to_page:t='0'
  noMargin:t=yes;
  btnName:t='RB';
  showButtonImageOnConsole:t='no'
  ButtonImg{}
  img{
    background-image:t='#ui/gameuiskin#spinnerListBox_arrow_up.svg'; rotation:t='90'
  }
}
pages{
  id:t='paginator_page_holder';
}
<<^hasSimpleNavButtons>>
Button_text
<</hasSimpleNavButtons>>
<<#hasSimpleNavButtons>>
button
<</hasSimpleNavButtons>>
{
  id:t='pag_prew_page';
  class:t='image';
  nav:t='left';
  on_click:t='goToPage';
  to_page:t='0'
  noMargin:t=yes;
  btnName:t='LB';
  showButtonImageOnConsole:t='no'
  ButtonImg{}
  img{
    background-image:t='#ui/gameuiskin#spinnerListBox_arrow_up.svg'; rotation:t='270'
  }
}
unseenIcon {
  id:t='pag_prew_page_unseen'
  pos:t='-w - @blockInterval - 1@buttonHeight, 50%ph-50%h'
  position:t='absolute'
  unseenText{}
}
unseenIcon {
  id:t='pag_next_page_unseen'
  pos:t='pw + @blockInterval + 1@buttonHeight, 50%ph-50%h'
  position:t='absolute'
  unseenText{}
}