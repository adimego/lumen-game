import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const html = readFileSync(join(root, 'index.html'), 'utf8');
const start = html.indexOf('/* UGC_POLICY_START */');
const end = html.indexOf('/* UGC_POLICY_END */');
assert.ok(start > 0 && end > start, 'policy block missing');
const policy = new Function(`${html.slice(start, end)}\nreturn { lumenPublicNameSanitize, lumenBoardName, lumenLinkOk, LUMEN_BLOCK_WORDS };`)();

assert.equal(policy.lumenPublicNameSanitize('  Ada  '), 'Ada');
assert.equal(policy.lumenPublicNameSanitize('Player'), 'Player');
assert.equal(policy.lumenPublicNameSanitize('Essex'), 'Essex');
assert.equal(policy.lumenPublicNameSanitize('Assistant'), 'Assistant');
assert.equal(policy.lumenPublicNameSanitize('Classic'), 'Classic');
assert.equal(policy.lumenPublicNameSanitize(''), '');
assert.equal(policy.lumenPublicNameSanitize('ada@example.com'), '');
assert.equal(policy.lumenPublicNameSanitize('https://example.com'), '');
assert.equal(policy.lumenPublicNameSanitize('www.example.com'), '');
assert.equal(policy.lumenPublicNameSanitize('bad\u0000name'), 'badname');
assert.equal(policy.lumenPublicNameSanitize('x'.repeat(50)).length, 40);
assert.equal(policy.lumenPublicNameSanitize('oh fuck'), '');
assert.equal(policy.lumenBoardName('', ''), 'Player');
assert.equal(policy.lumenBoardName('', 'Ada'), 'Ada');
assert.equal(policy.lumenBoardName('Nova', 'Ada'), 'Nova');
assert.equal(policy.lumenBoardName('bad@mail', 'Ada'), 'Ada');
assert.equal(policy.lumenBoardName('', 'a@b.com'), 'Player');
assert.equal(policy.lumenLinkOk('https://example.com/REPLACE_ME/lumen-privacy'), false);
assert.equal(policy.lumenLinkOk('http://lumen.example/privacy'), false);
assert.equal(policy.lumenLinkOk('https://adimego.github.io/lumen-game/privacy.html'), true);
assert.match(html, /https:\/\/adimego\.github\.io\/lumen-game\/privacy\.html/);
assert.equal(html.includes('REPLACE_ME'), false);

assert.equal(html.includes("split('@')"), false);
assert.equal(html.includes('save.publicName'), false);
assert.match(html, /name:\(\)=>lumenBoardName\(lumenStoredPublicName\(\), user&&user\.displayName\)/);

const rules = readFileSync(join(root, 'firestore.rules'), 'utf8');
assert.match(rules, /hasOnly\(\['v', 'save', 'updatedAt'\]\)/);
assert.match(rules, /allow delete: if isOwner\(uid\);/);
assert.match(rules, /match \/reports\/\{id\}/);
assert.match(rules, /match \/blocks\/\{uid\}/);

const scriptStart = html.indexOf('<script>');
const scriptEnd = html.lastIndexOf('</script>');
const dir = mkdtempSync(join(tmpdir(), 'lumen-'));
const scriptPath = join(dir, 'game.js');
writeFileSync(scriptPath, html.slice(scriptStart + 8, scriptEnd));
execFileSync('node', ['--check', scriptPath], { stdio: 'inherit' });

const report = execFileSync('sh', [join(root, 'scripts/appstore-readiness-check.sh'), '--strict'], { encoding: 'utf8' });
assert.match(report, /OK:/);
assert.match(report, /MANUAL: Apple Team ID is TODO_APPLE_TEAM_ID/);
assert.doesNotMatch(report, /NOT READY/);
