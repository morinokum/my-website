#!/bin/bash

# ==============================================================================
# 1. グローバル変数・設定
# ==============================================================================
DOWNLOAD_DIR="$HOME/Downloads"
[ -d "$HOME/ダウンロード" ] && DOWNLOAD_DIR="$HOME/ダウンロード"
GAMES_DIR="games"
APPS_DIR="apps"

# 【安全対策】設定ファイルは必ずホームディレクトリに保存する
CONFIG_FILE="$HOME/.portfolio_ai_config"

GAME_COUNT=0
APP_COUNT=0
GAME_LIST_TEXT=""
APP_LIST_TEXT=""

# ==============================================================================
# 2. ユーティリティ（汎用ツール）
# ==============================================================================
copy_to_clipboard() {
  local content="$1"
  if command -v pbcopy >/dev/null 2>&1; then
    printf '%s' "$content" | pbcopy; return 0
  elif command -v clip.exe >/dev/null 2>&1; then
    printf '%s' "$content" | clip.exe; return 0
  elif command -v xclip >/dev/null 2>&1; then
    printf '%s' "$content" | xclip -selection clipboard; return 0
  elif command -v xsel >/dev/null 2>&1; then
    printf '%s' "$content" | xsel -b; return 0
  elif command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$content" | wl-copy; return 0
  fi
  return 1
}

extract_handoff() {
  sed -n '/AI-DEV-HANDOFF-START/,/AI-DEV-HANDOFF-END/p' "$1" 2>/dev/null
}

escape_html() {
  echo "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'
}

# ==============================================================================
# 3. Gemini API 連携機能 & セキュリティ対策
# ==============================================================================
secure_git_config() {
  local ignore_file=".gitignore"
  local target="*portfolio_ai_config*"
  
  if [ -d ".git" ]; then
    if [ ! -f "$ignore_file" ] || ! grep -q "$target" "$ignore_file"; then
      echo "$target" >> "$ignore_file"
      echo "🛡 セキュリティ対策: .gitignore を更新し、設定ファイルのGit混入を防ぎました。"
    fi
  fi
}

setup_api_key() {
  if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
  fi

  if [ -z "$GEMINI_API_KEY" ]; then
    echo -e "\n🔑 Gemini APIキーが設定されていません。"
    echo "Google AI Studio (https://aistudio.google.com/) で取得したAPIキーを入力してください:"
    echo -n "👉 APIキー (後で設定する場合は空Enter): "
    read -r api_key
    echo ""
    if [ -n "$api_key" ]; then
      echo "GEMINI_API_KEY=\"$api_key\"" > "$CONFIG_FILE"
      chmod 600 "$CONFIG_FILE"
      export GEMINI_API_KEY="$api_key"
      echo "✅ APIキーを安全な場所（$CONFIG_FILE）に保存しました。"
    else
      echo "⚠ APIキーが入力されなかったため、AIアイデア生成機能はオフになります。"
    fi
  fi
}

generate_idea_with_gemini() {
  local subject="$1"
  local list_text="$2"

  if [ -z "$GEMINI_API_KEY" ]; then
    echo "⚠ Gemini APIキーが設定されていないため、アイデアを生成できません。"
    return 1
  fi

  echo -e "\n🧠 Geminiが過去の作品リストを読み込み、新しい${subject}のアイデアを考え中..."
  
  # 【超進化ポイント】現在使える最新のAIモデルを自動的に探して設定する
  local model_name=$(python3 -c "
import urllib.request, json
url = 'https://generativelanguage.googleapis.com/v1beta/models?key=${GEMINI_API_KEY}'
try:
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req) as res:
        data = json.loads(res.read().decode())
        valid = [m['name'].replace('models/', '') for m in data.get('models', []) if 'generateContent' in m.get('supportedGenerationMethods', [])]
        flash = [m for m in valid if 'flash' in m]
        pro = [m for m in valid if 'pro' in m]
        if flash: print(flash[0])
        elif pro: print(pro[0])
        elif valid: print(valid[0])
except Exception:
    pass
" 2>/dev/null)

  if [ -z "$model_name" ]; then
    echo "⚠ 利用可能なAIモデルの取得に失敗しました。APIキーを確認してください。"
    return 1
  fi
  
  echo "🤖 使用モデル: $model_name が自動選択されました"

  # プロンプトの組み立て
  local system_prompt="あなたは優秀な${subject}の企画・開発者です。これまでに以下の${subject}を作成しました。\n\n${list_text}\n\nこれらと重複しない、かつ個人開発のブラウザアプリ(HTML1ファイル)として実現可能な、斬新で面白い次回作のアイデアを【1つだけ】提案してください。タイトル、概要、面白いポイントを含めて出力してください。"

  local escaped_prompt=$(echo "$system_prompt" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')

  local api_url="https://generativelanguage.googleapis.com/v1beta/models/${model_name}:generateContent?key=${GEMINI_API_KEY}"
  local payload="{\"contents\":[{\"parts\":[{\"text\":\"${escaped_prompt}\"}]}]}"

  # API呼び出し
  local response=$(curl -s -X POST -H "Content-Type: application/json" -d "$payload" "$api_url")
  
  # Pythonを使って安全にJSONをパースして結果を抽出
  local idea=$(echo "$response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    text = data.get('candidates', [{}])[0].get('content', {}).get('parts', [{}])[0].get('text', '')
    print(text.strip())
except Exception:
    print('')
" 2>/dev/null)

  if [ -z "$idea" ]; then
      echo "⚠ APIからの応答の取得に失敗しました。通信エラーの可能性があります。"
      return 1
  fi
  
  echo "$idea"
}

# ==============================================================================
# 4. ファイル収集・更新
# ==============================================================================
setup_environment() {
  echo "🔍 [$DOWNLOAD_DIR] からデータを探索中..."
  mkdir -p "$GAMES_DIR"
  mkdir -p "$APPS_DIR"
}

update_shared_data() {
  local g_data
  g_data=$(find "$DOWNLOAD_DIR" -maxdepth 1 -name "*.js" -type f -exec grep -l "AI_PORTFOLIO_DATA_FILE" {} + 2>/dev/null | head -n 1)
  if [ -n "$g_data" ]; then
    cp "$g_data" ./game-data.js
    echo "📦 ゲーム共通データを更新: $(basename "$g_data") -> ./game-data.js"
  fi

  local a_data
  a_data=$(find "$DOWNLOAD_DIR" -maxdepth 1 -name "*.js" -type f -exec grep -l "AI_APP_DATA_FILE" {} + 2>/dev/null | head -n 1)
  if [ -n "$a_data" ]; then
    cp "$a_data" ./app-data.js
    echo "📦 アプリ共通データを更新: $(basename "$a_data") -> ./app-data.js"
  fi
}

collect_html_files() {
  while IFS= read -r file; do
    local filename=$(basename "$file")
    if grep -q "AI-GAME-PORTFOLIO" "$file" 2>/dev/null; then
      if [ ! -f "$GAMES_DIR/$filename" ]; then
        cp "$file" "$GAMES_DIR/"
        echo "🎮 新ゲームを収集: $filename"
      fi
    elif grep -q "AI-APP-PORTFOLIO" "$file" 2>/dev/null; then
      if [ ! -f "$APPS_DIR/$filename" ]; then
        cp "$file" "$APPS_DIR/"
        echo "🛠 新アプリを収集: $filename"
      fi
    fi
  done < <(find "$DOWNLOAD_DIR" -maxdepth 1 -name "*.html" -type f 2>/dev/null)
}

# ==============================================================================
# 5. HTML生成
# ==============================================================================
generate_html() {
  local type="$1"
  local index_file=""
  local title=""
  local subtitle=""
  local primary_color=""
  local hover_color=""
  local dir_name=""
  local nav_link=""
  local item_label=""

  if [ "$type" = "game" ]; then
    index_file="index.html"
    title="AI Game Portfolio"
    subtitle="AIと共に制作したゲーム展示室"
    primary_color="#007acc"
    hover_color="#005999"
    dir_name="$GAMES_DIR"
    item_label="作品"
    nav_link='<a href="apps.html" style="color: #009688; text-decoration: none; font-weight: bold; font-size: 1.1em; background: #1e1e1e; padding: 10px 20px; border-radius: 20px; border: 1px solid #009688;">🛠 実用アプリ・ツール一覧へ</a>'
  else
    index_file="apps.html"
    title="AI App Portfolio"
    subtitle="AIと共に制作した実用Webツール・アプリ群"
    primary_color="#009688"
    hover_color="#00796b"
    dir_name="$APPS_DIR"
    item_label="ツール"
    nav_link='<a href="index.html" style="color: #007acc; text-decoration: none; font-weight: bold; font-size: 1.1em; background: #1e1e1e; padding: 10px 20px; border-radius: 20px; border: 1px solid #007acc;">🎮 ゲーム一覧へ</a>'
  fi

  cat << EOF > "$index_file"
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title}</title>
  <style>
    :root { --bg: #1e1e1e; --panel: #2d2d30; --primary: ${primary_color}; --primary-hover: ${hover_color}; --text: #f0f0f0; }
    body { font-family: sans-serif; background: var(--bg); color: var(--text); margin: 0; }
    header { text-align: center; padding: 40px; background: #252526; border-bottom: 2px solid var(--primary); }
    h1 { margin: 0 0 10px 0; color: var(--primary); }
    .nav-buttons { margin-top: 25px; }
    .controls { max-width: 1000px; margin: 20px auto; padding: 0 20px; display: flex; justify-content: space-between; align-items: center; }
    input { width: 100%; max-width: 300px; padding: 10px; border-radius: 20px; border: 1px solid #3e3e42; background: var(--panel); color: white; outline: none; }
    input:focus { border-color: var(--primary); }
    .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 20px; max-width: 1000px; margin: auto; padding: 20px; min-height: 50vh; }
    .card { background: var(--panel); padding: 20px; border-radius: 10px; border: 1px solid #3e3e42; display: flex; flex-direction: column; }
    .card h3 { margin-top: 0; color: #fff; }
    .desc { flex-grow: 1; font-size: 0.9em; color: #ccc; margin-bottom: 15px; display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden; }
    .buttons { display: flex; gap: 10px; }
    .btn { flex: 1; padding: 10px; text-align: center; background: var(--primary); color: white; text-decoration: none; border-radius: 5px; border: none; cursor: pointer; font-weight: bold; }
    .btn:hover { background: var(--primary-hover); }
    .btn.copy { background: #3e3e42; }
    .btn.copy:hover { background: #505055; }
    #toast { visibility: hidden; min-width: 250px; background-color: var(--primary); color: #fff; text-align: center; border-radius: 8px; padding: 16px; position: fixed; z-index: 1000; left: 50%; bottom: 30px; transform: translateX(-50%); box-shadow: 0 4px 12px rgba(0,0,0,0.4); font-weight: bold; }
    #toast.show { visibility: visible; animation: fadein 0.3s, fadeout 0.4s 2.5s; }
    @keyframes fadein { from {bottom: 0; opacity: 0;} to {bottom: 30px; opacity: 1;} }
    @keyframes fadeout { from {bottom: 30px; opacity: 1;} to {bottom: 0; opacity: 0;} }
  </style>
</head>
<body>
  <header>
    <h1>${title}</h1><p>${subtitle}</p>
    <div class="nav-buttons">${nav_link}</div>
  </header>
  <div class="controls">
    <input type="text" id="search" placeholder="🔍 検索..." onkeyup="search()">
    <span id="count" style="color: #ccc; font-weight: bold;"></span>
  </div>
  <div class="grid" id="grid">
EOF

  declare -A seen
  local count=0
  local list_text=""

  while IFS= read -r file; do
    [ -f "$file" ] || continue
    local filename=$(basename "$file")
    local file_title=$(grep -io '<title>.*</title>' "$file" | sed -E 's/<\/?title>//gi' | head -n 1)
    file_title=${file_title:-${filename%.*}}

    if [ -n "${seen[$file_title]:-}" ]; then continue; fi
    seen[$file_title]=1
    
    list_text+="- ${file_title}\n"
    ((count++))

    local search_word="概要・ルール:"
    [ "$type" = "app" ] && search_word="目的・概要:"
    local summary=$(extract_handoff "$file" | grep -i "^${search_word}" | sed "s/^${search_word}[ ]*//" | head -n 1)
    summary=${summary:-"概要はまだ記載されていません。"}

    local safe_title=$(escape_html "$file_title")
    local safe_summary=$(escape_html "$summary")

    cat << EOF >> "$index_file"
      <div class="card" data-text="${safe_title} ${safe_summary}">
        <h3>${safe_title}</h3>
        <div class="desc">${safe_summary}</div>
        <div class="buttons">
          <a href="${dir_name}/${filename}" class="btn" target="_blank">▶ Open</a>
          <button class="btn copy" onclick="copyCode('${filename}')">📋 Code</button>
        </div>
      </div>
EOF
  done < <(ls -t "$dir_name"/*.html 2>/dev/null)

  cat << EOF >> "$index_file"
  </div>
  <div id="toast">コピーしました！</div>
  <script>
    document.getElementById('count').textContent = "全 ${count} ${item_label}";
    function search() {
      const q = document.getElementById('search').value.toLowerCase();
      document.querySelectorAll('.card').forEach(c => {
        c.style.display = c.dataset.text.toLowerCase().includes(q) ? '' : 'none';
      });
    }
    async function copyCode(file) {
      try {
        const res = await fetch('${dir_name}/' + file);
        if (!res.ok) throw new Error('Network error');
        const text = await res.text();
        await navigator.clipboard.writeText(text);
        const t = document.getElementById('toast');
        t.textContent = '📋 ' + file + ' のコードをコピーしました！';
        t.className = 'show';
        setTimeout(() => { t.className = ''; }, 2800);
      } catch (err) {
        console.error(err);
        alert('コードの読み込みに失敗しました。');
      }
    }
  </script>
</body>
</html>
EOF

  if [ "$type" = "game" ]; then
    GAME_COUNT=$count
    GAME_LIST_TEXT=$list_text
  else
    APP_COUNT=$count
    APP_LIST_TEXT=$list_text
  fi
}

# ==============================================================================
# 6. Git連携
# ==============================================================================
sync_with_git() {
  if [ -d ".git" ] && [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    git add .
    git commit -m "🚀 ポートフォリオ更新: ゲーム(${GAME_COUNT}) アプリ(${APP_COUNT})"
    git push origin "$current_branch"
    echo "🎉 Git同期完了 (ゲーム: ${GAME_COUNT}作品 / アプリ: ${APP_COUNT}ツール)"
  fi
}

# ==============================================================================
# 7. プロンプト生成
# ==============================================================================
get_game_rules() {
  cat << 'EOF'
【必須条件】
・HTML/CSS/JSが1つにまとまった1ファイルの完全なコードを生成してください。
・コード内のどこかに必ず「AI-GAME-PORTFOLIO」というメタタグまたは識別コメントを含めてください。
・マスタデータは外部URL「https://morinokum.github.io/my-website/game-data.js」から読み込み（window.RUNE_GAME_DATA を利用）、取得失敗時のフォールバックデータも備えてください。
・ローカルストレージなどによるセーブ機能も備えてください。
・コード内に、開発引き継ぎ用の以下のコメントブロックを必ず含めてください。
<!-- AI-DEV-HANDOFF-START
タイトル:
バージョン:
概要・ルール:
主要な構造（関数・状態管理・画面遷移）:
セーブデータのキー:
実装済み機能:
未実装・TODO:
設計上のこだわり・注意点:
AI-DEV-HANDOFF-END -->
EOF
}

get_app_rules() {
  cat << 'EOF'
【必須条件】
・HTML/CSS/JSが1つにまとまった1ファイルの完全なコードを生成してください。外部CDN（Tailwind等）の使用は自由です。
・コード内のどこかに必ず「AI-APP-PORTFOLIO」というメタタグまたは識別コメントを含めてください。
・共通設定データは外部URL「https://morinokum.github.io/my-website/app-data.js」から読み込み（window.APP_SHARED_DATA を利用）、取得失敗時のフォールバックデータも備えてください。
・ローカルストレージなどによるデータ保存機能も備えてください。
・コード内に、開発引き継ぎ用の以下のコメントブロックを必ず含めてください。
<!-- AI-DEV-HANDOFF-START
タイトル:
バージョン:
目的・概要:
主要な機能・UI構成:
データ構造・保存キー:
実装済み機能:
未実装・TODO:
設計上のこだわり・注意点:
AI-DEV-HANDOFF-END -->
EOF
}

build_prompt() {
  local t_type="$1"
  local mode="$2"
  local req="$3"
  local target_file="$4"
  
  local rule_text=""
  local list_text=""
  local data_file=""
  local marker=""
  local subject=""

  if [ "$t_type" = "1" ]; then
    rule_text=$(get_game_rules)
    list_text="$GAME_LIST_TEXT"
    data_file="game-data.js"
    marker="AI_PORTFOLIO_DATA_FILE"
    subject="ゲーム"
  else
    rule_text=$(get_app_rules)
    list_text="$APP_LIST_TEXT"
    data_file="app-data.js"
    marker="AI_APP_DATA_FILE"
    subject="Webアプリ（ツール）"
  fi

  local PROMPT=""

  if [ "$mode" = "5" ]; then
    PROMPT="私はこれまでに以下の${subject}を作成しました。

$(echo -e "$list_text")

次回作として「${req:-新しい斬新なアイデア}」を実現する${subject}を作りたいです。
いきなりコードを書くのではなく、まずは【要件定義・基本設計書】を作成してください。
目的、コア機能、UI構成、データ構造、ユーザーフローを含めて具体的に記述してください。コードはまだ書かないでください。"

  elif [ "$mode" = "6" ]; then
    PROMPT="以下の【設計書】をもとに、HTML/CSS/JSが1つにまとまった完全なコードを生成してください。

【設計書】
（※ここにAIが作成した設計書のテキストをペーストしてください）

${rule_text}"

  elif [ "$mode" = "4" ]; then
    local cur_data=""
    [ -f "./$data_file" ] && cur_data="【現在のデータの参考】\n\`\`\`javascript\n$(cat ./$data_file)\n\`\`\`"
    
    PROMPT="現在、共通データとして『${data_file}』を使用しています。
今回は本体コードではなく、【共通データ（${data_file}）のみ】を新しく作成してください。
テーマ・用途: ${req:-新しい汎用データセット}

【必須条件】
1. 出力はJavaScriptコードのみの単一ブロック。
2. 必ず「${marker}」という文字列をコメントで含める。
${cur_data}"

  elif [ "$mode" = "2" ] || [ "$mode" = "3" ]; then
    local handoff=$(extract_handoff "$target_file")
    [ -z "$handoff" ] && handoff="（引き継ぎ情報なし）"
    
    PROMPT="以下の${subject}の開発を引き継いでください。

【タイトル】$(basename "$target_file")
【引き継ぎ情報】
${handoff}

要求: ${req:-使い勝手の向上や機能追加を実装してください}
既存の仕様やセーブデータを壊さないよう注意してください。
"
    if [ "$mode" = "3" ]; then
      PROMPT+="
【現在の全コード】
\`\`\`html
$(cat "$target_file")
\`\`\`
"
    fi
    PROMPT+="${rule_text}"

  else # モード1
    PROMPT="私はこれまでに以下の${subject}を作成しました。

$(echo -e "$list_text")

次回作として「${req:-実用的で新しいアイデア}」を実現する${subject}を作りたいです。
${rule_text}"
  fi

  printf "%s\n" "$PROMPT"
}

prompt_interactive() {
  echo -e "\n--------------------------------------------------"
  echo "🤖 AIへの発注プロンプトを作成します。"
  echo "どちらを作りますか？"
  echo "  1) 🎮 ゲーム"
  echo "  2) 🛠 アプリ"
  echo -n "👉 選択 [1]: "
  local t_type
  read -r t_type
  t_type=${t_type:-1}

  echo -e "\n作業モードを選択:"
  echo "  1) 🆕 新作を作る (直接コード生成)"
  echo "  2) 🔧 既存を引き継ぐ (メタデータのみ添付)"
  echo "  3) 🚀 既存を引き継ぐ (全コード添付)"
  echo "  4) 📦 共通データのみ更新"
  echo "  5) 📝 【設計フェーズ1】設計書を作成"
  echo "  6) 🏗 【設計フェーズ2】設計書から実装"
  
  echo -n "👉 番号 [1]: "
  local mode
  read -r mode
  mode=${mode:-1}

  local req=""
  local target=""
  
  if [ "$mode" = "1" ] || [ "$mode" = "5" ]; then
    echo -e "\n💡 ヒント: 「ai」と入力すると、Gemini APIが過去の作品リストを考慮して斬新なアイデアを自動で考えます！"
    echo -n "👉 テーマ・目的 (空Enterでお任せ, 'ai'で自動生成): "
    read -r req

    # 「ai」と入力された場合、Geminiにアイデアを生成させる
    if [[ "$req" == "ai" || "$req" == "AI" ]]; then
      local subj="ゲーム"
      local list_text="$GAME_LIST_TEXT"
      if [ "$t_type" = "2" ]; then
        subj="Webアプリ（ツール）"
        list_text="$APP_LIST_TEXT"
      fi

      local ai_idea=$(generate_idea_with_gemini "$subj" "$list_text")
      
      if [ -n "$ai_idea" ]; then
        echo -e "\n✨ 【Geminiの提案アイデア】\n---------------------------------\n$ai_idea\n---------------------------------"
        req="以下のアイデアを実現してください。\n\n$ai_idea"
      else
        req="" # APIエラー時はデフォルトにフォールバック
      fi
    fi

  elif [ "$mode" = "4" ]; then
    echo -n "👉 データセットの内容 (空Enterでお任せ): "
    read -r req
  elif [ "$mode" = "2" ] || [ "$mode" = "3" ]; then
    local dir="$GAMES_DIR"
    [ "$t_type" = "2" ] && dir="$APPS_DIR"
    
    local files=()
    while IFS= read -r f; do [ -n "$f" ] && files+=("$f"); done < <(ls -t "$dir"/*.html 2>/dev/null || true)
    
    if [ ${#files[@]} -eq 0 ]; then
      echo "⚠ 対象がありません"; return
    fi
    
    echo "引き継ぐ対象を選択:"
    for i in "${!files[@]}"; do
      local mark="  "
      grep -q "AI-DEV-HANDOFF-START" "${files[$i]}" && mark="📝"
      printf "  %2d) %s %s\n" "$((i+1))" "$mark" "$(basename "${files[$i]}")"
    done
    echo -n "👉 番号: "
    local num
    read -r num
    
    target="${files[$((num-1))]}"
    if [ ! -f "$target" ]; then
      echo "⚠ 無効な番号です"; return
    fi
    
    echo -n "👉 変更・追加内容 (空Enterでお任せ): "
    read -r req
  fi

  local prompt_text=$(build_prompt "$t_type" "$mode" "$req" "$target")

  if copy_to_clipboard "$prompt_text"; then
    echo -e "\n📋 クリップボードに指示文をコピーしました！新規チャットで貼り付けてください。"
  else
    echo -e "\n⚠ コピー失敗。以下を手動でコピーしてください:\n--------------------------------------------------\n$prompt_text\n--------------------------------------------------"
  fi
}

main() {
  secure_git_config
  setup_api_key
  setup_environment
  update_shared_data
  collect_html_files
  generate_html "game"
  generate_html "app"
  sync_with_git
  prompt_interactive
}

main "$@"
