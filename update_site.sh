#!/bin/bash

echo "🔍 ダウンロードフォルダから新しいゲームおよび共通データを探索中..."

# 1. games フォルダを準備
mkdir -p games

# 2. 共通データファイル（game-data.js）の探索と自動更新
data_file_found=$(grep -rl "AI_PORTFOLIO_DATA_FILE" ~/ダウンロード --include="*.js" 2>/dev/null | head -n 1)
if [ -n "$data_file_found" ]; then
  cp "$data_file_found" ./game-data.js
  echo "📦 共通データファイルを更新しました: $(basename "$data_file_found") -> ./game-data.js"
elif [ -f "$HOME/ダウンロード/game-data.js" ]; then
  cp "$HOME/ダウンロード/game-data.js" ./game-data.js
  echo "📦 共通データファイルを更新しました: game-data.js -> ./game-data.js"
fi

# 3. ダウンロードフォルダから目印のあるHTMLファイルだけを探索・収集
grep -rl "AI-GAME-PORTFOLIO" ~/ダウンロード --include="*.html" --exclude-dir="my-website" 2>/dev/null | while read -r file; do
  filename=$(basename "$file")
  
  if [ -f "games/$filename" ]; then
    continue
  fi

  echo "✨ 新しいゲームを発見して収集: $filename"
  cp "$file" games/
done

# 4. index.html のデザイン部分を生成
cat << 'HTMLEOF' > index.html
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AI Game Portfolio</title>
  <style>
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #1e1e1e; color: #f0f0f0; margin: 0; padding: 0; }
    header { text-align: center; padding: 50px 20px; background-color: #252526; border-bottom: 2px solid #007acc; }
    h1 { margin: 0; font-size: 2.5em; color: #007acc; }
    header p { color: #cccccc; margin-top: 10px; }
    .controls { max-width: 1000px; margin: 20px auto 0; padding: 0 20px; }
    #searchInput { width: 100%; max-width: 300px; padding: 10px; border-radius: 4px; border: 1px solid #3e3e42; background: #2d2d30; color: #fff; }
    .container { max-width: 1000px; margin: 0 auto; padding: 20px; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 25px; }
    .card { background: #2d2d30; border-radius: 8px; padding: 25px; box-shadow: 0 4px 6px rgba(0,0,0,0.3); transition: transform 0.2s; border: 1px solid #3e3e42; display: flex; flex-direction: column; justify-content: space-between; }
    .card:hover { transform: translateY(-5px); border-color: #007acc; }
    .card h3 { margin-top: 0; color: #ffffff; font-size: 1.4em; }
    .tag { display: inline-block; background: #007acc; color: white; padding: 3px 8px; border-radius: 12px; font-size: 0.75em; margin-bottom: 10px; }
    .card p { font-size: 0.95em; line-height: 1.6; color: #d4d4d4; }
    .button-group { display: flex; gap: 10px; margin-top: 15px; }
    a.button, button.button { flex: 1; text-align: center; padding: 10px; background: #007acc; color: #ffffff; text-decoration: none; border-radius: 4px; font-weight: bold; border: none; cursor: pointer; font-size: 0.9em; transition: background 0.2s; }
    a.button:hover, button.button:hover { background: #005999; }
    button.copy-btn { background: #3e3e42; }
    button.copy-btn:hover { background: #505055; }
    #toast { visibility: hidden; min-width: 200px; background-color: #333; color: #fff; text-align: center; border-radius: 4px; padding: 12px; position: fixed; z-index: 1000; left: 50%; bottom: 30px; transform: translateX(-50%); box-shadow: 0 4px 6px rgba(0,0,0,0.3); }
    #toast.show { visibility: visible; animation: fadein 0.5s, fadeout 0.5s 2.5s; }
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
    <input type="text" id="searchInput" placeholder="ゲームを検索..." onkeyup="filterGames()">
  </div>

  <div class="container">
    <div class="grid" id="gameGrid">
HTMLEOF

# 5. games フォルダ内のHTMLを読み込んでカードを追加＆AI用のリスト作成
declare -A seen_titles
game_list_text=""

while IFS= read -r file; do
  [ -e "$file" ] || continue
  filename=$(basename "$file")
  
  # タイトルタグの抽出
  raw_title=$(grep -io '<title>.*</title>' "$file" | sed -e 's/<title>//i' -e 's/<\/title>//i' | head -n 1)
  gametitle=${raw_title:-${filename%.*}}
  
  if [ -n "${seen_titles["$gametitle"]}" ]; then
    echo "  ※重複タイトルをスキップ: $filename"
    continue
  fi
  
  seen_titles["$gametitle"]=1
  game_list_text+="- ${gametitle}\n"

  # エスケープ処理
  safe_title=$(echo "$gametitle" | sed 's/"/\&quot;/g')

  # カード出力
  cat << HTMLEOF >> index.html
      <div class="card" data-title="${safe_title}">
        <div>
          <h3>${safe_title}</h3>
          <span class="tag">Web Game</span>
          <p>ファイル: ${filename}</p>
        </div>
        <div class="button-group">
          <a href="games/${filename}" class="button" target="_blank">Play</a>
          <button class="button copy-btn" onclick="copyGameCode('${filename}')">コードコピー</button>
        </div>
      </div>
HTMLEOF
done < <(ls -t games/*.html 2>/dev/null)

# 6. フッターとJavaScriptを追加
cat << 'HTMLEOF' >> index.html
    </div>
  </div>

  <div id="toast">コードをクリップボードにコピーしました！</div>

  <script>
    function filterGames() {
      const input = document.getElementById('searchInput').value.toLowerCase();
      const cards = document.querySelectorAll('.card');
      cards.forEach(card => {
        const title = card.getAttribute('data-title').toLowerCase();
        card.style.display = title.includes(input) ? '' : 'none';
      });
    }

    async function copyGameCode(filename) {
      try {
        const response = await fetch('games/' + filename);
        if (!response.ok) throw new Error('Network response was not ok');
        const text = await response.text();
        
        await navigator.clipboard.writeText(text);
        showToast(filename + ' のコードをコピーしました！');
      } catch (err) {
        console.error('コピーに失敗しました', err);
        alert('コードの読み込みに失敗しました。');
      }
    }

    function showToast(message) {
      const toast = document.getElementById('toast');
      toast.textContent = message;
      toast.className = 'show';
      setTimeout(() => { toast.className = ''; }, 3000);
    }
  </script>
</body>
</html>
HTMLEOF

# 7. Gitで自動コミット＆プッシュ
if [ -n "$(git status --porcelain)" ]; then
  git add .
  git commit -m "ポートフォリオ更新: $(date +'%Y-%m-%d %H:%M:%S')"
  git push origin main
  echo "🎉 サイトの自動収集・ビルド・公開が完了しました！"
else
  echo "✅ 変更がないため、Gitの更新はスキップしました。"
fi

# 8. 🌟 共通データ連携対応：AIへの発注プロンプト作成とクリップボードコピー 🌟
echo -e "\n--------------------------------------------------"
echo "🤖 次回作の注文（プロンプト）を作成します。"
echo "開発中のテーマや、新しく追加したい要素・ルールを入力してください。"
echo "（何も入力せずに Enter を押すと、共通データを活用したお任せアイデアになります）"
echo -n "👉 リクエスト入力: "
read -r custom_request

if [ -n "$custom_request" ]; then
  REQUEST_PART="次回作として「${custom_request}」という概念やテーマを組み込んだゲームを作りたいです。"
else
  REQUEST_PART="次回作を作りたいのですが、共通データを活かした、既存作品と被らない新しいルールの「面白くてハマる単一ファイルゲーム」のアイデアを1つ考えてください。"
fi

PROMPT="私はこれまでに以下のHTMLブラウザゲームを作成しました。

${game_list_text}
これらは私の「AI-GAME-PORTFOLIO」に収録されています。

${REQUEST_PART}

HTML/CSS/JSが1つにまとまった1ファイルの完全なコードを生成してください。

【必須条件】
・コード内のどこかに必ず「AI-GAME-PORTFOLIO」というメタタグまたは識別コメントを含めてください。
・マスタデータ（カード、レシピ、家など）は外部URL「https://morinokum.github.io/my-website/game-data.js」から読み込み（window.RUNE_GAME_DATA を利用）、取得失敗時の簡単なフォールバックデータも備えてください。
・ローカルストレージなどによるセーブ機能も備えてください。"

# 9. クリップボードへの転送処理
copy_to_clipboard() {
  local content="$1"
  if command -v xclip >/dev/null 2>&1; then
    echo -e "$content" | xclip -selection clipboard
    return 0
  elif command -v xsel >/dev/null 2>&1; then
    echo -e "$content" | xsel -b
    return 0
  elif command -v wl-copy >/dev/null 2>&1; then
    echo -e "$content" | wl-copy
    return 0
  fi
  return 1
}

if copy_to_clipboard "$PROMPT"; then
  echo -e "\n📋 クリップボードにAIへの指示文をコピーしました！"
  echo "    Geminiの入力欄で「Ctrl + V」すればそのまま発注できます。"
else
  echo -e "\n⚠ クリップボード出力ツールが見つかりませんでした。"
  echo "   以下のテキストをコピーして使用してください："
  echo "--------------------------------------------------"
  echo -e "$PROMPT"
  echo "--------------------------------------------------"
fi
