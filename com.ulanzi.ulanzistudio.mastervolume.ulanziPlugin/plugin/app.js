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

console.log("Master Volume Plugin initialized. argv:", process.argv);

const UlanziNodeApi = require('./libs/ulanziNodeApi.js');
const scriptPath = path.join(__dirname, 'libs', 'masterAudioControl.ps1');
const $UD = new UlanziNodeApi();

const SETTINGS_CACHE = {};

// アクションUUID定数 (msg.uuid に送られてくる)
const ACTION_MASTER  = 'com.ulanzi.ulanzistudio.mastervolume.control';
const ACTION_APPVOL  = 'com.ulanzi.ulanzistudio.mastervolume.appvolume';

function checkIsAppMode(jsn, context) {
  if (jsn && jsn.uuid === ACTION_APPVOL) return true;
  if (context && context.startsWith(ACTION_APPVOL)) return true;
  return false;
}

function runPowerShell(args) {
  return new Promise((resolve, reject) => {
    const system32 = process.env.SystemRoot ? path.join(process.env.SystemRoot, 'System32') : 'C:\\Windows\\System32';
    const powershellPath = path.join(system32, 'WindowsPowerShell', 'v1.0', 'powershell.exe');
    const command = `"${powershellPath}" -NoProfile -ExecutionPolicy Bypass -File "${scriptPath}" ${args}`;

    exec(command, { encoding: 'utf8' }, (error, stdout, stderr) => {
      if (error) {
        reject(error);
      } else {
        resolve(stdout.trim());
      }
    });
  });
}

// ========= Master Volume API =========

async function getVolume(device = "default") {
  try {
    const output = await runPowerShell(`-Action GetVolume -DeviceName "${device}"`);
    const val = parseFloat(output.trim());
    return val >= 0 ? Math.round(val * 100) : 50;
  } catch (err) {
    console.error(`[AudioControl] Failed to get volume:`, err);
    return 50;
  }
}

async function setVolume(device = "default", vol = 50) {
  const val = Math.max(0, Math.min(100, vol)) / 100.0;
  await runPowerShell(`-Action SetVolume -DeviceName "${device}" -Value ${val}`);
}

async function getMute(device = "default") {
  try {
    const output = await runPowerShell(`-Action GetMute -DeviceName "${device}"`);
    return output.trim() === '1';
  } catch (err) {
    console.error(`[AudioControl] Failed to get mute:`, err);
    return false;
  }
}

async function setMute(device = "default", mute = false) {
  const val = mute ? 1 : 0;
  await runPowerShell(`-Action SetMute -DeviceName "${device}" -Value ${val}`);
}

// ========= Foreground App Volume API =========

async function getForegroundVolume() {
  try {
    const output = await runPowerShell(`-Action GetForegroundVolume`);
    const val = parseFloat(output.trim());
    if (val < 0) return -1;
    return Math.round(val * 100);
  } catch (err) {
    console.error(`[AppVolume] Failed to get foreground volume:`, err);
    return -1;
  }
}

async function setForegroundVolume(vol = 50) {
  const val = Math.max(0, Math.min(100, vol)) / 100.0;
  await runPowerShell(`-Action SetForegroundVolume -Value ${val}`);
}

async function getForegroundMute() {
  try {
    const output = await runPowerShell(`-Action GetForegroundMute`);
    const val = parseInt(output.trim());
    if (val < 0) return null;
    return val === 1;
  } catch (err) {
    console.error(`[AppVolume] Failed to get foreground mute:`, err);
    return null;
  }
}

async function setForegroundMute(mute = false) {
  const val = mute ? 1 : 0;
  await runPowerShell(`-Action SetForegroundMute -Value ${val}`);
}

async function getForegroundAppName() {
  try {
    const output = await runPowerShell(`-Action GetForegroundAppName`);
    return output.trim() || 'App';
  } catch (err) {
    return 'App';
  }
}

// ========= Volume Queue =========

const volumeQueue = {
  isExecuting: {},
  pendingVolume: {},

  async apply(context, isAppMode, device, volume) {
    this.pendingVolume[context] = volume;
    if (this.isExecuting[context]) return;
    this.isExecuting[context] = true;

    while (this.pendingVolume[context] !== null) {
      const volToApply = this.pendingVolume[context];
      this.pendingVolume[context] = null;
      try {
        if (isAppMode) {
          await setForegroundVolume(volToApply);
        } else {
          await setVolume(device, volToApply);
        }
      } catch (err) {
        console.error(`[AudioControl] Error applying volume:`, err);
      }
    }
    this.isExecuting[context] = false;
  }
};

// ========= UI Update =========

async function updateDialUI(context) {
  const config = SETTINGS_CACHE[context];
  if (!config) return;

  const vol5 = Math.max(0, Math.min(100, Math.round(config.currentVolume / 5) * 5));
  const iconRelPath = config.currentMute ? 'assets/vol_mute.png' : `assets/vol_${vol5}.png`;

  let volText;
  if (config.isAppMode) {
    const appShort = (config.appName || 'App').substring(0, 8);
    volText = config.currentMute ? `${appShort}:MUTE` : `${appShort}:${config.currentVolume}%`;
  } else {
    volText = config.currentMute ? "MUTE" : `${config.currentVolume}%`;
  }

  console.log(`[AudioControl] Updating Dial UI for ${context} (isAppMode=${config.isAppMode}): Vol=${config.currentVolume}%, Mute=${config.currentMute}, Path=${iconRelPath}, Text=${volText}`);

  try {
    $UD.setPathIcon(context, iconRelPath, volText);
  } catch (err) {
    console.error(`[AudioControl] Error updating UI:`, err);
  }
}

const syncQueue = {};

// ========= Sync from System =========

async function syncFromSystem(context) {
  if (syncQueue[context]) {
    if (syncQueue[context].pending) return;
    syncQueue[context].pending = true;
    await syncQueue[context].promise;
  }

  let resolvePromise;
  const promise = new Promise((resolve) => {
    resolvePromise = resolve;
  });

  syncQueue[context] = { promise, pending: false };

  try {
    const config = SETTINGS_CACHE[context];
    if (config) {
      if (config.isAppMode) {
        const [appVol, appMute, appName] = await Promise.all([
          getForegroundVolume(),
          getForegroundMute(),
          getForegroundAppName()
        ]);

        config.appName = appName;

        if (appVol < 0) {
          // セッションなし → マスター音量にフォールバック
          const device = config.device || "default";
          config.currentVolume = await getVolume(device);
          config.currentMute = await getMute(device);
          config.appName = 'Master';
        } else {
          config.currentVolume = appVol;
          config.currentMute = appMute === null ? false : appMute;
        }
      } else {
        const device = config.device || "default";
        const vol = await getVolume(device);
        const mute = await getMute(device);
        config.currentVolume = vol;
        config.currentMute = mute;
      }

      await updateDialUI(context);
    }
  } catch (err) {
    console.error(`[AudioControl] Failed to sync state for ${context}:`, err);
  } finally {
    resolvePromise();
    if (syncQueue[context] && !syncQueue[context].pending) {
      delete syncQueue[context];
    }
  }
}

// ========= Plugin Connect =========

$UD.connect('com.ulanzi.ulanzistudio.mastervolume');

$UD.onConnected(() => {
  console.log("[app.js] Master Volume Service connected to Ulanzi Studio");
});

// ========= Action Add =========

$UD.onAdd(async (jsn) => {
  const context = jsn.context;
  const isAppMode = checkIsAppMode(jsn, context);
  console.log(`[app.js] Action added: ${context}, jsn.uuid=${jsn.uuid}, isAppMode=${isAppMode}`);

  if (!SETTINGS_CACHE[context]) {
    SETTINGS_CACHE[context] = {
      isAppMode,
      device: "default",
      step: 5,
      currentVolume: 50,
      currentMute: false,
      appName: 'App'
    };
  } else {
    SETTINGS_CACHE[context].isAppMode = isAppMode;
  }

  $UD.send('getSettings', {
    uuid: jsn.uuid,
    key: jsn.key,
    actionid: jsn.actionid
  });

  await syncFromSystem(context);
});

// ========= Settings Received =========

$UD.on('didReceiveSettings', async (jsn) => {
  const context = `${jsn.uuid}___${jsn.key}___${jsn.actionid}`;
  const isAppMode = checkIsAppMode(jsn, context);
  console.log(`[app.js] Received settings via didReceiveSettings for ${context}:`, jsn.settings);

  if (!SETTINGS_CACHE[context]) {
    SETTINGS_CACHE[context] = {
      isAppMode,
      device: "default",
      step: 5,
      currentVolume: 50,
      currentMute: false,
      appName: 'App'
    };
  } else {
    SETTINGS_CACHE[context].isAppMode = isAppMode;
  }

  if (jsn.settings) {
    if (jsn.settings.device) SETTINGS_CACHE[context].device = jsn.settings.device;
    if (jsn.settings.step) SETTINGS_CACHE[context].step = parseInt(jsn.settings.step) || 5;
  }

  await syncFromSystem(context);
});

// ========= SetActive =========

$UD.onSetActive(async (jsn) => {
  const context = jsn.context;
  console.log("[app.js] Action SetActive:", context, jsn.active);
  if (jsn.active) {
    await syncFromSystem(context);
  }
});

// ========= Clear =========

$UD.onClear((jsn) => {
  if (jsn.param) {
    jsn.param.forEach(p => {
      console.log("[app.js] Action cleared:", p.context);
      delete SETTINGS_CACHE[p.context];
    });
  }
});

// ========= Param from App (Inspector) =========

$UD.onParamFromApp(async (jsn) => {
  const context = jsn.context;
  const isAppMode = checkIsAppMode(jsn, context);

  if (!SETTINGS_CACHE[context]) {
    console.log(`[app.js] Cache initialized in onParamFromApp for ${context}`);
    SETTINGS_CACHE[context] = {
      isAppMode,
      device: "default",
      step: 5,
      currentVolume: 50,
      currentMute: false,
      appName: 'App'
    };
  } else {
    SETTINGS_CACHE[context].isAppMode = isAppMode;
  }

  if (jsn.param) {
    if (jsn.param.device) SETTINGS_CACHE[context].device = jsn.param.device;
    if (jsn.param.step) SETTINGS_CACHE[context].step = parseInt(jsn.param.step) || 5;
  }

  await syncFromSystem(context);
});

// ========= Dial Rotate =========

$UD.onDialRotate(async (jsn) => {
  const context = jsn.context;
  const isAppMode = checkIsAppMode(jsn, context);
  let config = SETTINGS_CACHE[context];

  if (!config) {
    console.log(`[app.js] Fallback config creation onDialRotate for ${context}`);
    SETTINGS_CACHE[context] = {
      isAppMode,
      device: "default",
      step: 5,
      currentVolume: isAppMode ? (await getForegroundVolume().catch(() => 50) || 50) : await getVolume("default"),
      currentMute: isAppMode ? false : await getMute("default"),
      appName: isAppMode ? await getForegroundAppName() : 'Master'
    };
    config = SETTINGS_CACHE[context];
  }

  config.isAppMode = isAppMode;

  const event = jsn.rotateEvent;
  console.log(`[app.js] Dial rotate event for ${context}: ${event}, isAppMode=${isAppMode}`);

  // アプリモードの場合、回した瞬間にも最新のフォアグラウンドアプリ情報を取得
  if (isAppMode) {
    const appName = await getForegroundAppName();
    const appVol = await getForegroundVolume();
    config.appName = appName;
    if (appVol >= 0) {
      config.currentVolume = appVol;
    }
  }

  if (config.currentMute) {
    config.currentMute = false;
    if (isAppMode) {
      await setForegroundMute(false);
    } else {
      await setMute(config.device || "default", false);
    }
  }

  const step = config.step || 5;
  let newVol = config.currentVolume;

  if (event === 'left' || event === 'hold-left') {
    newVol = Math.max(0, config.currentVolume - step);
  } else if (event === 'right' || event === 'hold-right') {
    newVol = Math.min(100, config.currentVolume + step);
  }

  if (newVol !== config.currentVolume) {
    config.currentVolume = newVol;
    await updateDialUI(context);
    await volumeQueue.apply(context, isAppMode, config.device || "default", newVol);
  }
});

// ========= Dial Down (Mute Toggle) =========

$UD.onDialDown(async (jsn) => {
  const context = jsn.context;
  const isAppMode = checkIsAppMode(jsn, context);
  let config = SETTINGS_CACHE[context];

  if (!config) {
    console.log(`[app.js] Fallback config creation onDialDown for ${context}`);
    SETTINGS_CACHE[context] = {
      isAppMode,
      device: "default",
      step: 5,
      currentVolume: 50,
      currentMute: false,
      appName: 'App'
    };
    config = SETTINGS_CACHE[context];
  }

  config.isAppMode = isAppMode;
  console.log(`[app.js] Dial down (mute toggle) for ${context}, isAppMode=${isAppMode}`);

  config.currentMute = !config.currentMute;
  await updateDialUI(context);

  try {
    if (isAppMode) {
      await setForegroundMute(config.currentMute);
    } else {
      await setMute(config.device || "default", config.currentMute);
    }
  } catch (err) {
    console.error("[app.js] Failed to toggle mute:", err);
  }
});
