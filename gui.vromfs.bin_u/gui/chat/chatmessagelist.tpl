<<#messages>>
  chatMessage {
    id:t='chat_message'
    messageType:t='<<messageType>>'
    textareaNoTab {
      id:t='chat_message_text'
      childIndex:t='<<childIndex>>'
      <<#customRoomId>>_customRoomId:t='<<customRoomId>>'<</customRoomId>>
      text:t='<<text>>'
    }
  }
<</messages>>