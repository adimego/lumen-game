import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

function inline(text) {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>')
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
}

function markdownToHtml(markdown) {
  const lines = markdown.replace(/\r\n/g, '\n').split('\n');
  const out = [];
  let list = false;
  const closeList = () => {
    if (list) {
      out.push('</ul>');
      list = false;
    }
  };
  for (const line of lines) {
    if (!line.trim()) {
      closeList();
      continue;
    }
    if (line.startsWith('# ')) {
      closeList();
      out.push(`<h1>${inline(line.slice(2))}</h1>`);
      continue;
    }
    if (line.startsWith('## ')) {
      closeList();
      out.push(`<h2>${inline(line.slice(3))}</h2>`);
      continue;
    }
    if (line.startsWith('- ')) {
      if (!list) {
        out.push('<ul>');
        list = true;
      }
      out.push(`<li>${inline(line.slice(2))}</li>`);
      continue;
    }
    closeList();
    out.push(`<p>${inline(line)}</p>`);
  }
  closeList();
  return out.join('\n');
}

function page({ title, body }) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="theme-color" content="#03040b">
<meta name="description" content="${title} for LUMEN: Orbital Conquest">
<title>${title} · LUMEN: Orbital Conquest</title>
<style>
:root{--sat:env(safe-area-inset-top,0px);--sab:env(safe-area-inset-bottom,0px);--sal:env(safe-area-inset-left,0px);--sar:env(safe-area-inset-right,0px)}
*{box-sizing:border-box}
html,body{margin:0;background:#03040b;color:#e6f6ff;font:17px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,Helvetica,Arial,sans-serif}
main{max-width:40rem;margin:0 auto;padding:calc(var(--sat) + 28px) calc(var(--sar) + 20px) calc(var(--sab) + 40px) calc(var(--sal) + 20px)}
a{color:#9fe9ff}
h1{font-weight:200;letter-spacing:.08em;font-size:1.7rem;margin:0 0 1rem}
h2{font-weight:600;font-size:1.05rem;letter-spacing:.04em;margin:1.6rem 0 .4rem;color:#dff6ff}
p,li{margin:.45rem 0}
ul{padding-left:1.2rem}
code{font-size:.92em;color:#bff4ff}
nav{display:flex;flex-wrap:wrap;gap:12px 16px;margin:1.5rem 0;font-size:.95rem}
.back{letter-spacing:.14em;text-transform:uppercase;font-size:.78rem}
</style>
</head>
<body>
<main>
<p class="back"><a href="./">LUMEN</a></p>
${body}
<nav>
<a href="privacy.html">Privacy</a>
<a href="terms.html">Terms</a>
<a href="support.html">Support</a>
</nav>
<p>Copyright 2026 Adam Lyons.</p>
</main>
</body>
</html>
`;
}

const pages = [
  ['privacy.html', 'Privacy policy', 'docs/legal/privacy-policy-draft.md'],
  ['terms.html', 'Terms of use', 'docs/legal/terms-of-use-draft.md'],
  ['support.html', 'Support', 'docs/legal/support.md'],
];

for (const [file, title, source] of pages) {
  const markdown = readFileSync(join(root, source), 'utf8');
  writeFileSync(join(root, file), page({ title, body: markdownToHtml(markdown) }));
  console.log('wrote', file);
}
