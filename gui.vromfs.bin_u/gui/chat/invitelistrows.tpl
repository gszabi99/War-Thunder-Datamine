<<#invites>>
expandable {
  id:t='invite_<<uid>>'
  inviteUid:t='<<uid>>'
  class:t='simple'
  highlightedRowLine {}
  selImg {
    style:t='flow:horizontal;'

    tdiv {
      size:t='fw, fh'

      tdiv {
        width:t='fw'
        flow:t='vertical'

        <<#hasInviter>>
        tdiv {
          ButtonImg {
            size:t='@cIco, @cIco'
            pos:t='0, 50%ph-50%h'
            position:t='relative'
            margin-right:t='0.01@scrn_tgt'
            showOnSelect:t='yes'
            btnName:t='Y'
          }

          textareaNoTab {
            id:t='inviterName_<<uid>>'
            inviteUid:t='<<uid>>'
            overlayTextColor:t='userlog'
            text:t='<<getInviterName>>'

            behaviour:t='button'
            on_r_click:t='onInviterInfo'
            on_click:t='onInviterInfo'
          }
        }
        <</hasInviter>>

        tdiv {
          width:t='pw'

          cardImg {
            background-image:t='<<getIcon>>'
          }

          textareaNoTab {
            id:t='text'
            width:t='fw'
            pos:t='0.01@scrn_tgt, 0'
            position:t='relative'
            overlayTextColor:t='active'
            text:t='<<getInviteText>>'
          }
        }

        textareaNoTab {
          id:t='restrictions'
          width:t='pw'
          padding-left:t='1@cIco + 0.01@scrn_tgt'
          overlayTextColor:t='warning'
          text:t='<<getRestrictionText>>'
          hideEmptyText:t='yes'
        }
      }

      tdiv {
        pos:t='0, ph - h'
        //pos:t='0, 50%ph-50%h'
        position:t='relative'
        padding:t='-1@buttonMargin'

        Button_text {
          id:t='accept'
          inviteUid:t='<<uid>>'
          class:t="double"
          tooltip:t = '#invite/accept'
          btnName:t='X'
          showOnSelect:t='yes'
          on_click:t = 'onAccept'

          <<#haveRestrictions>>
            inactiveColor:t='yes'
          <</haveRestrictions>>

          ButtonImg {}
          img { background-image:t='#ui/gameuiskin#favorite' }
        }

        Button_text {
          inviteUid:t='<<uid>>'
          class:t="double"
          showOnSelect:t='yes'
          tooltip:t = '#invite/reject'
          btnName:t='LB'
          on_click:t = 'onReject'
          ButtonImg {}
          img { background-image:t='#ui/gameuiskin#icon_primary_fail.svg' }
        }
      }
    }
  }
}
<</invites>>
