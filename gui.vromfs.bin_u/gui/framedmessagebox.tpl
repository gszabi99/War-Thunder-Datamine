massTransp {
  size:t='sw, sh'
  type:t='framedMessageBox'
  behaviour:t='button'
  on_click:t='goBack'

  framedMessageBox {
    id:t='framed_message_box'
    pos:t='0, 0'
    position:t='absolute'

    frame {
      activeText {
        smallFont:t='yes'
        position:t='relative'
        text:t='<<title>>'
        input-transparent:t='yes'
        max-width:t='1@framedMessageMaxWidth'
      }

      textareaNoTab {
        text:t='<<message>>'
        input-transparent:t='yes'
        pare-text:t= 'yes'
        max-width:t='1@framedMessageMaxWidth'
      }

      tdiv {
        id:t='framed_message_box_buttons_place'
        pos:t='pw-w, 0'
        position:t='relative'

        <<#buttons>>
          include "gui/commonParts/button"
        <</buttons>>
      }
    }
  }
}
