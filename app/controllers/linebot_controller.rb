# frozen_string_literal: true

class LinebotController < ApplicationController
  require 'line/bot' # gem 'line-bot-api'
  require 'open-uri'
  require 'kconv'
  require 'rexml/document'

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery except: [:callback]

  is_setting_mode = false

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      error 400 do 'Bad Request' end
    end
    events = client.parse_events_from(body)
    events.each do |event|
      case event
        # メッセージが送信された場合の対応（機能①）
      when Line::Bot::Event::Message
        case event.type
          # ユーザーからテキスト形式のメッセージが送られて来た場合
        when Line::Bot::Event::MessageType::Text
          # event.message['text']：ユーザーから送られたメッセージ
          input = event.message['text']
          url  = 'https://www.drk7.jp/weather/xml/13.xml'
          xml  = open(url).read.toutf8
          doc = REXML::Document.new(xml)
          xpath = 'weatherforecast/pref/area[4]/'

          # 当日朝のメッセージの送信の下限値は20％としているが、明日・明後日雨が降るかどうかの下限値は30％としている
          min_per = 30
          case input

          # 「設定」or「せってい」というワードが含まれる場合、設定フラグを立ててメッセージを返す
          when /.*(設定|せってい).*/
            is_setting_mode = true
            push = '降水確率を通知時間の設定をするよ！/n'

            # 「明日」or「あした」というワードが含まれる場合
          when /.*(明日|あした).*/
            # info[2]：明日の天気
            per06to12 = doc.elements[xpath + 'info[2]/rainfallchance/period[2]'].text
            per12to18 = doc.elements[xpath + 'info[2]/rainfallchance/period[3]'].text
            per18to24 = doc.elements[xpath + 'info[2]/rainfallchance/period[4]'].text
            # 降水確率のメッセージ
            rainy_percent = "    6〜12時　#{per06to12}％\n　12〜18時　#{per12to18}％\n　18〜24時　#{per18to24}％\n"

            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              push =
                "明日の天気だよね。\n明日は雨が降りそうだよ、、、\n今のところ降水確率はこんな感じだよ。\n#{rainy_percent}また明日の朝の最新の天気予報で雨が降りそうだったら教えるね！"
            else
              push =
                "明日の天気？\n明日は雨が降らない予定だよ！\nまた明日の朝の最新の天気予報で雨が降りそうだったら教えるね！"
            end

          when /.*(明後日|あさって).*/
            per06to12 = doc.elements[xpath + 'info[3]/rainfallchance/period[2]l'].text
            per12to18 = doc.elements[xpath + 'info[3]/rainfallchance/period[3]l'].text
            per18to24 = doc.elements[xpath + 'info[3]/rainfallchance/period[4]l'].text
            # 降水確率のメッセージ
            rainy_percent = "    6〜12時　#{per06to12}％\n　12〜18時　#{per12to18}％\n　18〜24時　#{per18to24}％\n"

            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              push =
                "明後日の天気だよね。\n明後日は雨が降りそう…\n当日の朝に雨が降りそうだったら教えるからね！"
            else
              push =
                "明後日の天気？\n明後日は雨は降らない予定だよ(^^)\nまた当日の朝の最新の天気予報で雨が降りそうだったら教えるからね！"
            end

          when /.*(かわいい|可愛い|カワイイ|きれい|綺麗|キレイ|素敵|ステキ|すてき|面白い|おもしろい|ありがと|すごい|スゴイ|スゴい|頑張|がんば|ガンバ).*/
            push =
              "ありがとう！！！\n"

          when /.*(こんにちは|こんばんは|初めまして|はじめまして|おはよう).*/
            push =
              "こんにちは。\n声をかけてくれてありがとう\n"

          when /.*(すき|好き).*/
            push =
              'ぼくも好きだよ！'
          else
            per06to12 = doc.elements[xpath + 'info/rainfallchance/period[2]l'].text
            per12to18 = doc.elements[xpath + 'info/rainfallchance/period[3]l'].text
            per18to24 = doc.elements[xpath + 'info/rainfallchance/period[4]l'].text
            # 降水確率のメッセージ
            rainy_percent = "    6〜12時　#{per06to12}％\n　12〜18時　#{per12to18}％\n　18〜24時　#{per18to24}％\n"

            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              word =
                ['雨だけど元気出していこうね！',
                 '雨ニモマケズ！！'].sample
              push =
                "今日の天気？\n今日は雨が降りそうだから傘があった方が安心だよ。\n#{rainy_percent}#{word}"
            else
              word =
                ['雨じゃなくてよかった！'].sample
              push =
                "今日の天気？\n今日は雨は降らなさそうだよ。降水確率はこんなかんじ〜。\n#{rainy_percent}#{word}"
            end
          end
          # テキスト以外（画像等）のメッセージが送られた場合
        else
          push = 'なんじゃい'
        end
        message = {
          type: 'text',
          text: push
        }
        client.reply_message(event['replyToken'], message)

        if is_setting_mode
          settingMessage = {
            "type": 'template',
            "altText": 'this is a buttons template',
            "template": {
              "type": 'buttons',
              "title": '空いてる日程教えてよ',
              "text": 'Please select',
              "actions": [
                {
                  "type": 'datetimepicker',
                  "label": 'いいよ',
                  "mode": 'date',
                  "data": 'action=datetemp&selectId=1'
                },
                {
                  "type": 'postback',
                  "label": 'やっぱりやめたい',
                  "data": 'action=cancel&selectId=2'
                }
              ]
            }
          }
          client.reply_message(event['replyToken'], settingMessage)
        end

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
    end
    head :ok
  end

  private

  def client
    @client ||= Line::Bot::Client.new do |config|
      config.channel_secret = ENV['LINE_CHANNEL_SECRET']
      config.channel_token = ENV['LINE_CHANNEL_TOKEN']
    end
  end
end
