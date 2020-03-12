<<#isFull>>
MultiSelect {
  <<#id>>
    id:t='<<id>>'
  <</id>>
  height:t='ph -6@sf/@pf'
  <<#showTitle>>
    pos:t='0, 0.5(ph-h)'
    position:t='relative'
  <</showTitle>>
  <<^showTitle>>
    pos:t='pw-0.5p.p.w-0.5w, 0.5(ph-h)'
    position:t='absolute'
  <</showTitle>>
<</isFull>>

  <<#cb>>
    on_select:t='<<cb>>'
  <</cb>>
  class:t='<<listClass>>'
  value:t='<<#value>><<value>><</value>><<^value>>0<</value>>'
  optionsShortcuts:t='yes'

  <<#items>>
  multiOption {
    <<#id>>
      id:t='<<id>>'
    <</id>>
    <<^enabled>>
      enable:t='no'
    <</enabled>>
    <<^isVisible>>
      display:t='hide'
    <</isVisible>>
    <<#image>>
      multiOptionImg { background-image:t='<<image>>' }
    <</image>>
    <<#activateShortcutIconName>>
      ButtonImg { showOn:t='selectedOnConsole'; btnName:t='<<activateShortcutIconName>>' }
    <</activateShortcutIconName>>
    <<^activateShortcutIconName>>
      ButtonImg { showOn:t='selectedOnConsole'; btnName:t='X' }
    <</activateShortcutIconName>>
    <<#text>>
      multiOptionText { text:t='<<text>>' }
    <</text>>
    <<#tooltip>>
      tooltip:t = '<<tooltip>>'
    <</tooltip>>
    CheckBoxImg {}
  }
  <</items>>

<<#isFull>>
}

<<#textAfter>>
  textareaNoTab {
    id:t='text_after'
    pos:t='0, ph/2-h/2'
    position:t='relative'
    margin-left:t='@blockInterval + 0.33h'
    text:t='<<textAfter>>'
  }
<</textAfter>>
<</isFull>>
