const fs = require('fs'), vm = require('vm');
const elements = {};
function el(id) {
  return elements[id] ??= { id, style: {}, children: [], value: 50, attrs: {},
    setAttribute(k, v) { this.attrs[k] = v; },
    appendChild(c) { this.children.push(c); }
  };
}
const ctx = { document: {
  getElementById: el,
  querySelectorAll() { return el('tabs').children; },
  createElement() { return { attrs: {}, setAttribute(k, v) { this.attrs[k] = v; } }; }
} };
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(process.argv[2], 'utf8'), ctx);
for (let i = 0; i < 9; i++) {
  vm.runInContext(`select(${i})`, ctx);
  for (const x of [0, 50, 100]) {
    el('slider').value = x;
    vm.runInContext('split()', ctx);
    if (el('line').style.left !== x + '%') throw Error('divider');
  }
  if (!el('title').textContent || !el('before').src || !el('after').src) throw Error('missing');
}
process.stdout.write('27 UI state checks passed');
