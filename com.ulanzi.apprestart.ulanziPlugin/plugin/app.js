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

console.log("App Restart Plugin main service starting. argv:", process.argv);

const UlanziNodeApi = require('./libs/ulanziNodeApi.js');
const scriptPath = path.join(__dirname, 'libs', 'restart.ps1');
const $UD = new UlanziNodeApi();

const SETTINGS_CACHE = {};

// PowerShell螳溯｡後Λ繝・ヱ繝ｼ
function runPowerShell() {
  return new Promise((resolve, reject) => {
    const system32 = process.env.SystemRoot ? path.join(process.env.SystemRoot, 'System32') : 'C:\\Windows\\System32';
    const powershellPath = path.join(system32, 'WindowsPowerShell', 'v1.0', 'powershell.exe');

    const command = `"${powershellPath}" -NoProfile -ExecutionPolicy Bypass -File "${scriptPath}"`;
    console.log(`[AppRestart] Executing: ${command}`);
    exec(command, { encoding: 'utf8' }, (error, stdout, stderr) => {
      if (stderr && stderr.trim()) {
        console.error(`[AppRestart] PowerShell stderr:`, stderr);
      }
      if (error) {
        reject(error);
      } else {
        resolve(stdout.trim());
      }
    });
  });
}

// 繧ｨ繝ｩ繝ｼ繧､繝吶Φ繝医ワ繝ｳ繝峨Μ繝ｳ繧ｰ (譛ｪ蜃ｦ逅・お繝ｩ繝ｼ縺ｫ繧医ｋ繧ｯ繝ｩ繝・す繝･髦ｲ豁｢)
$UD.on('error', (err) => {
  console.error("[app.js] WebSocket API Error:", err);
});

// 謗･邯壼ｮ御ｺ・う繝吶Φ繝・
$UD.onConnected(() => {
  console.log("[app.js] App Restart plugin connected to Ulanzi Studio");
});

// 繧ｭ繝ｼ霑ｽ蜉繧､繝吶Φ繝・
$UD.onAdd(async (jsn) => {
  const context = jsn.context;
  console.log(`[app.js] Action added: ${context}`);

  SETTINGS_CACHE[context] = {
    isActive: true
  };
});

// 繧ｭ繝ｼ繧｢繧ｯ繝・ぅ繝也憾諷句､画峩繧､繝吶Φ繝・
$UD.onSetActive(async (jsn) => {
  const context = jsn.context;
  console.log(`[app.js] Action SetActive: ${context}, active: ${jsn.active}`);
  if (SETTINGS_CACHE[context]) {
    SETTINGS_CACHE[context].isActive = jsn.active;
  }
});

// 繧ｭ繝ｼ蜑企勁繧､繝吶Φ繝・
$UD.onClear((jsn) => {
  if (jsn.param) {
    jsn.param.forEach(p => {
      console.log("[app.js] Action cleared:", p.context);
      delete SETTINGS_CACHE[p.context];
    });
  }
});

// 繧ｭ繝ｼ謚ｼ荳九う繝吶Φ繝・(蜀崎ｵｷ蜍募・逅・
$UD.onRun(async (jsn) => {
  const context = jsn.context;
  console.log(`[app.js] Action run (restart application) for context: ${context}`);
  
  try {
    await runPowerShell();
    console.log("[AppRestart] Restart triggered successfully.");
  } catch (err) {
    console.error("[AppRestart] Failed to trigger restart:", err);
  }
});

// Ulanzi Studio 謗･邯夐幕蟋・
$UD.connect('com.ulanzi.apprestart');

