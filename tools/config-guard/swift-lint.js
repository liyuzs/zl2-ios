// 逐字符扫描 Swift 文件，跳过字符串、注释、字符字面量，统计真实括号深度
const fs = require('fs');
const path = require('path');

const dir = 'D:\\ios-zl2\\src';

function scan(file) {
  const src = fs.readFileSync(file, 'utf8');
  let i = 0;
  const n = src.length;
  let brace = 0, paren = 0, bracket = 0;
  let minBrace = 0, minParen = 0;
  let line = 1;
  let issues = [];
  let inLineComment = false;
  let blockCommentDepth = 0;
  let inString = false;
  let stringKind = ''; // '"' or '"""'
  let inChar = false;

  while (i < n) {
    const c = src[i];
    const c2 = src.substr(i, 2);
    const c3 = src.substr(i, 3);

    if (c === '\n') { line++; inLineComment = false; i++; continue; }

    if (inLineComment) { i++; continue; }

    if (blockCommentDepth > 0) {
      if (c2 === '/*') { blockCommentDepth++; i += 2; continue; }
      if (c2 === '*/') { blockCommentDepth--; i += 2; continue; }
      i++; continue;
    }

    if (inString) {
      if (stringKind === '"""') {
        if (c3 === '"""') { inString = false; i += 3; continue; }
        if (c === '\\') { i += 2; continue; }
        i++; continue;
      } else {
        if (c === '\\') { i += 2; continue; }
        if (c === '"') { inString = false; i++; continue; }
        if (c === '\n') { inString = false; i++; continue; } // 未闭合，容错
        i++; continue;
      }
    }

    if (inChar) {
      if (c === '\\') { i += 2; continue; }
      if (c === "'") { inChar = false; i++; continue; }
      i++; continue;
    }

    if (c2 === '//') { inLineComment = true; i += 2; continue; }
    if (c2 === '/*') { blockCommentDepth = 1; i += 2; continue; }
    if (c3 === '"""') { inString = true; stringKind = '"""'; i += 3; continue; }
    if (c === '"') {
      // 判断是不是字符字面量 '"'
      inString = true; stringKind = '"'; i++; continue;
    }

    if (c === '{') { brace++; }
    else if (c === '}') { brace--; if (brace < minBrace) minBrace = brace; }
    else if (c === '(') { paren++; }
    else if (c === ')') { paren--; if (paren < minParen) minParen = paren; }

    i++;
  }

  return { brace, paren, minBrace, minParen, line };
}

const files = fs.readdirSync(dir).filter(f => f.endsWith('.swift'));
let bad = 0;
for (const f of files) {
  const r = scan(path.join(dir, f));
  if (r.brace !== 0 || r.paren !== 0 || r.minBrace < 0 || r.minParen < 0) {
    console.log(`BAD  ${f}  brace=${r.brace} paren=${r.paren} minBrace=${r.minBrace} minParen=${r.minParen}`);
    bad++;
  }
}
console.log(bad === 0 ? `全部 ${files.length} 个文件语法括号配对正确` : `共 ${bad} 个文件有问题`);
