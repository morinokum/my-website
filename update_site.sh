#!/bin/bash

# 1. ゲームを入れるためのフォルダを作成
mkdir -p games

# 2. index.html の「上半分（デザイン部分）」を作成
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
    .card { background: #2d2d30; border-radius: 8px; padding: 25px; box-shadow: 0 4px 6px rgba(0,0,0,0.3); transition: transform 0.2s; border: 1px solid #3e3e42; }
    .card:hover { transform: translateY(-5px); border-color: #007acc; }
    .card h3 { margin-top: 0; color: #ffffff; font-size: 1.4em; }
    .tag { display: inline-block; background: #007acc; color: white; padding: 3px 8px; border-radius: 12px; font-size: 0.75em; margin-bottom: 10px; }
    .card p { font-size: 0.95em; line-height: 1.6; color: #d4d4d4; }
    a.button { display: inline-block; margin-top: 15px; padding: 10px 20px; background: #007acc; color: #ffffff; text-decoration: none; border-radius: 4px; font-weight: bold; }
    a.button:hover { background: #005999; }
  </style>
</head>
<body>
  <header>
    <h1>AI Game Portfolio</h1>
    <p>gamesフォルダから自動生成されたギャラリー</p>
  </header>
  <div class="container">
    <div class="grid">
HTMLEOF

# 3. gamesフォルダの中にあるHTMLを探して、自動でカード（枠）を追加する
for file in games/*.html; do
  [ -e "$file" ] || continue
  filename=$(basename "$file")
  
  # HTMLの中から <title> タグを抽出（なければファイル名をタイトルにする）
  gametitle=$(grep -io '<title>.*</title>' "$file" | sed -e 's/<title>//i' -e 's/<\/title>//i' | head -n 1)
  gametitle=${gametitle:-${filename%.*}}
  
  cat << HTMLEOF >> index.html
      <div class="card">
        <h3>${gametitle}</h3>
        <span class="tag">Web Game</span>
        <p>ファイル名: ${filename}</p>
        <a href="games/${filename}" class="button">Play Game</a>
      </div>
HTMLEOF
done

# 4. index.html の「下半分」を閉じる
cat << 'HTMLEOF' >> index.html
    </div>
  </div>
</body>
</html>
HTMLEOF

# 5. GitHubへ自動送信
git add .
git commit -m "フォルダの内容からポートフォリオを自動更新"
git push origin main
echo "✨ サイトの自動更新と公開が完了しました！"
