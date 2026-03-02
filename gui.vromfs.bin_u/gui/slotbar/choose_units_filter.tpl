<<#rows>>
options_list {
  flow:t='vertical';
  padding-bottom:t='10*@sf/@pf';
  text {
    text:t='<<option_title>>';
  }
  options_nest {
    padding-right:t='26*@sf/@pf';
    MultiSelect {
      id:t='<<option_id>>';
      uid:t='<<option_uid>>';
      idx:t='<<option_idx>>';
      value:t='<<option_value>>';
      on_select:t='<<#cb>><<cb>><</cb>><<^cb>>onSelectedOptionChooseUnit<</cb>>'
      flow:t='horizontal';
      smallFont:t='yes';
      optionsShortcuts:t='yes';
      <<#nums>>
      multiOption {
        filter_multi_option:t='yes';
        <<#option_icon>>
        infoImg{
          size:t='@cIco, @cIco'
          background-svg-size:t='@cIco, @cIco'
          background-image:t='<<option_icon>>'
          bgcolor:t='#FFFFFF'
          <<#isTextHidden>>
          tooltip:t='<<option_name>>'
          <</isTextHidden>>
        }
        <</option_icon>>
        <<^isTextHidden>>
        textareaNoTab {
          max-width:t='0.5@rw -0.5@slot_width'
          pos:t='1@blockInterval, ph/2-h/2'; position:t='relative'
          text:t='<<option_name>>';
          text-align:t='right';
          input-transparent:t='yes';
        }
        <</isTextHidden>>
        <<^isEnabled>>
        enable:t='no';
        <</isEnabled>>
        <<^visible>>
        display:t='hide';
        inactive:t='yes';
        <</visible>>
        CheckBoxImg{}
      }
      <</nums>>
    }
  }
}
<</rows>>