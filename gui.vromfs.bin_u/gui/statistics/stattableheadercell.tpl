<<#cells>>
td {
  id:t='<<id>>';
  width:t='<<width>>';
  text-halign:t='center'
  total-input-transparent:t='yes'
  tooltip:t='<<tooltip>>';
  <<@customParams>>

  <<#fontIcon>>
  fontIcon32 {
    fonticon { text:t='<<fontIcon>>' }
  }
  <</fontIcon>>
  <<^fontIcon>>
  <<#tooltip>>
  activeText {
    position:t='relative'
    top:t='ph/2-h/2'
    width:t='pw'
    pare-text:t='yes'
    text:t='<<tooltip>>'
  }
  <</tooltip>>
  <</fontIcon>>
}
<</cells>>
