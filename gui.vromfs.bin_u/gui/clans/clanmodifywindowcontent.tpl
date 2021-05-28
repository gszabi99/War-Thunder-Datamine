frame{
  width:t='0.9@scrn_tgt';
  pos:t='50%pw-50%w, 1@minYposWindow + 0.02@scrn_tgt'
  position:t='absolute';
  flow:t='vertical';
  class:t='wndNav';

  frame_header {
    activeText {
      caption:t='yes'
      text:t='<<windowHeader>>'
    }

    Button_close { id:t='btn_back' }
  }

  tdiv{
    padding-left:t='10';
    padding-right:t='10';
    size:t='pw, fh'
    flow:t='vertical';

    <<#hasClanTypeSelect>>
    tdiv {
      id:t='clan_type_select'
      width:t='pw'
      flow:t='vertical'

      activeText{
        text:t='#clan/clan_type'
      }

      HorizontalListBox {
        id:t='newclan_type'
        size:t='pw, 0.04@sf'
        on_select:t = 'onClanTypeSelect'
        on_set_focus:t='onFocus'
        on_hover:t='onHover'
        on_unhover:t='onHover'
        margin-bottom:t='0.01@sf'
        shortcutsNavigator:t='yes'
        navigatorShortcuts:t='yes'

        <<#clanTypeItems>>
        shopFilter {
          width:t='pw/<<numItems>>'
          tooltip:t='<<itemTooltip>>'
          clanTypeName:t='<<typeName>>'

          shopFilterText {
            text:t='<<itemText>>'
          }

          textarea {
            id:t='<<typeTextId>>'
            text:t='<<typePrice>>'
            pos:t='0, 0.5ph - 0.5h'
            position:t='relative'
            input-transparent:t='yes'
          }
        }
        <</clanTypeItems>>
      }

      fieldReq {
        id:t='req_newclan_type'
        display:t='hide';
        textarea {
          smallFont:t='yes'
          width:t='pw'
          text:t='#clan/newclan_type_req'
        }
      }
    }
    <</hasClanTypeSelect>>

    <<#hasClanNameSelect>>
    tdiv{
      width:t='50%pw';
      flow:t='vertical';
      activeText{
        text:t='#clan/clan_name';
      }

      EditBox{
        id:t = 'newclan_name';
        width:t = 'pw';
        position:t='relative';
        max-len:t='32';
        <<^isNonLatinCharsAllowedInClanName>>
        char-mask:t='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890 _-';
        <</isNonLatinCharsAllowedInClanName>>
        text:t='';
        noActivate:t='yes'
        on_set_focus:t='onFocus';
        on_hover:t='onHover'
        on_unhover:t='onHover'
        on_change_value:t='onFieldChange';
        on_cancel_edit:t='clanCanselEdit';
      }

      fieldReq{
        id:t='req_newclan_name';
        textarea{
          smallFont:t='yes';
          width:t='pw';
          text:t='#clan/newclan_name_req';
        }
      }
    }
    <</hasClanNameSelect>>

    tdiv {
      width:t='pw';
      tdiv{
        width:t='pw/2';
        flow:t='vertical';
        activeText{
          text:t='#clan/clan_tag';
        }

        EditBox{
          id:t = 'newclan_tag';
          width:t = 'pw';
          max-len:t='5';
          <<^isNonLatinCharsAllowedInClanName>>
          char-mask:t='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890';
          <</isNonLatinCharsAllowedInClanName>>
          text:t='';
          noActivate:t='yes'
          on_set_focus:t='onFocus';
          on_hover:t='onHover'
          on_unhover:t='onHover'
          on_change_value:t='updateDecoration';
          on_cancel_edit:t='clanCanselEdit';
        }
      }

      tdiv{
        width:t='pw/2 - 0.01*@scrn_tgt';
        margin-left='0.02*@scrn_tgt';
        flow:t='vertical';
        activeText{
          text:t='#clan/clan_tag_decoration';
        }

        ComboBox{
          id:t = 'newclan_tag_decoration';
          size:t='pw, @buttonHeight';
          on_hover:t='onHover'
          on_unhover:t='onHover'
          on_select:t='onFieldChange'
        }
      }

      fieldReq{
        id:t='req_newclan_tag';
        display:t='hide';
        textarea{
          id:t='req_newclan_tag_text'
          smallFont:t='yes';
          width:t='pw';
          text:t='';
        }
      }
    }

    <<#hasClanSloganSelect>>
    tdiv{
      width:t='pw';
      flow:t='vertical';
      activeText{
        text:t='#clan/clan_slogan';
      }

      EditBox{
        id:t = 'newclan_slogan';
        width:t='pw';
        max-len:t='100';
        text:t='';
        noActivate:t='yes'
        on_set_focus:t='onFocus';
        on_hover:t='onHover'
        on_unhover:t='onHover'
        on_change_value:t='onFieldChange';
        on_cancel_edit:t='clanCanselEdit';
      }

      fieldReq{
        id:t='req_newclan_slogan';
        display:t='hide';
        textarea{
          smallFont:t='yes';
          width:t='pw';
          text:t='#clan/newclan_slogan_req';
        }
      }
    }
    <</hasClanSloganSelect>>

    <<#hasClanRegionSelect>>
    div{
      id:t='region_nest'
      width:t='pw';
      flow:t='vertical';
      tdiv {
        activeText{
          text:t='#clan/clan_region';
        }

        activeText {
          id:t='region_change_cooldown'
          text:t=''
          margin-left:t='0.005@scrn_tgt'
        }
      }

      EditBox
      {
        id:t='newclan_region';
        width:t='pw';
        max-len:t='64';
        text:t='';
        noActivate:t='yes'
        on_set_focus:t='onFocus';
        on_hover:t='onHover'
        on_unhover:t='onHover'
        on_change_value:t='onFieldChange';
        on_cancel_edit:t='clanCanselEdit';
      }

      fieldReq {
        id:t='req_newclan_region';
        display:t='hide';
        textarea{
          smallFont:t='yes';
          width:t='pw';
          text:t='#clan/newclan_region_req';
        }
      }
    }
    <</hasClanRegionSelect>>

    div{
      width:t='pw';
      flow:t='vertical';
      tdiv {
        activeText{
          text:t='#clan/clan_description';
        }
      }

      EditBox
      {
        id:t='newclan_description';
        size:t='pw, 12*@sf/100';
        multiline='yes';
        max-len:t='512';
        text:t='';
        on_set_focus:t='onFocus';
        on_hover:t='onHover'
        on_unhover:t='onHover'
        on_change_value:t='onFieldChange';
        on_cancel_edit:t='clanCanselEdit';
      }

      textarea {
        display:t='hide'
        id:t='not_allowed_description_caption'
        text:t='#clan/description_not_allowed'
      }

      fieldReq{
        id:t='req_newclan_description';
        display:t='hide';
        textarea{
          smallFont:t='yes';
          width:t='pw';
          text:t='#clan/newclan_description_req';
        }
      }
    }

    div {
      id:t='announcement_nest'
      width:t='pw';
      flow:t='vertical';
      tdiv {
        activeText{
          text:t='#clan/clan_announcement';
        }
      }

      EditBox
      {
        id:t='newclan_announcement';
        size:t='pw, 12*@sf/100';
        multiline='yes';
        max-len:t='512';
        text:t='';
        on_set_focus:t='onFocus';
        on_hover:t='onHover'
        on_unhover:t='onHover'
        on_change_value:t='onFieldChange';
        on_cancel_edit:t='clanCanselEdit';
      }

      textarea {
        display:t='hide'
        id:t='not_allowed_announcement_caption'
        text:t='#clan/announcement_not_allowed'
      }

      fieldReq{
        id:t='req_newclan_announcement';
        display:t='hide';
        textarea{
          smallFont:t='yes';
          width:t='pw';
          text:t='#clan/newclan_announcement_req';
        }
      }
    }
  }

  navBar {
    navRight{
      Button_text {
        id:t='btn_upg_members'
        hideText:t='yes'
        tooltip:t='';
        display:t='hide';
        visualStyle:t='purchase'
        btnName:t='Y'
        on_click:t='onUpgradeMembers';
        buttonWink{}
        ButtonImg{}
        textarea{
          id:t='btn_upg_members_text'
          text:t='#clan/members_upgrade_button';
          class:t='buttonText'
        }
      }
      Button_text{
        id:t='btn_submit';
        hideText:t='yes'
        btnName:t='X';
        visualStyle:t='purchase'
        _on_click:t='onSubmit';
        buttonWink{}
        buttonGlance{}
        ButtonImg{}
        textarea{
          id:t='btn_submit_text';
          class:t='buttonText';
        }
      }
    }

    navLeft {
      Button_text {
        id:t='btn_disbandClan'
        display:t='hide'
        btnName:t='L3'
        text:t = '#clan/btnDisbandClan'
        tooltip:t = '#clan/btnDisbandClan'
        on_click:t = 'onDisbandClan'
        ButtonImg{}
      }
    }
  }
}
