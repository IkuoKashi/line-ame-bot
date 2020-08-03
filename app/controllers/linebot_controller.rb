class LinebotController < ApplicationController
    require 'line/bot' #gem 'Line-bot-api'
    require 'open-uri'
    require 'kconv'
    require 'rexml/document'
    
    #callbackアクションのCSRFトークン認証を無効
    protect_from_forgery :except => [:callback]
    
    def callback
       body = request.body.read
       signature = request.env['HTTP_X_LINE_SIGNATURE']
       unless client.validate_signature(body, signature)
          return head :bad_request 
       end
       events = client.parse_events_from(body)
       events.each { |event|
           case event
           #メッセージが送信された場合の対応（機能１）
           when Line::Bot::Event::MessageType::Text
               case event.type
               #ユーザーからテキスト形式のメッセージが送られてきた場合
               when Line::Bot::Event::MessageType::Text
                   #event.message['text']: ユーザーから送られてきたメッセージ
                   input = event.message['text']
                   url = "https://www.drk7.jp/weather/xml/13.xml"
                   xml = open(url).read.touf8
                   doc = REXML::Document.new(xml)
                   xpath = 'weatherforecast/pref/area[4]'
                   # 当日朝のメッセージの送信の下限値は20％としているが、明日・明後日雨が降るかどうかの下限値は30％としている
                   min_per = 30
                   case input
                    # 明日」or「あした」というワードが含まれる場合
                   when /.*(明日|あした).*/
                      # info[2]：明日の天気
                      per06to12 = doc.elements[xpath + 'info[2]/rainfallchance/period[2]'].text
                      per12to18 = doc.elements[xpath + 'info[2]/rainfallchance/period[3]'].text
                      per18to24 = doc.elements[xpath + 'info[2]/rainfallchance/period[4]'].text
                      if per06to12.to_i >= min_per || per12to18 >= minper || per18to24 >= minper
                         push = 
                         "明日の天気やな。\n明日は雨が降りそうやわ(>_<)\n今のところ降水確率はこんな感じやで。\n
                         6~12時　#{per06to12}% \n
                         12~18時　#{per12to18}% \n
                         18~24時　#{per18to24}% \n
                         また明日の朝の最新の天気予報で雨が降ったら教えるわ！
                         "
                      else
                         push =
                          "明日は雨降らなさそう！\n
                          また当日の朝に雨が降りそうなら教えるわ！"
                      end
                    when /.*(明後日| あさって).*/
                      per06to12 = doc.elements[xpath + 'info[3]/rainfallchance/period[2]'].text
                      per12to18 = doc.elements[xpath + 'info[3]/rainfallchance/period[3]'].text
                      per18to24 = doc.elements[xpath + 'info[3]/rainfallchance/period[4]'].text
                      if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
                       push =
                       "明後日は雨が降りそう！当日の朝に細心の天気予報で雨が降りそうやったら教えるわ！"
                      else
                       push =
                       "明後日は雨降らなさそう！また降りそうやったら、その日の朝に教えるわ"
                      end
                    when /.*(かわいい|可愛い|カワイイ|きれい|綺麗|キレイ|素敵|ステキ|すてき|面白い|おもしろい|ありがと|すごい|スゴイ|スゴい|好き|頑張|がんば|ガンバ).*/
                     push =
                     "ありがとうな！元気出るわ！"
                    when /.*(こんにちは|こんばんは|初めまして|はじめまして|おはよう).*/
                     push =
                     "こんにちは！今日が君にとって、最高の日でありますように。"
                    else
                     per06to12 = doc.elements[xpath + 'info/rainfallchance/period[2]'].text
                     per12to18 = doc.elements[xpath + 'info/rainfallchance/period[3]'].text
                     per18to24 = doc.elements[xpath + 'info/rainfallchance/period[4]'].text
                     if per06to12.to_i >= min_per || per12to18 >= min_per || per18to24 >= min_per
                      word = 
                      ["雨やけど元気出して！",
                      "雨やなあ！お前の大好きな雨！",
                      "もうほんま、雨雨ぱれーらい"
                       ]
                       push =
                       "今日の天気は、雨っぽいわ！傘持って行った方がいいなあ。\n
                       6~12時 #{per06to12}% \n
                       12~18時 #{per12to18}% \n
                       18~24時 #{per18to24}% \n
                       #{word}"
                     else
                       word = 
                       ["天気ええ感じ！",
                       "雨降ったらすまん！"
                        ]
                        push = 
                        "今日は雨降らなさそうやわ！\n #{word}"
                     end
                    end
                  #テキスト以外（画像）等のメッセージが送られてきた場合
                 else 
                   push = "テキスト以外はきつい！"
                 end
             　　 message = {
          type: 'text',
          text: push
        }
        client.reply_message(event['replyToken'], message)
        # LINEお友達追された場合（機能②）
      when Line::Bot::Event::Follow
        # 登録したユーザーのidをユーザーテーブルに格納
        line_id = event['source']['userId']
        User.create(line_id: line_id)
        # LINEお友達解除された場合（機能③）
      when Line::Bot::Event::Unfollow
        # お友達解除したユーザーのデータをユーザーテーブルから削除
        line_id = event['source']['userId']
        User.find_by(line_id: line_id).destroy
      end
    }
       head :ok
    end
    
    private
    
    def client
      @client ||= Line::Bot::Client.new { |config|
       config.channel_sercret = ENV["LINE_CHANNEL_SECRET"]
       config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
      }
    end
end
