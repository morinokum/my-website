#!/bin/bash

echo "🔍 ダウンロードフォルダから新しいゲーム（AI-GAME-PORTFOLIO）を探索中..."

# 1. games フォルダを準備
mkdir -p games

# 2. ダウンロードフォルダから目印のあるファイルだけを探索
grep -rl "AI-GAME-PORTFOLIO" ~/ダウンロード --include="*.html" --exclude-dir="my-website" 2>/dev/null | while read -r file; do
  filename=$(basename "$file")
  
  if [ -f "games/$filename" ]; then
    continue
  fi

  echo "✨ 新しく発見して収集: $filename"
  cp "$file" games/
done

# 3. index.html のデザイン部分を生成（検索窓とCSSを追加）
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

# 4. games フォルダ内のHTMLを読み込んでカードを追加＆AI用のリスト作成
declare -A seen_titles
game_list_text=""

# ls -t で新しい順に処理
while IFS= read -r file; do
  [ -e "$file" ] || continue
  filename=$(basename "$file")
  
  # タイトルタグの抽出
  gametitle=$(grep -io '<title>.*</title>' "$file" | sed -e 's/<title>//i' -e 's/<\/title>//i' | head -n 1)
  gametitle=${gametitle:-${filename%.*}}
  
  # 🌟 メタデータ（ゲームの説明）を抽出
  gamedesc=$(grep -io '<meta name="description" content="[^"]*"' "$file" | sed -E 's/.*<meta name="description" content="([^"]*)".*/\1/i' | head -n 1)
  
  if [ -n "${seen_titles["$gametitle"]}" ]; then
    echo "  ※重複タイトルをスキップ（過去のバージョン）: $filename"
    continue
  fi
  
  seen_titles["$gametitle"]=1
  
  # 🌟 説明文があればリストに追加、なければタイトルのみ
  if [ -n "$gamedesc" ]; then
    game_list_text+="- ${gametitle}（${gamedesc}）\n"
  else
    game_list_text+="- ${gametitle}\n"
  fi

  # HTMLへの書き出し
  cat << HTMLEOF >> index.html
      <div class="card" data-title="${gametitle}">
        <div>
          <h3>${gametitle}</h3>
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

# 5. HTMLのフッターとJSを追加
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

# 6. Gitで安全に自動コミット＆プッシュ
if [ -n "$(git status --porcelain)" ]; then
  git add .
  git commit -m "ポートフォリオ更新: $(date +'%Y-%m-%d %H:%M:%S')"
  git push origin main
  echo "🎉 サイトの自動収集・ビルド・公開が完了しました！"
else
  echo "✅ 変更がないため、Gitの更新はスキップしました。"
fi

# 7. AIへのゲーム作成指示プロンプトの生成とクリップボードコピー
echo -e "\n🤖 AIへの次回作作成プロンプトを生成中..."

PROMPT="私はこれまでに以下のHTMLブラウザゲームを作成しました。

${game_list_text}
これらは私の「AI-GAME-PORTFOLIO」に収録されています。
次回作を作りたいのですが、上記のリストと内容やジャンル、操作システムが絶対に被らない、全く新しいルールの「面白くてハマるゲーム」のアイデアを1つ考え、HTML/CSS/JSが1つにまとまった1ファイルの完全なコードを生成してください。

【条件1】コード内のどこかに必ず「AI-GAME-PORTFOLIO」という文字列を含めてください。
【条件2】次回以降の重複を防ぐため、HTMLの <head> 内に必ず以下の形式で、そのゲームのジャンルと核となるシステムを1文で記載したメタタグを含めてください。
<meta name=\"description\" content=\"ここにゲームのジャンルと特徴を簡潔に記載\">"

if command -v xclip >/dev/null 2>&1; then
  echo -e "$PROMPT" | xclip -selection clipboard
  echo "📋 クリップボードにAIへの指示文をコピーしました！"
  echo "   Geminiの入力欄で「Ctrl + V (貼り付け)」するだけで次回作を発注できます。"
else
  echo "⚠️ クリップボードに直接コピーするツール(xclip)が見つかりませんでした。"
  echo "   以下のテキストを手動でコピーしてAIに貼り付けてください："
  echo "--------------------------------------------------"
  echo -e "$PROMPT"
  echo "--------------------------------------------------"
  echo -e "💡 次回から自動でコピーされるようにするには、Linuxターミナルで以下を実行してください："
  echo -e "   sudo apt update && sudo apt install xclip\n"
fi
