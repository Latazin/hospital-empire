const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  fs.mkdirSync('shots', { recursive: true });
  const b = await chromium.launch({ args: ['--use-gl=angle', '--enable-unsafe-swiftshader', '--lang=pt-BR'] });
  const runs = [['1_titulo', ''], ['2_inicio', '?auto=1'], ['3_cheio', '?auto=1&demo=1'], ['4_sala', '?auto=1&demo=1&panel=room:laboratorio'], ['5_melhorias', '?auto=1&demo=1&panel=upgrades'], ['6_gerentes', '?auto=1&demo=1&panel=managers']];
  for (const [name, q] of runs) {
    const p = await b.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, locale: 'pt-BR' });
    const logs = []; p.on('console', m => logs.push(m.type() + ': ' + m.text())); p.on('pageerror', e => logs.push('ERR ' + e.message));
    await p.goto('http://localhost:8080/' + q);
    await p.waitForTimeout(name === '1_titulo' ? 15000 : 26000);
    await p.screenshot({ path: `shots/${name}.png` });
    fs.writeFileSync(`shots/${name}.log`, logs.join('\n'));
    await p.close();
  }
  await b.close();
})();
