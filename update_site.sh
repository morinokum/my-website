#!/bin/bash

# ==============================================================================
# 1. グローバル変数・設定
# ==============================================================================
DOWNLOAD_DIR="$HOME/Downloads"
[ -d "$HOME/ダウンロード" ] && DOWNLOAD_DIR="$HOME/ダウンロード"
GAMES_DIR="games"

# 各関数をまたいで共有するデータ
GAME_COUNT=0
GAME_LIST_TEXT=""

# ==============================================================================
# 2. ユーティリティ関数（汎用ツール）
# ==============================================================================
# クリップボードへの転送処理
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
  sed -n '/AI-DEV-HANDOFF-START/,/AI-DEV-HANDOFF-END/p' "$1"
}

# ==============================================================================
# 3. メイン機能の部品（関数定義）
# ==============================================================================

setup_environment() {
  echo "🔍 [$DOWNLOAD_DIR] から新しいゲームおよび共通データを探索中..."
  mkdir -p "$GAMES_DIR"
}

update_game_data() {
  local data_file_found
  data_file_found=$(find "$DOWNLOAD_DIR" -maxdepth 1 -name "*.js" -type f -exec grep -l "AI_PORTFOLIO_DATA_FILE" {} + 2>/dev/null | head -n 1)

  if [ -n "$data_file_found" ]; then
    cp "$data_file_found" ./game-data.js
    echo "📦 共通データファイルを更新しました: $(basename "$data_file_found") -> ./game-data.js"
  elif [ -f "$DOWNLOAD_DIR/game-data.js" ]; then
    cp "$DOWNLOAD_DIR/game-data.js" ./game-data.js
    echo "📦 共通データファイルを更新しました: game-data.js -> ./game-data.js"
  else
    echo "ℹ 共通データファイル(game-data.js)の新規更新はありませんでした。"
  fi
}

collect_html_games() {
  while IFS= read -r file; do
    local filename
    filename=$(basename "$file")
    
    if [ -f "$GAMES_DIR/$filename" ]; then
      continue
    fi

    echo "✨ 新しいゲームを発見して収集: $filename"
    cp "$file" "$GAMES_DIR/"
  done < <(find "$DOWNLOAD_DIR" -maxdepth 1 -name "*.html" -type f -exec grep -l "AI-GAME-PORTFOLIO" {} + 2>/dev/null)
}

build_index_html() {
  cat << 'HTMLEOF' > index.html
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AI Game Portfolio</title>
  <style>
    :root { --bg: #1e1e1e; --panel: #2d2d30; --border: #3e3e42; --primary: #007acc; --primary-hover: #005999; --text: #f0f0f0; --text-muted: #cccccc; }
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: var(--bg); color: var(--text); margin: 0; padding: 0; }
    header { text-align: center; padding: 60px 20px; background-color: #252526; border-bottom: 2px solid var(--primary); }
    h1 { margin: 0; font-size: 2.8em; color: var(--primary); letter-spacing: 1px; }
    header p { color: var(--text-muted); margin-top: 10px; font-size: 1.1em; }
    .controls { max-width: 1000px; margin: 30px auto 10px; padding: 0 20px; display: flex; justify-content: space-between; align-items: center; }
    #searchInput { width: 100%; max-width: 350px; padding: 12px 16px; border-radius: 20px; border: 1px solid var(--border); background: var(--panel); color: #fff; font-size: 1em; outline: none; transition: border-color 0.2s; }
    #searchInput:focus { border-color: var(--primary); }
    .container { max-width: 1000px; margin: 0 auto; padding: 20px; min-height: 50vh; }
    .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 25px; }
    .card { background: var(--panel); border-radius: 12px; padding: 25px; box-shadow: 0 8px 16px rgba(0,0,0,0.2); transition: transform 0.2s, box-shadow 0.2s; border: 1px solid var(--border); display: flex; flex-direction: column; justify-content: space-between; }
    .card:hover { transform: translateY(-5px); box-shadow: 0 12px 20px rgba(0,0,0,0.3); border-color: var(--primary); }
    .card h3 { margin: 0 0 10px 0; color: #ffffff; font-size: 1.4em; }
    .tag { display: inline-block; background: var(--primary); color: white; padding: 4px 10px; border-radius: 12px; font-size: 0.75em; margin-bottom: 15px; font-weight: bold; }
    .desc { font-size: 0.95em; line-height: 1.5; color: #d4d4d4; flex-grow: 1; margin-bottom: 20px; display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden; }
    .meta { font-size: 0.8em; color: #888; margin-bottom: 15px; }
    .button-group { display: flex; gap: 10px; }
    a.button, button.button { flex: 1; text-align: center; padding: 12px; background: var(--primary); color: #ffffff; text-decoration: none; border-radius: 6px; font-weight: bold; border: none; cursor: pointer; font-size: 0.9em; transition: background 0.2s; }
    a.button:hover, button.button:hover { background: var(--primary-hover); }
    button.copy-btn { background: var(--border); }
    button.copy-btn:hover { background: #505055; }
    #noResults { display: none; text-align: center; color: var(--text-muted); padding: 50px; font-size: 1.2em; grid-column: 1 / -1; }
    #toast { visibility: hidden; min-width: 250px; background-color: var(--primary); color: #fff; text-align: center; border-radius: 8px; padding: 16px; position: fixed; z-index: 1000; left: 50%; bottom: 30px; transform: translateX(-50%); box-shadow: 0 4px 12px rgba(0,0,0,0.4); font-weight: bold; }
    #toast.show { visibility: visible; animation: fadein 0.3s, fadeout 0.4s 2.5s; }
    @keyframes fadein { from {bottom: 0; opacity: 0;} to {bottom: 30px; opacity: 1;} }
    @keyframes fadeout { from {bottom: 30px; opacity: 1;} to {bottom: 0; opacity: 0;} }
  </style>
</head>
<body>
  <header>
    <h1>AI Game Portfolio</h1>
    <p>AIと共に制作したゲーム・プロトタイプの展示室</p>
  </header>
  
  <div class="controls">
    <input type="text" id="searchInput" placeholder="🔍 タイトルや内容で検索..." onkeyup="filterGames()">
    <span id="gameCount" style="color: var(--text-muted); font-size: 0.9em; font-weight: bold;"></span>
  </div>

  <div class="container">
    <div class="grid" id="gameGrid">
      <div id="noResults">見つかりませんでした 😢</div>
HTMLEOF

  declare -A seen_titles
  GAME_LIST_TEXT=""
  GAME_COUNT=0

  while IFS= read -r file; do
    [ -e "$file" ] || continue
    local filename
    filename=$(basename "$file")
    
    local raw_title
    raw_title=$(grep -io '<title>.*</title>' "$file" | sed -e 's/<title>//i' -e 's/<\/title>//i' | head -n 1)
    local gametitle=${raw_title:-${filename%.*}}
    
    if [ -n "${seen_titles["$gametitle"]}" ]; then
      echo "  ※重複タイトルをスキップ: $filename"
      continue
    fi
    
    seen_titles["$gametitle"]=1
    GAME_LIST_TEXT+="- ${gametitle}\n"
    ((GAME_COUNT++))

    local summary
    summary=$(sed -n '/AI-DEV-HANDOFF-START/,/AI-DEV-HANDOFF-END/p' "$file" | grep -i "^概要・ルール:" | sed 's/^概要・ルール:[  ]*//' | head -n 1)
    if [ -z "$summary" ]; then
      summary="このゲームの概要はまだ記載されていません。"
    fi

    local safe_title
    safe_title=$(echo "$gametitle" | sed 's/"/\&quot;/g; s/</\&lt;/g; s/>/\&gt;/g')
    local safe_summary
    safe_summary=$(echo "$summary" | sed 's/"/\&quot;/g; s/</\&lt;/g; s/>/\&gt;/g')

    cat << HTMLEOF >> index.html
      <div class="card" data-title="${safe_title}" data-desc="${safe_summary}">
        <div>
          <h3>${safe_title}</h3>
          <span class="tag">Web Game</span>
          <div class="desc">${safe_summary}</div>
          <div class="meta">📁 ${filename}</div>
        </div>
        <div class="button-group">
          <a href="${GAMES_DIR}/${filename}" class="button" target="_blank">▶ Play</a>
          <button class="button copy-btn" onclick="copyGameCode('${filename}')">📋 Code</button>
        </div>
      </div>
HTMLEOF
  done < <(ls -t "$GAMES_DIR"/*.html 2>/dev/null)

  cat << HTMLEOF >> index.html
    </div>
  </div>

  <div id="toast">コードをコピーしました！</div>

  <script>
    document.getElementById('gameCount').textContent = "全 ${GAME_COUNT} 作品";

    function filterGames() {
      const input = document.getElementById('searchInput').value.toLowerCase();
      const cards = document.querySelectorAll('.card');
      let visibleCount = 0;

      cards.forEach(card => {
        const title = card.getAttribute('data-title').toLowerCase();
        const desc = card.getAttribute('data-desc').toLowerCase();
        
        if (title.includes(input) || desc.includes(input)) {
          card.style.display = '';
          visibleCount++;
        } else {
          card.style.display = 'none';
        }
      });

      document.getElementById('noResults').style.display = visibleCount === 0 ? 'block' : 'none';
    }

    async function copyGameCode(filename) {
      try {
        const response = await fetch('${GAMES_DIR}/' + filename);
        if (!response.ok) throw new Error('Network response error');
        const text = await response.text();
        
        await navigator.clipboard.writeText(text);
        showToast('📋 ' + filename + ' のコードをコピーしました！');
      } catch (err) {
        console.error('コピー失敗:', err);
        alert('コードの読み込みに失敗しました。');
      }
    }

    function showToast(message) {
      const toast = document.getElementById('toast');
      toast.textContent = message;
      toast.className = 'show';
      setTimeout(() => { toast.className = ''; }, 2800);
    }
  </script>
</body>
</html>
HTMLEOF
}

sync_with_git() {
  if [ ! -d ".git" ]; then
    echo "ℹ 現在のディレクトリはGitリポジトリではありません。Git連携をスキップします。"
    return
  fi

  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

    git add .
    git commit -m "🚀 ポートフォリオ更新: $(date +'%Y-%m-%d %H:%M:%S')"
    git push origin "$current_branch"
    echo "🎉 サイトの自動収集・ビルド・公開が完了しました！（計 ${GAME_COUNT} 作品）"
  else
    echo "✅ 変更がないため、Gitの更新はスキップしました。（計 ${GAME_COUNT} 作品）"
  fi
}

generate_ai_prompt() {
  local HANDOFF_RULE="・コード内に、開発引き継ぎ用の以下のコメントブロックを必ず含めてください。改良のたびに内容を最新に更新してください。
<!-- AI-DEV-HANDOFF-START
タイトル:
バージョン:
概要・ルール:
主要な構造（関数・状態管理・画面遷移）:
セーブデータのキー:
実装済み機能:
未実装・TODO:
設計上のこだわり・注意点:
AI-DEV-HANDOFF-END -->"

  echo -e "\n--------------------------------------------------"
  echo "🤖 AIへの発注プロンプトを作成します。モードを選んでください。"
  echo "  1) 🆕 新作を作る（直接コード生成）"
  echo "  2) 🔧 既存ゲームを引き継ぐ（メタデータのみ添付）"
  echo "  3) 🚀 既存ゲームを引き継ぐ（全コード添付）"
  echo "  4) 📦 共通データ(game-data.js)のみを更新する"
  echo "  5) 📝 【設計図フェーズ1】ゲームの設計図をAIに考えさせる"
  echo "  6) 🏗️ 【設計図フェーズ2】完成した設計図からゲームを実装させる"
  echo -n "👉 番号 [1]: "
  
  local mode
  read -r mode
  mode=${mode:-1}

  local COMMON_RULES="【必須条件】
・HTML/CSS/JSが1つにまとまった1ファイルの完全なコードを生成してください。
・コード内のどこかに必ず「AI-GAME-PORTFOLIO」というメタタグまたは識別コメントを含めてください。
・マスタデータ（カード、レシピ、家など）は外部URL「https://morinokum.github.io/my-website/game-data.js」から読み込み（window.RUNE_GAME_DATA を利用）、取得失敗時の簡単なフォールバックデータも備えてください。
・ローカルストレージなどによるセーブ機能も備えてください。
${HANDOFF_RULE}"

  local PROMPT=""

  if [ "$mode" = "5" ]; then
    echo -n "👉 設計図のテーマ・要素（空Enterでお任せ）: "
    local custom_request
    read -r custom_request
    
    local REQUEST_PART
    if [ -n "$custom_request" ]; then
      REQUEST_PART="次回作として「${custom_request}」という概念やテーマを組み込んだゲームを作りたいです。"
    else
      REQUEST_PART="次回作を作りたいのですが、既存の作品とは全く被らない新しいルールの「面白くてハマる単一ファイルゲーム」のアイデアを考えてください。"
    fi

    PROMPT="私はこれまでに以下のHTMLブラウザゲームを作成しました。

$(echo -e "$GAME_LIST_TEXT")

${REQUEST_PART}

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

${COMMON_RULES}"

  elif [ "$mode" = "4" ]; then
    echo -n "👉 新しいデータの世界観・テーマ（例: SF、ゾンビ、現代都市、宇宙、空Enterでお任せ）: "
    local data_theme
    read -r data_theme
    
    local THEME_REQUEST
    if [ -n "$data_theme" ]; then
      THEME_REQUEST="今回は「${data_theme}」というテーマ・世界観でデータを作成してください。"
    else
      THEME_REQUEST="今回は『紋章シリーズ』や王道ファンタジーからは完全に離れ、AI自身で「SF」「サイバーパンク」「現代劇」「妖怪」「動物」などの新しい斬新な世界観・テーマを考えてデータを作成してください。"
    fi

    local CURRENT_DATA=""
    if [ -f "./game-data.js" ]; then
      CURRENT_DATA="【現在のデータ構造の参考】
以下の構造（変数名、配列の形など）を参考にしつつ、中身のテキスト（名前、説明文、属性など）を新しいテーマに合わせて**完全に一新**してください。
\`\`\`javascript
$(cat ./game-data.js)
\`\`\`"
    else
      CURRENT_DATA="【データ構造について】
window.RUNE_GAME_DATA などのグローバル変数に、キャラクター、アイテム、マップ情報などの配列・オブジェクトを格納する形式にしてください。"
    fi

    PROMPT="現在、ゲームの共通データとして『game-data.js』を使用していますが、このデータに引っ張られて同じようなテーマ（紋章シリーズなど）のゲームばかり生成されてしまう問題が起きています。

そこで、今回はゲーム本体のコードではなく、【共通データ（game-data.js）のみ】を新しく作成してください。

${THEME_REQUEST}

【データ作成の必須条件】
1. 出力はJavaScriptのコードのみとし、単一のコードブロックで提供してください。
2. コードのどこかに必ず「AI_PORTFOLIO_DATA_FILE」という文字列をコメントで含めてください（自動収集スクリプトの目印になります）。
3. 既存のゲームとの互換性を保つため、データの階層構造（プロパティ名など）はなるべく維持しつつ、中身の世界観をガラッと変えてください。

${CURRENT_DATA}

ダウンロードしてそのまま使える形式で出力をお願いします。"

  elif [ "$mode" = "2" ] \vert{}\vert{} [ "$mode" = "3" ]; then
    local game_files=()
    while IFS= read -r f; do
      [ -n "$f" ] && game_files+=("$f")
    done < <(ls -t "$GAMES_DIR"/*.html 2>/dev/null)
    
    if [ ${#game_files[@]} -eq 0 ]; then
      echo "⚠ $GAMES_DIR フォルダにゲームがありません。"; exit 1
    fi
    
    echo -e "\n引き継ぐゲームを選んでください:"
    for i in "${!game_files[@]}"; do
      local mark="  "
      if grep -q "AI-DEV-HANDOFF-START" "${game_files[$i]}"; then mark="📝"; fi
      printf "  %2d) %s %s\n" "$((i+1))" "$mark" "$(basename "${game_files[$i]}")"
    done
    echo "  （📝 = 引き継ぎブロックあり）"
    echo -n "👉 番号: "
    
    local num
    read -r num
    
    if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -le 0 ] || [ "$num" -gt "${#game_files[@]}" ]; then
      echo "⚠ 無効な番号です。"; exit 1
    fi 

    local target="${game_files[$((num-1))]}"
    if [ -z "$target" ] \vert{}\vert{} [ ! -f "$target" ]; then
      echo "⚠ 無効な番号です。"; exit 1
    fi

    local handoff
    handoff=$(extract_handoff "$target")
    if [ -z "$handoff" ]; then
      echo "⚠ このゲームには引き継ぎブロックがありません。"
      if [ "$mode" = "2" ]; then
        echo "    全コード付き（モード3）に切り替えます。"
        mode=3
      fi
      handoff="（引き継ぎブロックなし）"
    fi

    echo -n "👉 今回の変更・追加したい内容（空Enterで『お任せ改良』）: "
    local custom_request
    read -r custom_request
    
    local REQUEST_PART
    if [ -n "$custom_request" ]; then
      REQUEST_PART="このゲームを引き継いで、「${custom_request}」を実装してください。"
    else
      REQUEST_PART="このゲームを引き継いで、面白さが増すような改良や機能追加を提案し、実装してください。"
    fi

    PROMPT="以下のHTMLブラウザゲームの開発を引き継いでください。

【ゲーム名】$(basename "$target")

【引き継ぎ情報】
${handoff}

${REQUEST_PART}
既存の仕様・セーブデータ互換を壊さないよう注意してください。
"
    if [ "$mode" = "3" ]; then
      PROMPT+="
【現在の全コード】
$(cat "$target")

"
    fi
    PROMPT+="
${COMMON_RULES}"

  else
    echo -n "👉 新作のテーマ・要素（空Enterでお任せ）: "
    local custom_request
    read -r custom_request
    
    local REQUEST_PART
    if [ -n "$custom_request" ]; then
      REQUEST_PART="次回作として「${custom_request}」という概念やテーマを組み込んだゲームを作りたいです。※既存の『紋章シリーズ』とは異なるアプローチでお願いします。"
    else
      REQUEST_PART="次回作を作りたいのですが、共通データを活かしつつも、既存作品（特に『紋章シリーズ』）とは全く被らない新しいルールの「面白くてハマる単一ファイルゲーム」のアイデアを1つ考えてください。"
    fi

    PROMPT="私はこれまでに以下のHTMLブラウザゲームを作成しました。

$(echo -e "$GAME_LIST_TEXT")
これらは私の「AI-GAME-PORTFOLIO」に収録されています。

${REQUEST_PART}

${COMMON_RULES}"
  fi

  if copy_to_clipboard "$PROMPT"; then
    echo -e "\n📋 クリップボードにAIへの指示文をコピーしました！"
    if [ "$mode" = "5" ]; then
      echo "    📝 新規チャットを開き、ペーストして設計図を作らせてください。"
    elif [ "$mode" = "6" ]; then
      echo "    🏗️ 新規チャットを開き、ペーストしてください。"
      echo "    ※ペースト後、(※ここにAIが作成した設計図のテキストをペーストしてください) の部分を上書きしてから送信してください。"
    else
      echo "    新規チャットにペーストして発注してください。"
    fi
  else
    echo -e "\n⚠ クリップボード出力ツールが見つかりませんでした。以下をコピーしてください："
    echo "--------------------------------------------------"
    printf '%s\n' "$PROMPT"
    echo "--------------------------------------------------"
  fi
}

main() {
  setup_environment
  update_game_data
  collect_html_games
  build_index_html
  sync_with_git
  generate_ai_prompt
}

main "$@"
