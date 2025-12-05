<<#items>>
infantrySkinItem {
  id:t='<<id>>'
  position:t='relative'
  min-width:t='pw'
  margin-bottom:t='8@sf/@pf'
  margin-left:t='1@infantryBlockMargin'
  padding:t='7@sf/@pf, 0, 5@sf/@pf, 0'
  background-color:t='@modBgColor'
  overflow-x:t='hidden'
  skinId:t='<<skinId>>'

  topLine{}

  textareaNoTab {
    position:t='relative'
    width:t='fw'
    top:t='(ph-h)/2'
    max-height:t='ph'
    text:t='<<label>>'
    tinyFont:t='yes'
  }

  RadioButton {
    id:t='radio_button'
    behaviour:t='button'
    position:t='relative'
    class:t='skinList'
    top:t='(ph-h)/2'
    isChecked:t='<<isChecked>>'
    on_click:t='onSkinRadioBtnClick'
    RadioButtonImg {}
  }

  <<#unseenValue>>
  infantryUnseenIcon {
    id:t='unseen_skin'
    iconType:t='skin'
    pos:t='-0.3w, -0.2h'
    value:t='<<unseenValue>>'
  }
  <</unseenValue>>
}
<</items>>