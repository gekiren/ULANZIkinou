const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const logPath = path.join(__dirname, 'debug.log');

const originalLog = console.log;
const originalError = console.error;

console.log = function (...args) {
  const msg = `[LOG] ${new Date().toISOString()}: ` + args.map(a => typeof a === 'object' ? JSON.stringify(a) : a).join(' ') + '\n';
  try {
    fs.appendFileSync(logPath, msg);
  } catch (e) {}
  originalLog.apply(console, args);
};

console.error = function (...args) {
  const msg = `[ERR] ${new Date().toISOString()}: ` + args.map(a => typeof a === 'object' ? JSON.stringify(a) : a).join(' ') + '\n';
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

// PowerShell実行ラッパー
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

// エラーイベントハンドリング (未処理エラーによるクラッシュ防止)
$UD.on('error', (err) => {
  console.error("[app.js] WebSocket API Error:", err);
});

// 接続完了イベント
$UD.onConnected(() => {
  console.log("[app.js] App Restart plugin connected to Ulanzi Studio");
});

// キー追加イベント
$UD.onAdd(async (jsn) => {
  const context = jsn.context;
  console.log(`[app.js] Action added: ${context}`);

  SETTINGS_CACHE[context] = {
    isActive: true
  };
});

// キーアクティブ状態変更イベント
$UD.onSetActive(async (jsn) => {
  const context = jsn.context;
  console.log(`[app.js] Action SetActive: ${context}, active: ${jsn.active}`);
  if (SETTINGS_CACHE[context]) {
    SETTINGS_CACHE[context].isActive = jsn.active;
  }
});

// キー削除イベント
$UD.onClear((jsn) => {
  if (jsn.param) {
    jsn.param.forEach(p => {
      console.log("[app.js] Action cleared:", p.context);
      delete SETTINGS_CACHE[p.context];
    });
  }
});

// キー押下イベント (再起動処理)
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

// Ulanzi Studio 接続開始
$UD.connect('com.ulanzi.ulanzistudio.apprestart');
