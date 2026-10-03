#!/bin/bash

echo "🔍 PC内からゲーム（AI-GAME-PORTFOLIO）を探索中..."

# 1. 一度 games フォルダの中をリセット（kabe.htmlを保護しつつ、または毎回集め直す）
mkdir -p games

# 2. 目印のあるファイルだけを安全に games フォルダに集める
grep -rl "AI-GAME-PORTFOLIO" ~ --include="*.html" 2>/dev/null | while read file; do
  # 自分の my-website フォルダ内にあるものはコピー元として除外（無限ループ防止）
  case "$file" in
    */my-website/*) continue ;;
  esac
  
  filename=$(basename "$file")
  echo "✨ 発見して収集: $filename"
  cp "$file" games/
done

# 3. index.html のデザイン部分を生成
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
    <p>AIと共に制作したゲーム・プロトタイプの展示室</p>
  </header>
  <div class="container">
    <div class="grid">
HTMLEOF

# 4. games フォルダ内のHTMLを自動で読み込んでカードを追加
for file in games/*.html; do
  [ -e "$file" ] || continue
  filename=$(basename "$file")
  
  # タイトルタグの抽出
  gametitle=$(grep -io '<title>.*</title>' "$file" | sed -e 's/<title>//i' -e 's/<\/title>//i' | head -n 1)
  gametitle=${gametitle:-${filename%.*}}
  
  cat << HTMLEOF >> index.html
      <div class="card">
        <h3>${gametitle}</h3>
        <span class="tag">Web Game</span>
        <p>ファイル: ${filename}</p>
        <a href="games/${filename}" class="button">Play Game</a>
      </div>
HTMLEOF
done

# 5. HTMLのフッター部分を閉じる
cat << 'HTMLEOF' >> index.html
    </div>
  </div>
</body>
</html>
HTMLEOF

# 6. Gitで自動コミット＆プッシュ
git add .
git commit -m "ゲームを自動収集してポートフォリオを更新"
git push origin main
echo "🎉 サイトの自動収集・ビルド・公開がすべて完了しました！"
