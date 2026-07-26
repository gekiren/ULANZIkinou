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
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

console.log("Master Volume Plugin initialized. argv:", process.argv);

const UlanziNodeApi = require('./libs/ulanziNodeApi.js');
const scriptPath = path.join(__dirname, 'libs', 'masterAudioControl.ps1');
const $UD = new UlanziNodeApi();

const SETTINGS_CACHE = {};

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

const volumeQueue = {
  isExecuting: {},
  pendingVolume: {},

  async apply(context, device, volume) {
    this.pendingVolume[context] = volume;
    if (this.isExecuting[context]) return;
    this.isExecuting[context] = true;

    while (this.pendingVolume[context] !== null) {
      const volToApply = this.pendingVolume[context];
      this.pendingVolume[context] = null;
      try {
        await setVolume(device, volToApply);
      } catch (err) {
        console.error(`[AudioControl] Error applying volume:`, err);
      }
    }
    this.isExecuting[context] = false;
  }
};

// 5%刻みの音量％画像/ミュート画像切り替えによる画面描画ロジック
async function updateDialUI(context) {
  const config = SETTINGS_CACHE[context];
  if (!config) return;

  const vol5 = Math.max(0, Math.min(100, Math.round(config.currentVolume / 5) * 5));
  const iconRelPath = config.currentMute ? 'assets/vol_mute.png' : `assets/vol_${vol5}.png`;
  const volText = config.currentMute ? "MUTE" : `${config.currentVolume}%`;

  console.log(`[AudioControl] Updating Dial UI for ${context}: Vol=${config.currentVolume}%, Mute=${config.currentMute}, Path=${iconRelPath}`);

  try {
    // 1. setFeedback でテキストタイトルも同時に更新
    $UD.setFeedback({
      title: volText
    }, context);

    // 2. setPathIcon で音量％・ミュート付きの動的画像を表示
    $UD.setPathIcon(context, iconRelPath, volText);
  } catch (err) {
    console.error(`[AudioControl] Error updating UI:`, err);
  }
}

const syncQueue = {};

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
      const device = config.device || "default";
      const vol = await getVolume(device);
      const mute = await getMute(device);

      config.currentVolume = vol;
      config.currentMute = mute;

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

$UD.connect('com.ulanzi.ulanzistudio.mastervolume');

$UD.onConnected(() => {
  console.log("[app.js] Master Volume Service connected to Ulanzi Studio");
});

$UD.onAdd(async (jsn) => {
  const context = jsn.context;
  console.log(`[app.js] Action added: ${context}`);

  if (!SETTINGS_CACHE[context]) {
    SETTINGS_CACHE[context] = {
      device: "default",
      step: 5,
      currentVolume: 50,
      currentMute: false
    };
  }

  $UD.send('getSettings', {
    uuid: jsn.uuid,
    key: jsn.key,
    actionid: jsn.actionid
  });

  await syncFromSystem(context);
});

$UD.on('didReceiveSettings', async (jsn) => {
  const context = `${jsn.uuid}___${jsn.key}___${jsn.actionid}`;
  console.log(`[app.js] Received settings via didReceiveSettings for ${context}:`, jsn.settings);

  if (!SETTINGS_CACHE[context]) {
    SETTINGS_CACHE[context] = {
      device: "default",
      step: 5,
      currentVolume: 50,
      currentMute: false
    };
  }

  if (jsn.settings) {
    if (jsn.settings.device) SETTINGS_CACHE[context].device = jsn.settings.device;
    if (jsn.settings.step) SETTINGS_CACHE[context].step = parseInt(jsn.settings.step) || 5;
  }

  await syncFromSystem(context);
});

$UD.onSetActive(async (jsn) => {
  const context = jsn.context;
  console.log("[app.js] Action SetActive:", context, jsn.active);
  if (jsn.active) {
    await syncFromSystem(context);
  }
});

$UD.onClear((jsn) => {
  if (jsn.param) {
    jsn.param.forEach(p => {
      console.log("[app.js] Action cleared:", p.context);
      delete SETTINGS_CACHE[p.context];
    });
  }
});

$UD.onParamFromApp(async (jsn) => {
  const context = jsn.context;
  if (!SETTINGS_CACHE[context]) {
    console.log(`[app.js] Cache initialized in onParamFromApp for ${context}`);
    SETTINGS_CACHE[context] = {
      device: "default",
      step: 5,
      currentVolume: 50,
      currentMute: false
    };
  }

  if (jsn.param) {
    if (jsn.param.device) SETTINGS_CACHE[context].device = jsn.param.device;
    if (jsn.param.step) SETTINGS_CACHE[context].step = parseInt(jsn.param.step) || 5;
  }

  await syncFromSystem(context);
});

$UD.onDialRotate(async (jsn) => {
  const context = jsn.context;
  let config = SETTINGS_CACHE[context];

  if (!config) {
    console.log(`[app.js] Fallback config creation onDialRotate for ${context}`);
    SETTINGS_CACHE[context] = {
      device: "default",
      step: 5,
      currentVolume: await getVolume("default"),
      currentMute: await getMute("default")
    };
    config = SETTINGS_CACHE[context];
  }

  const event = jsn.rotateEvent;
  console.log(`[app.js] Dial rotate event for ${context}: ${event}`);

  if (config.currentMute) {
    config.currentMute = false;
    await setMute(config.device || "default", false);
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
    await volumeQueue.apply(context, config.device || "default", newVol);
  }
});

$UD.onDialDown(async (jsn) => {
  const context = jsn.context;
  let config = SETTINGS_CACHE[context];

  if (!config) {
    console.log(`[app.js] Fallback config creation onDialDown for ${context}`);
    SETTINGS_CACHE[context] = {
      device: "default",
      step: 5,
      currentVolume: await getVolume("default"),
      currentMute: await getMute("default")
    };
    config = SETTINGS_CACHE[context];
  }

  console.log(`[app.js] Dial down (mute toggle) for ${context}`);

  config.currentMute = !config.currentMute;
  await updateDialUI(context);

  try {
    await setMute(config.device || "default", config.currentMute);
  } catch (err) {
    console.error("[app.js] Failed to toggle mute:", err);
  }
});
