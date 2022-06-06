root{
  blur {}
  blur_foreground {}

  frame{
    pos:t='50%pw-50%w, 50%ph-50%h';
    position:t='absolute';
    width:t='80%sh';
    max-width:t='800*@sf/@pf_outdated + 2@framePadding';
    max-height:t='@rh'
    class:t='wndNav';

    frame_header{
      Button_close {}
    }
    img{
      id:t='award_image';
      width:t='pw';
      height:t='0.5w';
      max-width:t='800*@sf/@pf_outdated';
      max-height:t='400*@sf/@pf_outdated';
      pos:t='50%pw-50%w, 0';
      position:t='relative';
      background-image:t='#ui/images/new_rank_usa.jpg?P1';
    }
    tdiv{
      width:t='pw';
      max-height:t='fh';
      pos:t='0, 1@framePadding';
      position:t='relative'
      flow:t='vertical';
      overflow-y:t='auto';

      tdiv {
        re-type:t='9rect';
        background-image:t='#ui/gameuiskin#block_bg_rounded_flat_black';
        background-position:t='4';
        background-repeat:t='expand';
        background-color:t='@white';
        width:t='pw';
        flow:t='vertical';
        padding:t='0.01@sf';

        textarea{
          position:t='relative';
          pos:t='50%pw-50%w, 0';
          max-width:t='pw';
          removeParagraphIndent:t='yes';
          text:t='<<rewardDescription>>';
        }

        activeText {
          position:t='relative';
          pos:t='50%pw-50%w, 0';
          padding-left:t='0.03@sf';
          margin-bottm:t='0.01@sf';
          text:t='<<conditionText>>';

          img {
            width:t='0.025@sf';
            height:t='w';
            pos:t="0, 50%ph-50%h";
            position:t="absolute";
            background-image:t="<<conditionIcon>>";
          }

          img {
            size:t="1.5ph, 1.5ph";
            pos:t="pw, -0.3h";
            position:t="absolute";
            background-image:t="#ui/gameuiskin#favorite";
          }
        }

        tdiv {
          id:t='rewardBox';
          position:t='relative';
          pos:t='50%pw-50%w, 0';

          tdiv {
            size:t='@eventRewardIconHeight, @eventRewardIconHeight';
            <<@rewardIcon>>
          }
          textarea{
            position:t='relative';
            pos:t='0, ph/2 - h/2';
            overlayTextColor:t='userlog';
            removeParagraphIndent:t='yes';
            text:t='<<rewardText>>';
          }
        }
      }

      <<#nextReward>>
      frameBlock_dark {
        width:t='pw';
        flow:t='vertical';
        padding:t='0.01@sf';

        textarea {
          position:t='relative';
          pos:t='50%pw-50%w, 0';
          text:t='#tournaments/reward/nextReward';
        }
        textarea {
          position:t='relative';
          pos:t='50%pw-50%w, 0';
          padding-left:t='0.03@sf';
          margin-bottm:t='0.01@sf';
          text:t='<<conditionText>>';

          img {
            width:t='0.025@sf';
            height:t='w';
            pos:t="0, 50%ph-50%h";
            position:t="absolute";
            background-image:t="<<conditionIcon>>";
          }
        }

        tdiv {
          id:t='rewardBox';
          position:t='relative';
          pos:t='50%pw-50%w, 0';

          tdiv {
            size:t='@eventRewardIconHeight, @eventRewardIconHeight';
            <<@rewardIcon>>
          }
          textarea{
            position:t='relative';
            pos:t='0, ph/2 - h/2';
            overlayTextColor:t='userlog';
            removeParagraphIndent:t='yes';
            text:t='<<rewardText>>';
          }
        }
        textarea {
          id:t='next_reward';
          max-width:t='pw';
          pos:t='50%pw-50%w, 0.03@sf';
          position:t='relative';
          textHide:t='yes';
          text:t='<<nextRewardText>>';
        }
      }
      <</nextReward>>
    }

    navBar{
      navLeft{
        Button_text {
          id:t='btn_upload_facebook_scrn';
          display:t='hide';
          pressAction:t='share';
          on_click:t='onFacebookLoginAndPostScrnshot';
          tooltip:t='';
          cardImg{
            background-image:t='#ui/gameuiskin#facebook_logo.svg'
            input-transparent:t='yes';
          }
          text{
            id:t='text_facebook_action';
            pos:t='0,50%ph-50%h';
            position:t='relative';
            text:t='#mainmenu/btnUploadFacebookScreenshot';
            input-transparent:t='yes';
          }
        }
      }
      navRight {
        Button_text {
          id:t = 'btn_close';
          text:t = '#mainmenu/btnOk';
          btnName:t='A';
          _on_click:t = 'onOk';
          ButtonImg {}
        }
      }
    }
  }
}
