#!/bin/bash

# ==============================================================================
# AI-EXTENDABLE WRAPPER SCRIPT (Optimized & Enhanced v2.1)
# ==============================================================================

# ------------------------------------------------------------------------------
# 【設定・ユーティリティ】ターミナルカラー設定
# ------------------------------------------------------------------------------
COLOR_INFO='\033[0;36m'   # Cyan
COLOR_SUCCESS='\033[0;32m' # Green
COLOR_WARN='\033[1;33m'    # Yellow
COLOR_ERROR='\033[0;31m'   # Red
COLOR_RESET='\033[0m'      # Reset

print_info() { echo -e "${COLOR_INFO}$1${COLOR_RESET}"; }
print_success() { echo -e "${COLOR_SUCCESS}$1${COLOR_RESET}"; }
print_warn() { echo -e "${COLOR_WARN}$1${COLOR_RESET}"; }
print_error() { echo -e "${COLOR_ERROR}$1${COLOR_RESET}"; }

print_info "🚀 [Wrapper] 拡張版アップデーターを起動します..."

# ダウンロードディレクトリの判定（本体と同じロジック）
DOWNLOAD_DIR="$HOME/Downloads"
[ -d "$HOME/ダウンロード" ] && DOWNLOAD_DIR="$HOME/ダウンロード"

# ------------------------------------------------------------------------------
# 【フェーズ1】事前処理エリア
# ------------------------------------------------------------------------------
if [ -f "index.html" ]; then
  cp index.html index_backup.html
  print_success "📦 [Wrapper] index.html のバックアップを作成しました。"
fi

# ------------------------------------------------------------------------------
# 【フェーズ2】コアシステムの実行
# ------------------------------------------------------------------------------
print_info "⚙  [Wrapper] コアスクリプト (update_site.sh) を呼び出します..."

# コアスクリプトを実行し、変数を引き継ぐ
source ./update_site.sh

echo -e "\n${COLOR_INFO}⚙  [Wrapper] コアスクリプトの実行が完了しました。${COLOR_RESET}"

# ------------------------------------------------------------------------------
# 【フェーズ3】拡張コード追加エリア
# ------------------------------------------------------------------------------
print_info "🔌 [Wrapper] 拡張処理を開始します..."

# --- 拡張機能1: AIプロンプトの履歴保存 (整理して保存) ---
if [ -n "$PROMPT" ]; then
  mkdir -p prompt_history
  timestamp=$(date +'%Y%m%d_%H%M%S')
  # 対象ゲーム名がある場合はファイル名に含める
  target_name="new"
  [ -n "$target" ] && target_name=$(basename "$target" .html)
  
  history_file="prompt_history/prompt_${timestamp}_mode${mode}_${target_name}.txt"
  echo "$PROMPT" > "$history_file"
  print_success "💾 [Extension] AIへのプロンプト履歴を保存しました: $history_file"
fi

# --- 拡張機能2: 実行ログの記録 ---
log_file="update_wrapper.log"
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Mode:$mode | Target: ${target_name:-none} | Games: ${game_count:-0}" >> "$log_file"
print_success "📝 [Extension] 実行ログを $log_file に記録しました。"


# --- 拡張機能3: メディアアセット(BGM/画像)と手動HTMLの組み込み (複数選択対応) ---
print_info "\n🎵🖼 [Extension] アセットとゲームの手動組み込み処理を開始します"

SEARCH_DIR="$DOWNLOAD_DIR"

if [ -d "$SEARCH_DIR" ]; then
  # 音声と画像を検索 (mp3, wav, png, jpg, jpeg, webp)
  mapfile -t all_assets < <(find "$SEARCH_DIR" -maxdepth 1 -type f \( -iname "*.mp3" -o -iname "*.wav" -o -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \))
  asset_count=${#all_assets[@]}
  
  # HTMLファイルを検索
  mapfile -t all_html_files < <(find "$SEARCH_DIR" -maxdepth 1 -type f -iname "*.html")
  html_count=${#all_html_files[@]}
else
  print_warn "⚠ 検索先ディレクトリ ($SEARCH_DIR) が見つかりません。"
  asset_count=0
  html_count=0
fi

copied_assets=()
copied_html=""

# 1. アセットの選択 (複数選択対応)
if [ "$asset_count" -gt 0 ]; then
  echo -e "\n${COLOR_INFO}🔍 ${asset_count} 件のメディアファイル(音声/画像)を発見しました。${COLOR_RESET}"
  echo "--------------------------------------------------"
  echo " 組み込むアセットを選んでください（スペース区切りで複数選択可）"
  echo " 例: 1 3 4 （※0でスキップ）"
  echo "--------------------------------------------------"
  echo "0) スキップする"
  for i in "${!all_assets[@]}"; do
    echo "$((i+1))) $(basename "${all_assets[$i]}")"
  done

  read -p "選択 (0-${asset_count}): " asset_choices

  if [[ "$asset_choices" != "0" && -n "$asset_choices" ]]; then
    for choice in $asset_choices; do
      if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -gt 0 ] && [ "$choice" -le "$asset_count" ]; then
        idx=$((choice-1))
        file="${all_assets[$idx]}"
        cp "$file" .
        copied_assets+=("$(basename "$file")")
        print_success "✅ コピー: $(basename "$file")"
      fi
    done
  else
    print_warn "⏭ アセットの選択をスキップしました。"
  fi
else
  print_warn "⏭ 音声や画像ファイルが指定フォルダ内にありませんでした。"
fi

# 2. HTML(ゲーム)の手動選択と自動紐付け
if [ "$html_count" -gt 0 ]; then
  echo -e "\n${COLOR_INFO}🔍 ${html_count} 件のHTMLファイルを発見しました。${COLOR_RESET}"
  echo "--------------------------------------------------"
  echo " 手動で配置・更新するゲーム(HTML)を選んでください"
  echo " ※コアスクリプトで自動収集されなかったものを強制配置できます"
  echo "--------------------------------------------------"
  echo "0) スキップする"
  for i in "${!all_html_files[@]}"; do
    echo "$((i+1))) $(basename "${all_html_files[$i]}")"
  done
  
  read -p "選択 (0-${html_count}): " html_choice
  
  if [[ "$html_choice" =~ ^[0-9]+$ ]] && [ "$html_choice" -gt 0 ] && [ "$html_choice" -le "$html_count" ]; then
    html_idx=$((html_choice-1))
    selected_html="${all_html_files[$html_idx]}"
    html_filename=$(basename "$selected_html")
    
    # games フォルダとルートの両方にコピー
    cp "$selected_html" games/ 2>/dev/null
    cp "$selected_html" .
    copied_html="$html_filename"
    print_success "🎮 配置完了: $html_filename"

    # =================================================================
    # 自動紐付け処理 (BGM/効果音)
    # =================================================================
    for asset in "${copied_assets[@]}"; do
      if [[ "$asset" == *.mp3 ]] || [[ "$asset" == *.wav ]]; then
        print_info "🔧 HTML内のBGM設定を '$asset' に自動紐付けしています..."
        
        # HTML内の src="*.mp3" をコピーしたファイル名に書き換える
        temp_file=$(mktemp)
        sed "s/src=\"[^\"]*\.mp3\"/src=\"$asset\"/g" "$copied_html" > "$temp_file"
        mv "$temp_file" "$copied_html"
        
        # gamesフォルダ内のHTMLも更新
        cp "$copied_html" games/ 2>/dev/null
        
        print_success "✅ HTMLの自動書き換えが完了！音が鳴るようになりました。"
        break
      fi
    done
    
  else
    print_warn "⏭ HTMLの手動配置をスキップしました。"
  fi
fi

# --- 拡張機能4: Gitステータス確認とスマートコミット ---
if [ ${#copied_assets[@]} -gt 0 ] || [ -n "$copied_html" ]; then
  echo -e "\n${COLOR_INFO}🚀 [Extension] 選択した追加ファイルのGitアップロード処理${COLOR_RESET}"
  
  echo "【現在のGit変更状況】"
  git status --short
  echo "--------------------------------------------------"
  
  read -p "これらの変更をGitHub Pagesに追加アップロードしますか？ (y/n): " upload_choice
  if [[ "$upload_choice" == [yY]* ]]; then
    
    # スマートなデフォルトコミットメッセージの生成
    msg_assets=$(IFS=, ; echo "${copied_assets[*]}")
    default_msg="Update:"
    [ -n "$copied_html" ] && default_msg+=" ${copied_html}"
    [ ${#copied_assets[@]} -gt 0 ] && default_msg+=" assets(${msg_assets})"
    
    echo -n "📝 コミットメッセージを入力 (空Enterでデフォルト: '$default_msg'): "
    read -r custom_msg
    commit_msg="${custom_msg:-$default_msg}"

    print_info "📦 変更をステージング(git add)しています..."
    git add .
    
    print_info "📝 コミット(git commit)しています..."
    git commit -m "$commit_msg"
    
    print_info "☁ アップロード(git push)しています..."
    if git push; then
      print_success "✅ アップロード成功！ 数分後にGitHub Pagesに反映されます。"
    else
      print_error "❌ アップロードに失敗しました。Gitの接続設定等を確認してください。"
    fi
  else
    print_warn "⏭ アップロードをスキップしました。"
  fi
else
  echo -e "\n${COLOR_INFO}ℹ 追加のアセット/HTML操作は行われませんでした。${COLOR_RESET}"
fi

print_success "\n✨ [Wrapper] すべての処理が完了しました！ お疲れ様でした！"
