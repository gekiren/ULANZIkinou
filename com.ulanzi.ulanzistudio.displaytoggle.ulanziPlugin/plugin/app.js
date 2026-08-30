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

console.log("Display Toggle Plugin main service starting. argv:", process.argv);

const UlanziNodeApi = require('./libs/ulanziNodeApi.js');
const scriptPath = path.join(__dirname, 'libs', 'displayControl.ps1');
const $UD = new UlanziNodeApi();

const SETTINGS_CACHE = {};
let pollingTimer = null;

// PowerShell実行ラッパー
function runPowerShell(action) {
  return new Promise((resolve, reject) => {
    const system32 = process.env.SystemRoot ? path.join(process.env.SystemRoot, 'System32') : 'C:\\Windows\\System32';
    const powershellPath = path.join(system32, 'WindowsPowerShell', 'v1.0', 'powershell.exe');

    const command = `"${powershellPath}" -NoProfile -ExecutionPolicy Bypass -File "${scriptPath}" -Action ${action}`;
    exec(command, { encoding: 'utf8' }, (error, stdout, stderr) => {
      if (stderr && stderr.trim()) {
        console.error(`[DisplayToggle] PowerShell stderr for ${action}:`, stderr);
      }
      if (error) {
        reject(error);
      } else {
        resolve(stdout.trim());
      }
    });
  });
}

// UI更新処理
async function updateUI(context, status) {
  const config = SETTINGS_CACHE[context];
  if (!config) return;

  const isExtend = status === 'Extend';
  const relativeIconPath = isExtend ? 'assets/extend.png' : 'assets/pc_only.png';
  const iconPath = path.join(__dirname, '..', relativeIconPath).replace(/\\/g, '/');
  const labelText = isExtend ? 'Extend' : 'PC Only';

  if (config.lastStatus !== status) {
    console.log(`[DisplayToggle] Updating UI for ${context}: State=${status}`);
    config.lastStatus = status;
    $UD.setPathIcon(context, iconPath, labelText);
  }
}

// システムの状態を取得して同期
async function syncFromSystem(context) {
  const config = SETTINGS_CACHE[context];
  if (config && config.simulationMode) {
    return; // シミュレーションモード時はシステムからの同期をスキップ
  }
  try {
    const status = await runPowerShell('GetStatus');
    await updateUI(context, status);
  } catch (err) {
    console.error(`[DisplayToggle] Failed to sync display status for ${context}:`, err);
  }
}

// すべてのアクティブなキーを同期
async function syncAll() {
  const keys = Object.keys(SETTINGS_CACHE);
  for (const context of keys) {
    if (SETTINGS_CACHE[context].isActive) {
      await syncFromSystem(context);
    }
  }
}

// ポーリングの開始
function startPolling() {
  if (pollingTimer) return;
  console.log("[DisplayToggle] Starting system status polling...");
  pollingTimer = setInterval(async () => {
    await syncAll();
  }, 3000); // 3秒周期
}

// ポーリングの停止
function stopPolling() {
  if (!pollingTimer) return;
  console.log("[DisplayToggle] Stopping system status polling...");
  clearInterval(pollingTimer);
  pollingTimer = null;
}

// 接続完了イベント
$UD.onConnected(() => {
  console.log("[app.js] Display Toggle plugin connected to Ulanzi Studio");
});

// キー追加イベント
$UD.onAdd(async (jsn) => {
  const context = jsn.context;
  console.log(`[app.js] Action added: ${context}`);

  const savedSettings = jsn.param || {};
  SETTINGS_CACHE[context] = {
    isActive: true,
    lastStatus: null,
    simulationMode: savedSettings.simulationMode || false
  };

  await syncFromSystem(context);
  startPolling();
});

// キーアクティブ状態変更イベント
$UD.onSetActive(async (jsn) => {
  const context = jsn.context;
  console.log(`[app.js] Action SetActive: ${context}, active: ${jsn.active}`);
  if (SETTINGS_CACHE[context]) {
    SETTINGS_CACHE[context].isActive = jsn.active;
  }
  
  const hasActive = Object.values(SETTINGS_CACHE).some(cfg => cfg.isActive);
  if (hasActive) {
    if (jsn.active) {
      await syncFromSystem(context);
    }
    startPolling();
  } else {
    stopPolling();
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
  if (Object.keys(SETTINGS_CACHE).length === 0) {
    stopPolling();
  }
});

// キー押下イベント (トグル処理)
$UD.onRun(async (jsn) => {
  const context = jsn.context;
  console.log(`[app.js] Action run (toggle display) for context: ${context}`);
  
  const config = SETTINGS_CACHE[context];
  if (config && config.simulationMode) {
    const currentStatus = config.lastStatus || 'Internal';
    const nextStatus = currentStatus === 'Extend' ? 'Internal' : 'Extend';
    console.log(`[DisplayToggle] Simulation toggle. ${currentStatus} -> ${nextStatus}`);
    await updateUI(context, nextStatus);
  } else {
    try {
      const status = await runPowerShell('Toggle');
      console.log(`[DisplayToggle] Switch complete. New status: ${status}`);
      await updateUI(context, status);
    } catch (err) {
      console.error("[DisplayToggle] Failed to toggle display switcher:", err);
    }
  }
});

// 設定更新イベント受信時のキャッシュ更新
$UD.on('didReceiveSettings', (jsn) => {
  const context = `${jsn.uuid}___${jsn.key}___${jsn.actionid}`;
  console.log(`[app.js] didReceiveSettings for ${context}:`, jsn.settings);
  if (SETTINGS_CACHE[context]) {
    SETTINGS_CACHE[context].simulationMode = jsn.settings?.simulationMode || false;
  }
});

// Ulanzi Studio 接続開始
$UD.connect('com.ulanzi.ulanzistudio.displaytoggle');
