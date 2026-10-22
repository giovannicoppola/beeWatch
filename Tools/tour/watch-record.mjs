// Films the Apple Watch tour: builds the beeWatch watch app (Debug, where its sample goals live),
// installs it fresh on the Watch simulator, then records the screen while watch-runner drives it.
// Writes film.mp4, screen.mp4 (retimed, 700x858) and events.json.
// Usage: node watch-record.mjs <watch simulator udid> <out dir>
// Pair that Watch with an iPhone simulator first, or it shows a red "iPhone disconnected" glyph.
import { execFileSync, spawn } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const [SIM, OUT] = process.argv.slice(2);
if (!SIM || !OUT) throw new Error('Usage: node watch-record.mjs <watch simulator udid> <out dir>');
const HERE = fileURLToPath(new URL('.', import.meta.url));
const REPO = fileURLToPath(new URL('../../', import.meta.url));
const BUNDLE = 'com.beewatch.ios.watchkitapp';
const run = (cmd, args, opts = {}) => execFileSync(cmd, args, { stdio: ['ignore', 'ignore', 'inherit'], ...opts });
mkdirSync(OUT, { recursive: true });

const derived = join(OUT, 'derived');
run('xcodebuild', ['-project', `${REPO}beeWatch.xcodeproj`, '-scheme', 'beeWatch Watch App', '-configuration', 'Debug',
  '-destination', `id=${SIM}`, '-derivedDataPath', derived, 'build']);
run('xcrun', ['simctl', 'bootstatus', SIM, '-b']);
run('xcrun', ['simctl', 'uninstall', SIM, BUNDLE]);
run('xcrun', ['simctl', 'install', SIM, join(derived, 'Build/Products/Debug-watchsimulator/beeWatch Watch App.app')]);

const runner = ['-project', join(HERE, 'watch-runner/BeeWatchWatchTour.xcodeproj'), '-scheme', 'WatchTourTests', '-destination', `id=${SIM}`, '-derivedDataPath', join(OUT, 'runner')];
run('xcodegen', ['generate', '--spec', join(HERE, 'watch-runner/project.yml'), '--project', join(HERE, 'watch-runner')]);
run('xcodebuild', ['build-for-testing', ...runner]);

const film = join(OUT, 'film.mp4');
const recorder = spawn('xcrun', ['simctl', 'io', SIM, 'recordVideo', '--codec=h264', '--force', film]);
const t0 = await new Promise((resolve, reject) => {
  recorder.stderr.on('data', (d) => String(d).includes('Recording started') && resolve(Date.now() / 1000));
  recorder.on('exit', (code) => reject(new Error(`recordVideo exited ${code}`)));
});

const events = [];
const test = spawn('xcodebuild', ['test-without-building', ...runner]);
let buffer = '';
test.stdout.on('data', (d) => {
  buffer += d;
  const lines = buffer.split('\n');
  buffer = lines.pop();
  for (const line of lines) {
    const at = line.indexOf('TOUR ');
    if (at >= 0) {
      const event = JSON.parse(line.slice(at + 5));
      events.push(event);
    }
    if (/error:|failed|Test Case .* passed/.test(line)) console.log(line.trim());
  }
});
const code = await new Promise((resolve) => test.on('exit', resolve));
recorder.kill('SIGINT');
await new Promise((resolve) => recorder.on('exit', resolve));
writeFileSync(join(OUT, 'events.json'), JSON.stringify(events.map((e) => ({ ...e, t: e.t - t0 })), null, 1));
if (code !== 0) throw new Error(`the tour failed (xcodebuild exited ${code}); events.json shows how far it got`);
execFileSync('python3', [join(HERE, 'retime.py'), OUT, '700', '858'], { stdio: 'inherit' });
console.log(`${events.length} events, film in ${film}`);
