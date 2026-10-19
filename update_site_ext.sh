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
if [ -f "index.html" ]; then
  cp index.html index_backup.html
  echo "📦 [Wrapper] index.html のバックアップを作成しました。"
fi

# ------------------------------------------------------------------------------
# 【フェーズ2】コアシステムの実行
# ------------------------------------------------------------------------------
echo "⚙  [Wrapper] コアスクリプト (update_site.sh) を呼び出します..."

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

# --- 拡張機能3: 任意のMP3とHTMLファイルを手動選択し、配置・アップロード ---
echo "🎵 [Extension] MP3とゲーム(HTML)の組み込み処理を開始します..."

SEARCH_DIR="/home/hirosi/ダウンロード"

if [ -d "$SEARCH_DIR" ]; then
  # MP3ファイルを検索
  mapfile -t all_mp3_files < <(find "$SEARCH_DIR" -maxdepth 1 -type f -iname "*.mp3")
  audio_count_found=${#all_mp3_files[@]}
  
  # HTMLファイルを検索
  mapfile -t all_html_files < <(find "$SEARCH_DIR" -maxdepth 1 -type f -iname "*.html")
  html_count_found=${#all_html_files[@]}
else
  echo "⚠ 検索先ディレクトリ ($SEARCH_DIR) が見つかりません。"
  audio_count_found=0
  html_count_found=0
fi

# 1. MP3の選択
if [ "$audio_count_found" -gt 0 ]; then
  echo "🔍 [Extension] ${audio_count_found} 件のMP3ファイルを発見しました。"
  echo "--------------------------------------------------"
  echo " どのMP3ファイルを組み込みますか？（0でスキップ）"
  echo "--------------------------------------------------"
  echo "0) スキップする"
  for i in "${!all_mp3_files[@]}"; do
    echo "$((i+1)))$(basename "${all_mp3_files[$i]}")"
  done

  read -p "選択 (0-${audio_count_found}): " mp3_choice

  if [[ "$mp3_choice" =~ ^[0-9]+$ ]] && [ "$mp3_choice" -gt 0 ] && [ "$mp3_choice" -le "$audio_count_found" ]; then
    selected_idx=$((mp3_choice-1))
    selected_bgm="${all_mp3_files[$selected_idx]}"
    bgm_filename=$(basename "$selected_bgm")
    echo "🎵 選択されたMP3: $bgm_filename"
    
    # 2. HTML(ゲーム)の選択
    if [ "$html_count_found" -gt 0 ]; then
      echo ""
      echo "--------------------------------------------------"
      echo " どのゲーム(HTML)に組み込みますか？（0でスキップ）"
      echo "--------------------------------------------------"
      echo "0) スキップする"
      for i in "${!all_html_files[@]}"; do
        echo "$((i+1)))$(basename "${all_html_files[$i]}")"
      done
      
      read -p "選択 (0-${html_count_found}): " html_choice
      
      if [[ "$html_choice" =~ ^[0-9]+$ ]] && [ "$html_choice" -gt 0 ] && [ "$html_choice" -le "$html_count_found" ]; then
        html_idx=$((html_choice-1))
        selected_html="${all_html_files[$html_idx]}"
        html_filename=$(basename "$selected_html")
        game_name="${html_filename%.*}" # 拡張子を除いたファイル名
        
        echo "🎮 選択されたゲーム: $html_filename"
        
        # 3. カレントディレクトリへのコピー実行
        # 現在のフォルダ(Gitリポジトリ)に両方のファイルをコピーします
        cp "$selected_bgm" .
        cp "$selected_html" .
        echo "✅ 配置完了: 現在のフォルダに ${html_filename} と ${bgm_filename} をコピーしました！"
        
        # --- 拡張機能4: GitHubへのアップロード処理 ---
        echo ""
        echo "🚀 [Extension] ゲームのアップロード(Git Push)を開始します..."
        read -p "GitHub Pagesに変更をアップロードしますか？ (y/n): " upload_choice
        if [[ "$upload_choice" == [yY]* ]]; then
          echo "📦 変更をステージング(git add)しています..."
          git add .
          
          echo "📝 コミット(git commit)しています..."
          git commit -m "Update: Add game ${html_filename} and BGM${bgm_filename}"
          
          echo "☁️ アップロード(git push)しています..."
          git push
          
          if [ $? -eq 0 ]; then
            echo "✅ アップロード成功！ 数分後にGitHub Pagesに反映されます。"
          else
            echo "❌ アップロードに失敗しました。Gitの接続設定等を確認してください。"
          fi
        else
          echo "⏭ アップロードをスキップしました。"
        fi
        
      else
        echo "⏭ ゲーム(HTML)の選択がスキップされたか、無効な入力です。処理を中止します。"
      fi
    else
      echo "⚠ HTMLファイルが指定のフォルダ内に見つかりませんでした。"
    fi
  else
    echo "⏭ MP3の選択がスキップされたか、無効な入力です。処理を中止します。"
  fi
else
  echo "⚠ MP3ファイルが指定のフォルダ(${SEARCH_DIR})内に見つかりませんでした。"
fi

echo "✨ [Wrapper] すべての処理が正常に完了しました！"
