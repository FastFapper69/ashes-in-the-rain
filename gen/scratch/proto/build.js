const fs = require('fs'), path = require('path');
const src = f => fs.readFileSync(path.join(__dirname, 'src', f), 'utf8');
const font = f => fs.readFileSync(path.join(__dirname, '..', 'fonts', 'node_modules', '@fontsource', 'bangers', 'files', f)).toString('base64');
// Bangers (SIL Open Font License 1.1), embedded so the page needs no network and Czech accents always render
const fontCss = `
  @font-face { font-family: Bangers; font-weight: 400; font-display: block; src: url(data:font/woff2;base64,${font('bangers-latin-400-normal.woff2')}) format('woff2'); unicode-range: U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+2000-206F, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD; }
  @font-face { font-family: Bangers; font-weight: 400; font-display: block; src: url(data:font/woff2;base64,${font('bangers-latin-ext-400-normal.woff2')}) format('woff2'); unicode-range: U+0100-02AF, U+0304, U+0308, U+0329, U+1E00-1E9F, U+1EF2-1EFF, U+2020, U+20A0-20AB, U+20AD-20C0, U+2113, U+2C60-2C7F, U+A720-A7FF; }`;
const html = `<!DOCTYPE html>
<html lang="cs">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<title>Bullet-time prototyp (fáze 0)</title>
<style>${fontCss}
  html, body { margin: 0; height: 100%; overflow: hidden; background: #101114; overscroll-behavior: none; }
  canvas { position: fixed; left: 0; top: 0; display: block; transform-origin: 0 0; touch-action: none;
    -webkit-user-select: none; user-select: none; -webkit-touch-callout: none; -webkit-tap-highlight-color: transparent; outline: none; }
</style>
</head>
<body>
<canvas id="game"></canvas>
<script>
${src('sim.js')}
${src('assets.js')}
${src('fx_table.js')}
${src('art.js')}
${src('view.js')}
${src('input.js')}
${src('main.js')}
</script>
</body>
</html>
`;
fs.mkdirSync(path.join(__dirname, 'dist'), { recursive: true });
fs.writeFileSync(path.join(__dirname, 'dist', 'index.html'), html);
console.log('built', html.length, 'bytes');
