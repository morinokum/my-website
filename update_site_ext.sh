#!/bin/bash

# ==============================================================================
# AI-EXTENDABLE WRAPPER SCRIPT
# ==============================================================================
# 【AIへのコンテキスト・指示 (Context for AI Assistant)】
# このスクリプトは、コアシステムである `update_site.sh` を直接編集せずに
# 機能を安全に拡張（ラップ）するための実行ファイルです。
# 
# AIであるあなたに機能追加を依頼された場合、以下のルールに従ってください：
# 1. 決して `source ./update_site.sh` の行を削除・変更しないでください。
# 2. 新しい機能を追加する場合は、ファイルの末尾にある【拡張コード追加エリア】に
#    下へ下へと追記する形で実装してください。
# 3. 以下の変数は `source` によって親スクリプトから引き継がれており、そのまま利用可能です：
#    - $PROMPT        : 生成されたAIへの発注プロンプト（文字列）
#    - $game_count    : 処理・収集されたゲームの合計数（数値）
#    - $DOWNLOAD_DIR  : 探索対象のダウンロードフォルダのパス
#    - $mode          : ユーザーが選択した実行モード (1=新作, 2/3=引継ぎ, 4=共通データ)
# ==============================================================================

echo "🚀 [Wrapper] 拡張版アップデーターを起動します..."

# ------------------------------------------------------------------------------
# 【フェーズ1】事前処理エリア（元のスクリプトが走る前に行う処理）
# ------------------------------------------------------------------------------
# 例: 念のため現在の index.html のバックアップを取っておく
if [ -f "index.html" ]; then
  cp index.html index_backup.html
  echo "📦 [Wrapper] index.html のバックアップを作成しました。"
fi


# ------------------------------------------------------------------------------
# 【フェーズ2】コアシステムの実行
# ------------------------------------------------------------------------------
echo "⚙  [Wrapper] コアスクリプト (update_site.sh) を呼び出します..."

# ここで元のプログラムを読み込み・実行します。
# ※ sourceコマンドを使うことで、元のプログラム内で作られた変数が全てこのスクリプトに引き継がれます。
source ./update_site.sh

echo -e "\n⚙  [Wrapper] コアスクリプトの実行が完了しました。"


# ------------------------------------------------------------------------------
# 【フェーズ3】拡張コード追加エリア（AIはここから下に追記していくこと）
# ------------------------------------------------------------------------------
echo "🔌 [Wrapper] 拡張処理を開始します..."

# --- 拡張機能1: AIプロンプトの履歴保存 ---
if [ -n "$PROMPT" ]; then
  mkdir -p prompt_history
  timestamp=$(date +'%Y%m%d_%H%M%S')
  history_file="prompt_history/prompt_${timestamp}_mode${mode}.txt"
  
  echo "$PROMPT" > "$history_file"
  echo "💾 [Extension] プロンプトのバックアップを保存しました: $history_file"
fi

# --- 拡張機能2: 実行ログの記録 ---
log_file="update_wrapper.log"
echo "[$(date +'\%Y-\%m-\%d \%H:\%M:\%S')] Mode:$mode | Games: $game_count" >> "$log_file"
echo "📝 [Extension] 実行ログを $log_file に追記しました。"


# ==============================================================================
# ↓↓↓ AIは今後の追加リクエストをここから下に追記してください ↓↓↓
# ==============================================================================

# --- 拡張機能3: Gemini生成MP3の自動検索とランダム組み込み ---
echo "🎵 [Extension] Gemini生成の音楽ファイルを検索し、組み込み処理を開始します..."

# 検索対象のディレクトリ（とりあえずこのスクリプトがあるフォルダ全体を下層まで探します）
# ※もし特定のフォルダ（例: ~/Downloads）だけを探したい場合は、以下の "." を "~/Downloads" に変更してください。
SEARCH_DIR="."

# ファイル名に「gemini」を含むMP3を大文字小文字問わず(-iname)検索し、配列に格納する
mapfile -t gemini_audio_files < <(find "$SEARCH_DIR" -type f -iname "*gemini*.mp3")

# 見つかったファイル数をカウント
audio_count_found=${#gemini_audio_files[@]}

if [ "$audio_count_found" -gt 0 ]; then
  echo "🔍 [Extension] ${audio_count_found} 件のGemini作曲MP3ファイルを発見しました。"
  
  # 対象のゲームディレクトリが存在するかチェック
  if [ -d "$DOWNLOAD_DIR" ]; then
    for game_dir in "$DOWNLOAD_DIR"/*/; do
      # ディレクトリが存在する場合のみ処理
      if [ -d "$game_dir" ]; then
        game_name=$(basename "$game_dir")
        
        # フォルダ内に既に音声ファイル(.mp3, .ogg, .wav)が含まれているかチェック
        existing_audio=$(find "$game_dir" -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.ogg" -o -name "*.wav" \) 2>/dev/null | wc -l)
        
        if [ "$existing_audio" -eq 0 ]; then
          # 見つかったGeminiのMP3群の中から、ランダムに1曲を選ぶ
          rand_idx=$((RANDOM % audio_count_found))
          selected_bgm="${gemini_audio_files[$rand_idx]}"
          
          # コピーして bgm.mp3 として配置
          cp "$selected_bgm" "${game_dir}/bgm.mp3"
          echo "  -> 🎵 組み込み: [${game_name}] に $(basename "$selected_bgm") をセットしました"
        else
          echo "  -> ⏭️ スキップ: [${game_name}] には既に音声ファイルが存在します"
        fi
      fi
    done
    echo "✨ [Extension] 全ゲームへのGemini音楽の組み込みが完了しました！"
  else
    echo "⚠️ [Extension] ダウンロードディレクトリ ($DOWNLOAD_DIR) が見つかりません。"
  fi
else
  echo "⚠️ [Extension] 「gemini」という名前が含まれるMP3ファイルが現在のフォルダ内に見つかりませんでした。"
  echo "   (※MP3ファイルが別の場所にある場合は SEARCH_DIR を変更するか、ファイルを移動してください)"
fi

echo "✨ [Wrapper] すべての処理が正常に完了しました！"
