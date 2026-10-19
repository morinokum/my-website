#!/bin/bash
# ==============================================================================
# AI Game Portfolio - Termux / Linux 向け全自動収集・ビルド・発注スクリプト
# ==============================================================================

# ダウンロードフォルダの自動検出（Termuxストレージ優先）
DOWNLOAD_DIR="$HOME/Downloads"
if [ -d "$HOME/downloads" ]; then
  DOWNLOAD_DIR="$HOME/downloads"
elif [ -d "/sdcard/Download" ]; then
  DOWNLOAD_DIR="/sdcard/Download"
elif [ -d "$HOME/ダウンロード" ]; then
  DOWNLOAD_DIR="$HOME/ダウンロード"
fi

echo "🔍 [$DOWNLOAD_DIR] から新しいゲームおよび共通データを探索中..."

mkdir -p games

# ------------------------------------------------------------------------------
# 1. 共通データファイル（game-data.js）の探索と自動更新
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# 2. 目印のあるHTMLファイルだけを探索・収集
# ------------------------------------------------------------------------------
find "$DOWNLOAD_DIR" -maxdepth 1 -name "*.html" -type f -exec grep -l "AI-GAME-PORTFOLIO" {} + 2>/dev/null | while read -r file; do
  filename=$(basename "$file")

  if [ -f "games/$filename" ]; then
    continue
  fi

  echo "✨ 新しいゲームを発見して収集: $filename"
  cp "$file" games/
done

# ------------------------------------------------------------------------------
# 3. index.html の生成（ヘッダー・CSS）
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# 4. games フォルダ内のHTMLを解析しカードを追加
# ------------------------------------------------------------------------------
declare -A seen_titles
game_list_text=""
game_count=0

while IFS= read -r file; do
  [ -e "$file" ] || continue
  filename=$(basename "$file")

  raw_title=$(grep -io '<title>.*</title>' "$file" | sed -e 's/<title>//i' -e 's/<\/title>//i' | head -n 1)
  gametitle=${raw_title:-${filename%.*}}

  if [ -n "${seen_titles["$gametitle"]}" ]; then
    echo "  ※重複タイトルをスキップ: $filename"
    continue
  fi

  seen_titles["$gametitle"]=1
  game_list_text+="- ${gametitle}\n"
  ((game_count++))

  summary=$(sed -n '/AI-DEV-HANDOFF-START/,/AI-DEV-HANDOFF-END/p' "$file" | grep -i "^概要・ルール:" | sed 's/^概要・ルール:[  ]*//' | head -n 1)
  if [ -z "$summary" ]; then
    summary="このゲームの概要はまだ記載されていません。"
  fi

  safe_title=$(echo "$gametitle" | sed 's/"/\&quot;/g; s/</\&lt;/g; s/>/\&gt;/g')
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
          <a href="games/${filename}" class="button" target="_blank">▶ Play</a>
          <button class="button copy-btn" onclick="copyGameCode('${filename}')">📋 Code</button>
        </div>
      </div>
HTMLEOF
done < <(ls -t games/*.html 2>/dev/null)

# ------------------------------------------------------------------------------
# 5. フッターとJavaScriptを追加
# ------------------------------------------------------------------------------
cat << HTMLEOF >> index.html
    </div>
  </div>

  <div id="toast">コードをコピーしました！</div>

  <script>
    document.getElementById('gameCount').textContent = "全 ${game_count} 作品";

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
        const response = await fetch('games/' + filename);
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

# ------------------------------------------------------------------------------
# 6. Git自動コミット＆プッシュ
# ------------------------------------------------------------------------------
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  git add .
  git commit -m "🚀 ポートフォリオ更新: $(date +'%Y-%m-%d %H:%M:%S')"
  git push origin main
  echo "🎉 サイトの自動収集・ビルド・公開が完了しました！（計 ${game_count} 作品）"
else
  echo "✅ 変更がないため、Gitの更新はスキップしました。（計 ${game_count} 作品）"
fi

# ------------------------------------------------------------------------------
# 7. AIプロンプト作成（クリップボード用）
# ------------------------------------------------------------------------------
HANDOFF_RULE="・コード内に、開発引き継ぎ用の以下のコメントブロックを必ず含めてください。改良のたびに内容を最新に更新してください。
<!-- AI-DEV-HANDOFF-START
DOFF-END -->"

extract_handoff() {
  sed -n '/AI-DEV-HANDOFF-START/,/AI-DEV-HANDOFF-END/p' "$1"
}

echo -e "\n--------------------------------------------------"
echo "🤖 AIへの発注プロンプトを作成します。モードを選んでください。"
echo "  1) 🆕 新作を作る"
echo "  2) 🔧 既存ゲームを引き継ぐ（メタデータのみ添付・トークン節約）"
echo "  3) 🚀 既存ゲームを引き継ぐ（全コード添付・確実な改良）"
echo "  4) 📦 共通データ(game-data.js)のみを新しく作る・更新する"
echo -n "👉 番号 [1]: "
read -r mode
mode=${mode:-1}

COMMON_RULES="【必須条件】
HTML/CSS/JSが1つにまとまった1ファイルの完全なコードを生成してください。
  <title>ミニマム文字RPG：ストーリー討伐</title>AI-GAME-PORTFOLIO」というメタタグまたは識別コメントを含めてください。
  <ミニマム文字/Title>>title okum.github.io/my-website/game-data.js」から読み込み（window.RUNE_GAME_DATA を利用）、取得失敗時の簡単なフォールバックデータも備えてください。
  <title>ミニマム文字RPG：ストーリー討伐</bin /bin.usr-is-merged /boot /dev /etc /home /lib /lib.usr-is-merged /lib64 /lost+found /media /mnt /opt /proc /root /run /sbin /sbin.usr-is-merged /snap /srv /swapfile /swapfile_extra / /Tmp //Var 
${HANDOFF_RULE}"

if [ "$mode" = "4" ]; then
  echo -n "👉 新しいデータの世界観・テーマ（例: SF、現代都市、妖怪、空Enterでお任せ）: "
  read -r data_theme
  if [ -n "$data_theme" ]; then
    THEME_REQUEST="今回は「${data_theme}」というテーマ・世界観でデータを作成してください。"
  else
    THEME_REQUEST="今回は『紋章シリーズ』や王道ファンタジーからは完全に離れ、AI自身で「SF」「サイバーパンク」「現代劇」「妖怪」「動物」などの新しい斬新な世界観・テーマを考えてデータを作成してください。"
  fi

  CURRENT_DATA=""
  if [ -f "./game-data.js" ]; then
    CURRENT_DATA="【現在のデータ構造の参考】
else
    CURRENT_DATA="【データ構造について】
window.RUNE_GAME_DATA などのグローバル変数に、キャラクター、アイテム、マップ情報などの配列・オブジェクトを格納する形式にしてください。"
  fi

  PROMPT="現在、ゲームの共通データとして『game-data.js』を使用していますが、このデータに引っ張られて同じようなテーマのゲームばかり生成されてしまう問題が起きています。

  <title>ミニマム文字RPG：ストーリー討伐</Title>.git Zero_Echoes_of_Golden_Ratio.mp3 game-data.js games gemini-code-1792274904676.html index.html index_backup.html neon_prism_draw_defend.html prompt_history rune_craft_puzzle (1).html update_portfolio.sh update_site.sh update_site.sh.bak update_site_ext.log update_site_ext.sh update_wrapper.game-data.js）のみ】を新しく作成してください。update_wrapper.sh 

${THEME_REQUEST}

  <
1. 出力はJavaScriptのコードのみとし、単一のコードブロックで提供してください。
2. コードのどこかに必ず「AI_PORTFOLIO_DATA_FILE」という文字列をコメントで含めてください。
3. 既存のゲームとの互換性を保つため、データの階層構造（プロパティ名など）はなるべく維持しつつ、中身の世界観をガラッと変えてください。

${CURRENT_DATA}

  <title>ミニマム文字RPG：ストーリー討伐</title>
  mapfile -t game_files < <(ls -t games/*.html 2>/dev/null)
  if [ ${#game_files[@]} -eq 0 ]; then
    echo "⚠ games フォルダにゲームがありません。"; exit 1
  fi
  echo -e "\n引き継ぐゲームを選んでください:"
  for i in "${!game_files[@]}"; do
    if grep -q "AI-DEV-HANDOFF-START" "${game_files[$i]}"; then mark="📝"; else mark="  "; fi
    printf "  %2d) %s %s\n" "$((i+1))" "$mark" "$(basename "${game_files[$i]}")"
  done
  echo "  （📝 = 引き継ぎブロックあり）"
  echo -n "👉 番号: "
  read -r num
  target="${game_files[$((num-1))]}"
  if [ -z "$target" ] \vert{}\vert{} [ ! -f "$target" ]; then
    echo "⚠ 無効な番号です。"; exit 1
  fi

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
  read -r custom_request
  if [ -n "$custom_request" ]; then
    REQUEST_PART="このゲームを引き継いで、「${custom_request}」を実装してください。"
  else
    REQUEST_PART="このゲームを引き継いで、面白さが増すような改良や機能追加を提案し、実装してください。"
  fi

  PROMPT="以下のHTMLブラウザゲームの開発を引き継いでください。

  <title>ミニマム文字RPG：ストーリー討伐</title>$(basename "$target")

  <title>ミニマム文字RPG：ストーリー討伐</title>
${handoff}

${REQUEST_PART}
#  <title>ミニマム文字RPG：ストーリー討伐</title>
.git Zero_Echoes_of_Golden_Ratio.mp3 game-data.js games gemini-code-1792274904676.html index.html index_backup.html neon_prism_draw_defend.html prompt_history rune_craft_puzzle\ \(1\).html update_portfolio.sh update_site.sh update_site.sh.bak update_site_ext.log update_site_ext.sh update_wrapper.Update_wrapper.sh 
"
  if [ "$mode" = "3" ]; then
    PROMPT+="
  <title>ミニマム文字RPG：ストーリー討伐</title>
\`\`\`html
$(cat "$target")
\`\`\`
"
  fi
  PROMPT+="
${COMMON_RULES}"

else
  # モード1：新作
  echo -n "👉 新作のテーマ・要素（空Enterでお任せ）: "
  read -r custom_request
  if [ -n "$custom_request" ]; then
    REQUEST_PART="次回作として「${custom_request}」という概念やテーマを組み込んだゲームを作りたいです。※既存の『紋章シリーズ』とは異なるアプローチでお願いします。"
  else
    REQUEST_PART="次回作を作りたいのですが、共通データを活かしつつも、既存作品（特に『紋章シリーズ』）とは全く被らない新しいルールの「面白くてハマる単一ファイルゲーム」のアイデアを1つ考えてください。"
  fi

  PROMPT="私はこれまでに以下のHTMLブラウザゲームを作成しました。

$(echo -e "$game_list_text")
create_site.shAI-GAME-PORTFOLIO」に収録されています。

${REQUEST_PART}

${COMMON_RULES}"
fi

# ------------------------------------------------------------------------------
# 8. クリップボードへの転送処理 (Termux対応拡張)
# ------------------------------------------------------------------------------
copy_to_clipboard() {
  local content="$1"
  if command -v termux-clipboard-set >/dev/null 2>&1; then
    printf '%s' "$content" | termux-clipboard-set; return 0 # Termux
  elif command -v pbcopy >/dev/null 2>&1; then
    printf '%s' "$content" | pbcopy; return 0                # Mac
  elif command -v clip.exe >/dev/null 2>&1; then
    printf '%s' "$content" | clip.exe; return 0              # Windows(WSL)
  elif command -v xclip >/dev/null 2>&1; then
    printf '%s' "$content" | xclip -selection clipboard; return 0 # Linux X11
  elif command -v xsel >/dev/null 2>&1; then
    printf '%s' "$content" | xsel -b; return 0               # Linux X11
  elif command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$content" | wl-copy; return 0               # Linux Wayland
  fi
  return 1
}

if copy_to_clipboard "$PROMPT"; then
  echo -e "\n📋 クリップボードにAIへの指示文をコピーしました！"
  echo "    新規チャットにペーストして発注してください。"
else
  echo -e "\n⚠ クリップボード出力ツールが見つかりませんでした。以下をコピーしてください："
  echo "--------------------------------------------------"
  printf '%s\n' "$PROMPT"
  echo "--------------------------------------------------"
fi
