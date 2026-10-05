#!/bin/bash

echo "🔍 ダウンロードフォルダから新しいゲーム（AI-GAME-PORTFOLIO）を探索中..."

# 1. games フォルダを準備
mkdir -p games

# 2. ダウンロードフォルダから目印のあるファイルだけを探索
grep -rl "AI-GAME-PORTFOLIO" ~/ダウンロード --include="*.html" 2>/dev/null | while read file; do
  case "$file" in
    */my-website/*) continue ;;
  esac
  
  filename=$(basename "$file")
  
  if [ -f "games/$filename" ]; then
    continue
  fi

  echo "✨ 新しく発見して収集: $filename"
  cp "$file" games/
done

# 3. index.html のデザイン部分を生成（モーダルやコピー用トースト通知のCSSも追加）
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
    .container { max-width: 1000px; margin: 0 auto; padding: 40px 20px; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 25px; margin-top: 20px; }
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
    /* コピー完了時の通知（トースト） */
    #toast { visibility: hidden; min-width: 200px; background-color: #333; color: #fff; text-align: center; border-radius: 4px; padding: 12px; position: z-index: 1000; position: fixed; left: 50%; bottom: 30px; transform: translateX(-50%); box-shadow: 0 4px 6px rgba(0,0,0,0.3); }
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
  <div class="container">
    <div class="grid">
HTMLEOF

# 4. games フォルダ内のHTMLを自動で読み込んでカードを追加
declare -A seen_titles

while IFS= read -r file; do
  [ -e "$file" ] || continue
  filename=$(basename "$file")
  
  # タイトルタグの抽出
  gametitle=$(grep -io '<title>.*</title>' "$file" | sed -e 's/<title>//i' -e 's/<\/title>//i' | head -n 1)
  gametitle=${gametitle:-${filename%.*}}
  
  if [ -n "${seen_titles["$gametitle"]}" ]; then
    echo "  ※重複タイトルをスキップ（過去のバージョン）: $filename"
    continue
  fi
  
  seen_titles["$gametitle"]=1

  # 各ゲームファイルの実際のソースコードを読み込んで、JavaScriptの変数として安全に埋め込む
  # (改行やエスケープ文字対策としてbase64エンコードを利用すると非常に安全に渡せます)
  encoded_code=$(base64 -w 0 "$file")

  cat << HTMLEOF >> index.html
      <div class="card">
        <div>
          <h3>${gametitle}</h3>
          <span class="tag">Web Game</span>
          <p>ファイル: ${filename}</p>
        </div>
        <div class="button-group">
          <a href="games/${filename}" class="button" target="_blank">Play</a>
          <button class="button copy-btn" onclick="copyGameCode('${encoded_code}', '${filename}')">コードコピー</button>
        </div>
      </div>
HTMLEOF
done < <(ls -t games/*.html 2>/dev/null)

# 5. HTMLのフッターと、コピー機能を実現するJavaScriptを追加
cat << 'HTMLEOF' >> index.html
    </div>
  </div>

  <div id="toast">コードをクリップボードにコピーしました！</div>

  <script>
    function copyGameCode(base64Code, filename) {
      try {
        // Base64から元のHTMLコード（文字列）に復元
        const decodedHtml = decodeURIComponent(escape(window.atob(base64Code)));
        
        // クリップボードにコピー
        navigator.clipboard.writeText(decodedHtml).then(() => {
          showToast(filename + ' のコードをコピーしました！');
        }).catch(err => {
          console.error('コピーに失敗しました', err);
          alert('コピーに失敗しました。');
        });
      } catch (e) {
        console.error('デコードエラー', e);
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

# 6. Gitで自動コミット＆プッシュ
git add .
git commit -m "ゲームカードにコードコピー機能を追加"
git push origin main
echo "🎉 サイトの自動収集・コードコピー機能付きビルド・公開が完了しました！"
