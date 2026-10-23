#!/bin/bash

# ==============================================================================
# 1. グローバル変数・設定
# ==============================================================================
DOWNLOAD_DIR="$HOME/Downloads"
[ -d "$HOME/ダウンロード" ] && DOWNLOAD_DIR="$HOME/ダウンロード"
GAMES_DIR="games"

GAME_COUNT=0
GAME_LIST_TEXT=""

# ==============================================================================
# 2. ユーティリティ（汎用ツール）
# ==============================================================================
# クリップボードへの転送処理（元通り printf と各OSのコマンドを復活）
copy_to_clipboard() {
  local content="$1"
  if command -v pbcopy >/dev/null 2>&1; then
    printf '%s' "$content" | pbcopy; return 0        # Mac
  elif command -v clip.exe >/dev/null 2>&1; then
    printf '%s' "$content" | clip.exe; return 0      # Windows(WSL)
  elif command -v xclip >/dev/null 2>&1; then
    printf '%s' "$content" | xclip -selection clipboard; return 0 # Linux X11
  elif command -v xsel >/dev/null 2>&1; then
    printf '%s' "$content" | xsel -b; return 0       # Linux X11
  elif command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$content" | wl-copy; return 0       # Linux Wayland
  fi
  return 1
}

# 開発引き継ぎブロックの抽出
extract_handoff() {
  sed -n '/AI-DEV-HANDOFF-START/,/AI-DEV-HANDOFF-END/p' "$1" 2>/dev/null
}

# HTMLエスケープ処理
escape_html() {
  echo "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'
}

# ==============================================================================
# 3. ファイル収集・更新
# ==============================================================================
setup_environment() {
  echo "🔍 [$DOWNLOAD_DIR] からゲームとデータを探索中..."
  mkdir -p "$GAMES_DIR"
}

update_game_data() {
  local data_file_found
  data_file_found=$(find "$DOWNLOAD_DIR" -maxdepth 1 -name "*.js" -type f -exec grep -l "AI_PORTFOLIO_DATA_FILE" {} + 2>/dev/null | head -n 1)

  if [ -n "$data_file_found" ]; then
    cp "$data_file_found" ./game-data.js
    echo "📦 共通データを更新しました: $(basename "$data_file_found") -> ./game-data.js"
  elif [ -f "$DOWNLOAD_DIR/game-data.js" ]; then
    cp "$DOWNLOAD_DIR/game-data.js" ./game-data.js
    echo "📦 共通データを更新しました: game-data.js"
  else
    echo "ℹ 共通データの新規更新はありません。"
  fi
}

collect_html_games() {
  while IFS= read -r file; do
    local filename=$(basename "$file")
    if [ ! -f "$GAMES_DIR/$filename" ]; then
      cp "$file" "$GAMES_DIR/"
      echo "✨ 新ゲームを発見して収集: $filename"
    fi
  done < <(find "$DOWNLOAD_DIR" -maxdepth 1 -name "*.html" -type f -exec grep -l "AI-GAME-PORTFOLIO" {} + 2>/dev/null)
}

# ==============================================================================
# 4. HTMLポートフォリオ生成
# ==============================================================================
build_index_html() {
  local index_file="index.html"
  
  cat << 'EOF' > "$index_file"
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AI Game Portfolio</title>
  <style>
    :root { --bg: #1e1e1e; --panel: #2d2d30; --primary: #007acc; --primary-hover: #005999; --text: #f0f0f0; }
    body { font-family: sans-serif; background: var(--bg); color: var(--text); margin: 0; }
    header { text-align: center; padding: 40px; background: #252526; border-bottom: 2px solid var(--primary); }
    h1 { margin: 0; color: var(--primary); }
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
  <header><h1>AI Game Portfolio</h1><p>AIと共に制作したゲーム展示室</p></header>
  <div class="controls">
    <input type="text" id="search" placeholder="🔍 検索..." onkeyup="search()">
    <span id="count" style="color: #ccc; font-weight: bold;"></span>
  </div>
  <div class="grid" id="grid">
EOF

  declare -A seen
  GAME_COUNT=0
  GAME_LIST_TEXT=""

  while IFS= read -r file; do
    [ -f "$file" ] || continue
    local filename=$(basename "$file")
    
    local title=$(grep -io '<title>.*</title>' "$file" | sed -E 's/<\/?title>//gi' | head -n 1)
    title=${title:-${filename%.*}}

    # 重複スキップ
    if [ -n "${seen[$title]:-}" ]; then continue; fi
    seen[$title]=1
    
    GAME_LIST_TEXT+="- ${title}\n"
    ((GAME_COUNT++))

    local summary=$(extract_handoff "$file" | grep -i "^概要・ルール:" | sed 's/^概要・ルール:[ ]*//' | head -n 1)
    summary=${summary:-"このゲームの概要はまだ記載されていません。"}

    local safe_title=$(escape_html "$title")
    local safe_summary=$(escape_html "$summary")

    cat << EOF >> "$index_file"
      <div class="card" data-text="${safe_title} ${safe_summary}">
        <h3>${safe_title}</h3>
        <div class="desc">${safe_summary}</div>
        <div class="buttons">
          <a href="${GAMES_DIR}/${filename}" class="btn" target="_blank">▶ Play</a>
          <button class="btn copy" onclick="copyCode('${filename}')">📋 Code</button>
        </div>
      </div>
EOF
  done < <(ls -t "$GAMES_DIR"/*.html 2>/dev/null)

  cat << EOF >> "$index_file"
  </div>
  <div id="toast">コピーしました！</div>
  <script>
    document.getElementById('count').textContent = "全 ${GAME_COUNT} 作品";
    function search() {
      const q = document.getElementById('search').value.toLowerCase();
      document.querySelectorAll('.card').forEach(c => {
        c.style.display = c.dataset.text.toLowerCase().includes(q) ? '' : 'none';
      });
    }
    async function copyCode(file) {
      try {
        const res = await fetch('${GAMES_DIR}/' + file);
        if (!res.ok) throw new Error('Network error');
        const text = await res.text();
        await navigator.clipboard.writeText(text);
        const t = document.getElementById('toast');
        t.textContent = '📋 ' + file + ' のコードをコピーしました！';
        t.className = 'show';
        setTimeout(() => { t.className = ''; }, 2800);
      } catch (err) {
        console.error(err);
        alert('コードの読み込みに失敗しました。ローカル環境の場合はサーバー経由で開く必要があります。');
      }
    }
  </script>
</body>
</html>
EOF
}

# ==============================================================================
# 5. Git連携
# ==============================================================================
sync_with_git() {
  if [ -d ".git" ] && [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    git add .
    git commit -m "🚀 ポートフォリオ更新: $(date +'%Y-%m-%d %H:%M:%S')"
    git push origin "$current_branch"
    echo "🎉 Git同期完了 (全 ${GAME_COUNT} 作品)"
  fi
}

# ==============================================================================
# 6. プロンプト生成
# ==============================================================================
get_common_rules() {
  cat << 'EOF'
【必須条件】
・HTML/CSS/JSが1つにまとまった1ファイルの完全なコードを生成してください。
・コード内のどこかに必ず「AI-GAME-PORTFOLIO」というメタタグまたは識別コメントを含めてください。
・マスタデータ（カード、レシピ、家など）は外部URL「https://morinokum.github.io/my-website/game-data.js」から読み込み（window.RUNE_GAME_DATA を利用）、取得失敗時の簡単なフォールバックデータも備えてください。
・ローカルストレージなどによるセーブ機能も備えてください。
・コード内に、開発引き継ぎ用の以下のコメントブロックを必ず含めてください。改良のたびに内容を最新に更新してください。
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

build_prompt() {
  local mode="$1"
  local req="$2"
  local target_file="$3"
  local rule_text=$(get_common_rules)
  local PROMPT=""

  if [ "$mode" = "5" ]; then
    local req_part
    if [ -n "$req" ]; then
      req_part="次回作として「${req}」という概念やテーマを組み込んだゲームを作りたいです。"
    else
      req_part="次回作を作りたいのですが、既存の作品とは全く被らない新しいルールの「面白くてハマる単一ファイルゲーム」のアイデアを考えてください。"
    fi
    PROMPT="私はこれまでに以下のHTMLブラウザゲームを作成しました。

$(echo -e "$GAME_LIST_TEXT")

${req_part}

いきなりコードを書くのではなく、まずはゲームの【設計図（仕様書）】を作成してください。
以下の項目を含めて、具体的かつ実装可能なレベルで記述してください。

【設計図に含めてほしい項目】
1. タイトルと概要
2. コアとなるゲームループ（プレイヤーの目的と面白さの核）
3. 画面レイアウト・UIの構成
4. 必要なデータ構造と状態管理（外部データ window.RUNE_GAME_DATA をどう活かすか）
5. ゲームの進行（開始、クリア、ゲームオーバー）
6. 実装すべきセーブデータの要素
7. 開発・実装のステップ

※ここでは絶対にコードを生成せず、設計図のテキストのみを出力してください。"

  elif [ "$mode" = "6" ]; then
    PROMPT="以下の【ゲーム設計図】をもとに、HTML/CSS/JSが1つにまとまった1ファイルの完全なコードを生成してください。

【ゲーム設計図】
（※ここに前回のチャットでAIが作成した設計図のテキストをペーストしてください）

${rule_text}"

  elif [ "$mode" = "4" ]; then
    local req_part
    if [ -n "$req" ]; then
      req_part="今回は「${req}」というテーマ・世界観でデータを作成してください。"
    else
      req_part="今回は『紋章シリーズ』や王道ファンタジーからは完全に離れ、AI自身で「SF」「サイバーパンク」「現代劇」「妖怪」「動物」などの新しい斬新な世界観・テーマを考えてデータを作成してください。"
    fi

    local cur_data=""
    if [ -f "./game-data.js" ]; then
      cur_data="【現在のデータ構造の参考】
以下の構造（変数名、配列の形など）を参考にしつつ、中身のテキスト（名前、説明文、属性など）を新しいテーマに合わせて**完全に一新**してください。
\`\`\`javascript
$(cat ./game-data.js)
\`\`\`"
    else
      cur_data="【データ構造について】
window.RUNE_GAME_DATA などのグローバル変数に、キャラクター、アイテム、マップ情報などの配列・オブジェクトを格納する形式にしてください。"
    fi

    PROMPT="現在、ゲームの共通データとして『game-data.js』を使用していますが、このデータに引っ張られて同じようなテーマ（紋章シリーズなど）のゲームばかり生成されてしまう問題が起きています。

そこで、今回はゲーム本体のコードではなく、【共通データ（game-data.js）のみ】を新しく作成してください。

${req_part}

【データ作成の必須条件】
1. 出力はJavaScriptのコードのみとし、単一のコードブロックで提供してください。
2. コードのどこかに必ず「AI_PORTFOLIO_DATA_FILE」という文字列をコメントで含めてください（自動収集スクリプトの目印になります）。
3. 既存のゲームとの互換性を保つため、データの階層構造（プロパティ名など）はなるべく維持しつつ、中身の世界観をガラッと変えてください。

${cur_data}

ダウンロードしてそのまま使える形式で出力をお願いします。"

  elif [ "$mode" = "2" ] || [ "$mode" = "3" ]; then
    local handoff
    handoff=$(extract_handoff "$target_file")
    [ -z "$handoff" ] && handoff="（引き継ぎ情報なし）"
    
    local req_part
    if [ -n "$req" ]; then
      req_part="このゲームを引き継いで、「${req}」を実装してください。"
    else
      req_part="このゲームを引き継いで、面白さが増すような改良や機能追加を提案し、実装してください。"
    fi

    PROMPT="以下のHTMLブラウザゲームの開発を引き継いでください。

【ゲーム名】$(basename "$target_file")

【引き継ぎ情報】
${handoff}

${req_part}
既存の仕様・セーブデータ互換を壊さないよう注意してください。
"
    if [ "$mode" = "3" ]; then
      PROMPT+="
【現在の全コード】
\`\`\`html
$(cat "$target_file")
\`\`\`
"
    fi
    PROMPT+="
${rule_text}"

  else # モード1（デフォルト）
    local req_part
    if [ -n "$req" ]; then
      req_part="次回作として「${req}」という概念やテーマを組み込んだゲームを作りたいです。※既存の『紋章シリーズ』とは異なるアプローチでお願いします。"
    else
      req_part="次回作を作りたいのですが、共通データを活かしつつも、既存作品（特に『紋章シリーズ』）とは全く被らない新しいルールの「面白くてハマる単一ファイルゲーム」のアイデアを1つ考えてください。"
    fi

    PROMPT="私はこれまでに以下のHTMLブラウザゲームを作成しました。

$(echo -e "$GAME_LIST_TEXT")
これらは私の「AI-GAME-PORTFOLIO」に収録されています。

${req_part}

${rule_text}"
  fi

  # プロンプトを出力
  printf "%s\n" "$PROMPT"
}

prompt_interactive() {
  echo -e "\n--------------------------------------------------"
  echo "🤖 AIへの発注プロンプトを作成します。モードを選択:"
  echo "  1) 🆕 新作を作る (直接コード生成)"
  echo "  2) 🔧 既存を引き継ぐ (メタデータのみ添付)"
  echo "  3) 🚀 既存を引き継ぐ (全コード添付)"
  echo "  4) 📦 共通データ(game-data.js)のみ更新"
  echo "  5) 📝 【設計図フェーズ1】ゲームの設計図を作成"
  echo "  6) 🏗 【設計図フェーズ2】完成した設計図から実装"
  
  echo -n "👉 番号 [1]: "
  local mode
  read -r mode
  mode=${mode:-1}

  local req=""
  local target=""
  
  if [ "$mode" = "1" ] || [ "$mode" = "5" ]; then
    echo -n "👉 テーマ・要素 (空Enterでお任せ): "
    read -r req
  elif [ "$mode" = "4" ]; then
    echo -n "👉 新しい世界観・テーマ (空Enterでお任せ): "
    read -r req
  elif [ "$mode" = "2" ] || [ "$mode" = "3" ]; then
    local files=()
    while IFS= read -r f; do [ -n "$f" ] && files+=("$f"); done < <(ls -t "$GAMES_DIR"/*.html 2>/dev/null || true)
    
    if [ ${#files[@]} -eq 0 ]; then
      echo "⚠ ゲームがありません"; return
    fi
    
    echo "引き継ぐゲームを選択:"
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

  local prompt_text
  prompt_text=$(build_prompt "$mode" "$req" "$target")

  if copy_to_clipboard "$prompt_text"; then
    echo -e "\n📋 クリップボードにAIへの指示文をコピーしました！"
    if [ "$mode" = "5" ]; then
      echo "    📝 新規チャットを開き、ペーストして設計図を作らせてください。"
    elif [ "$mode" = "6" ]; then
      echo "    🏗 新規チャットを開き、(※ここにAIが作成した設計図のテキストをペーストしてください) の部分を上書きして送信してください。"
    else
      echo "    新規チャットにペーストして発注してください。"
    fi
  else
    echo -e "\n⚠ コピー失敗。以下を手動でコピーしてください:\n--------------------------------------------------\n$prompt_text\n--------------------------------------------------"
  fi
}

main() {
  setup_environment
  update_game_data
  collect_html_games
  build_index_html
  sync_with_git
  prompt_interactive
}

main "$@"
