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

console.log("Display Toggle Plugin main service starting. argv:", process.argv);

const UlanziNodeApi = require('./libs/ulanziNodeApi.js');
const scriptPath = path.join(__dirname, 'libs', 'displayControl.ps1');
const $UD = new UlanziNodeApi();

const SETTINGS_CACHE = {};
let pollingTimer = null;

// PowerShell螳溯｡後Λ繝・ヱ繝ｼ
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

// UI譖ｴ譁ｰ蜃ｦ逅・
async function updateUI(context, status) {
  const config = SETTINGS_CACHE[context];
  if (!config) return;

  const isExtend = status === 'Extend';
  const iconRelPath = isExtend ? 'assets/extend.png' : 'assets/pc_only.png';
  const labelText = isExtend ? 'Extend' : 'PC Only';

  if (config.lastStatus !== status) {
    console.log(`[DisplayToggle] Updating UI for ${context}: State=${status}`);
    config.lastStatus = status;
    $UD.setPathIcon(context, iconRelPath, labelText);
  }
}

// 繧ｷ繧ｹ繝・Β縺ｮ迥ｶ諷九ｒ蜿門ｾ励＠縺ｦ蜷梧悄
async function syncFromSystem(context) {
  const config = SETTINGS_CACHE[context];
  if (config && config.simulationMode) {
    return; // 繧ｷ繝溘Η繝ｬ繝ｼ繧ｷ繝ｧ繝ｳ繝｢繝ｼ繝画凾縺ｯ繧ｷ繧ｹ繝・Β縺九ｉ縺ｮ蜷梧悄繧偵せ繧ｭ繝・・
  }
  try {
    const status = await runPowerShell('GetStatus');
    await updateUI(context, status);
  } catch (err) {
    console.error(`[DisplayToggle] Failed to sync display status for ${context}:`, err);
  }
}

// 縺吶∋縺ｦ縺ｮ繧｢繧ｯ繝・ぅ繝悶↑繧ｭ繝ｼ繧貞酔譛・
async function syncAll() {
  const keys = Object.keys(SETTINGS_CACHE);
  for (const context of keys) {
    if (SETTINGS_CACHE[context].isActive) {
      await syncFromSystem(context);
    }
  }
}

// 繝昴・繝ｪ繝ｳ繧ｰ縺ｮ髢句ｧ・
function startPolling() {
  if (pollingTimer) return;
  console.log("[DisplayToggle] Starting system status polling...");
  pollingTimer = setInterval(async () => {
    await syncAll();
  }, 3000); // 3遘貞捉譛・
}

// 繝昴・繝ｪ繝ｳ繧ｰ縺ｮ蛛懈ｭ｢
function stopPolling() {
  if (!pollingTimer) return;
  console.log("[DisplayToggle] Stopping system status polling...");
  clearInterval(pollingTimer);
  pollingTimer = null;
}

// 謗･邯壼ｮ御ｺ・う繝吶Φ繝・
$UD.onConnected(() => {
  console.log("[app.js] Display Toggle plugin connected to Ulanzi Studio");
});

// 繧ｭ繝ｼ霑ｽ蜉繧､繝吶Φ繝・
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

// 繧ｭ繝ｼ繧｢繧ｯ繝・ぅ繝也憾諷句､画峩繧､繝吶Φ繝・
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

// 繧ｭ繝ｼ蜑企勁繧､繝吶Φ繝・
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

// 繧ｭ繝ｼ謚ｼ荳九う繝吶Φ繝・(繝医げ繝ｫ蜃ｦ逅・
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

// 險ｭ螳壽峩譁ｰ繧､繝吶Φ繝亥女菫｡譎ゅ・繧ｭ繝｣繝・す繝･譖ｴ譁ｰ
$UD.on('didReceiveSettings', (jsn) => {
  const context = `${jsn.uuid}___${jsn.key}___${jsn.actionid}`;
  console.log(`[app.js] didReceiveSettings for ${context}:`, jsn.settings);
  if (SETTINGS_CACHE[context]) {
    SETTINGS_CACHE[context].simulationMode = jsn.settings?.simulationMode || false;
  }
});

// Ulanzi Studio 謗･邯夐幕蟋・
$UD.connect('com.ulanzi.ulanzistudio.displaytoggle');

