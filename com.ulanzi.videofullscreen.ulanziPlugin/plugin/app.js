const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const logPath = path.join(__dirname, 'debug.log');

function rotateLogIfNeeded() {
  try {
    if (fs.existsSync(logPath)) {
      const stats = fs.statSync(logPath);
      if (stats.size > 1024 * 1024) { // 1MB limit
        fs.writeFileSync(logPath, ''); // Clear file
      }
    }
  } catch (e) {}
}

const originalLog = console.log;
const originalError = console.error;

console.log = function (...args) {
  rotateLogIfNeeded();
  const msg = [LOG]  + new Date().toISOString() + :  + args.map(a => typeof a === 'object' ? JSON.stringify(a) : a).join(' ') + '\n';
  try {
    fs.appendFileSync(logPath, msg);
  } catch (e) {}
  originalLog.apply(console, args);
};

console.error = function (...args) {
  rotateLogIfNeeded();
  const msg = [ERR]  + new Date().toISOString() + :  + args.map(a => typeof a === 'object' ? JSON.stringify(a) : a).join(' ') + '\n';
  try {
    fs.appendFileSync(logPath, msg);
  } catch (e) {}
  originalError.apply(console, args);
};

process.on('uncaughtException', (err) => {
  console.error('Uncaught Exception:', err);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

console.log("Video Fullscreen Plugin main service starting. argv:", process.argv);

const UlanziNodeApi = require('./libs/ulanziNodeApi.js');
const scriptPath = path.join(__dirname, 'libs', 'fullscreen.ps1');
const $UD = new UlanziNodeApi();

const SETTINGS_CACHE = {};

function runPowerShellFullscreen() {
  return new Promise((resolve, reject) => {
    const system32 = process.env.SystemRoot ? path.join(process.env.SystemRoot, 'System32') : 'C:\\Windows\\System32';
    const powershellPath = path.join(system32, 'WindowsPowerShell', 'v1.0', 'powershell.exe');

    const command = `"${powershellPath}" -NoProfile -ExecutionPolicy Bypass -File "${scriptPath}"`;
    console.log(`[VideoFullscreen] Executing: ${command}`);
    exec(command, { encoding: 'utf8' }, (error, stdout, stderr) => {
      if (stderr && stderr.trim()) {
        console.error(`[VideoFullscreen] PowerShell stderr:`, stderr);
      }
      if (error) {
        reject(error);
      } else {
        resolve(stdout.trim());
      }
    });
  });
}

$UD.on('error', (err) => {
  console.error("[app.js] WebSocket API Error:", err);
});

$UD.onConnected(() => {
  console.log("[app.js] Video Fullscreen plugin connected to Ulanzi Studio");
});

$UD.onAdd(async (jsn) => {
  const context = jsn.context;
  console.log(`[app.js] Action added: ${context}`);
  SETTINGS_CACHE[context] = { isActive: true };
});

$UD.onSetActive(async (jsn) => {
  const context = jsn.context;
  if (SETTINGS_CACHE[context]) {
    SETTINGS_CACHE[context].isActive = jsn.active;
  }
});

$UD.onClear((jsn) => {
  if (jsn.param) {
    jsn.param.forEach(p => {
      delete SETTINGS_CACHE[p.context];
    });
  }
});

$UD.onRun(async (jsn) => {
  const context = jsn.context;
  console.log(`[app.js] Action run (Video Fullscreen) for context: ${context}`);
  
  try {
    const result = await runPowerShellFullscreen();
    console.log("[VideoFullscreen] Fullscreen triggered successfully. Output:", result);
  } catch (err) {
    console.error("[VideoFullscreen] Failed to trigger fullscreen:", err);
  }
});

$UD.connect('com.ulanzi.videofullscreen');

