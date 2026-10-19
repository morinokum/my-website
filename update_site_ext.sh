k#!/bin/bash

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

# --- 拡張機能3: 任意のMP3を手動選択し、指定したゲームに組み込む ---
echo "🎵 [Extension] MP3音楽ファイルの組み込み処理を開始します..."

SEARCH_DIR="."
# 名前を問わず、すべてのMP3ファイルを検索し配列に格納する
mapfile -t all_mp3_files < <(find "$SEARCH_DIR" -type f -iname "*.mp3")

audio_count_found=${#all_mp3_files[@]}

if [ "$audio_count_found" -gt 0 ]; then
  echo "🔍 [Extension] ${audio_count_found} 件のMP3ファイルを発見しました。"
  echo "--------------------------------------------------"
  echo " どのMP3ファイルを組み込みますか？（0でスキップ）"
  echo "--------------------------------------------------"
  echo "0) スキップする"
  for i in "${!all_mp3_files[@]}"; do
    echo "$((i+1))) ${all_mp3_files[$i]}"
  done

  read -p "選択 (0-${audio_count_found}): " mp3_choice

  # 入力が正しい数字かチェックし、0でなければ処理を進める
  if [[ "$mp3_choice" =~ ^[0-9]+$ ]] && [ "$mp3_choice" -gt 0 ] && [ "$mp3_choice" -le "$audio_count_found" ]; then
    selected_idx=$((mp3_choice-1))
    selected_bgm="${all_mp3_files[$selected_idx]}"
    echo "🎵 選択されたMP3: $selected_bgm"
    
    # 対象のゲームディレクトリ一覧を取得・選択
    if [ -d "$DOWNLOAD_DIR" ]; then
      mapfile -t game_dirs < <(find "$DOWNLOAD_DIR" -mindepth 1 -maxdepth 1 -type d)
      game_count_found=${#game_dirs[@]}
      
      if [ "$game_count_found" -gt 0 ]; then
        echo ""
        echo "--------------------------------------------------"
        echo " どのゲームに組み込みますか？（0でスキップ）"
        echo "--------------------------------------------------"
        echo "0) スキップする"
        for i in "${!game_dirs[@]}"; do
          echo "$((i+1)))$(basename "${game_dirs[$i]}")"
        done
        
        read -p "選択 (0-${game_count_found}): " game_choice
        
        if [[ "$game_choice" =~ ^[0-9]+$ ]] && [ "$game_choice" -gt 0 ] && [ "$game_choice" -le "$game_count_found" ]; then
          game_idx=$((game_choice-1))
          selected_game_dir="${game_dirs[$game_idx]}"
          game_name=$(basename "$selected_game_dir")
          
          echo "🎮 選択されたゲーム: $game_name"
          
          # コピー実行 (bgm.mp3として配置)
          cp "$selected_bgm" "${selected_game_dir}/bgm.mp3"
          echo "✅ 組み込み完了: [${game_name}] に $(basename "$selected_bgm") を bgm.mp3 として設定しました！"
          
          # --- 拡張機能4: GitHubへのアップロード処理 ---
          echo ""
          echo "🚀 [Extension] ゲームのアップロード(Git Push)を開始します..."
          read -p "GitHub Pagesに変更をアップロードしますか？ (y/n): " upload_choice
          if [[ "$upload_choice" == [yY]* ]]; then
            echo "📦 変更をステージング(git add)しています..."
            # update_site.sh で更新された index.html 等もまとめて add します
            git add .
            
            echo "📝 コミット(git commit)しています..."
            git commit -m "Update: Add BGM to ${game_name} and update site"
            
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
          echo "⏭ ゲームの選択がスキップされたか、無効な入力です。組み込みを中止します。"
        fi
      else
        echo "⚠ ゲームディレクトリが見つかりません。"
      fi
    else
      echo "⚠ ダウンロードディレクトリ ($DOWNLOAD_DIR) が見つかりません。"
    fi
  else
    echo "⏭ MP3の選択がスキップされたか、無効な入力です。処理を中止します。"
  fi
else
  echo "⚠ MP3ファイルが現在のフォルダ内に見つかりませんでした。"
fi

echo "✨ [Wrapper] すべての処理が正常に完了しました！"
