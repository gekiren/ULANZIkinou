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

// 譛ｪ蜿苓ｨ励・萓句､悶→Promise諡貞凄繧偵く繝｣繝・メ縺励※蠑ｷ蛻ｶ繝ｭ繧ｰ蜃ｺ蜉帙☆繧・
process.on('uncaughtException', (err) => {
  console.error('Uncaught Exception:', err);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

console.log("Plugin debug log system initialized. argv:", process.argv);



const UlanziNodeApi = require('./libs/ulanziNodeApi.js');
const scriptPath = path.join(__dirname, 'libs', 'audioControl.ps1');
const $UD = new UlanziNodeApi();

// 蜷・い繧ｯ繧ｷ繝ｧ繝ｳ繧､繝ｳ繧ｹ繧ｿ繝ｳ繧ｹ縺ｮ險ｭ螳壹く繝｣繝・す繝･
// context => { device: string, step: number, currentVolume: number, currentMute: boolean }
const SETTINGS_CACHE = {};

// 繝・ヰ繧､繧ｹ荳隕ｧ縺ｮ繝｡繝｢繝ｪ繧ｭ繝｣繝・す繝･
let cachedDevices = [];

// PowerShell螳溯｡後Λ繝・ヱ繝ｼ
function runPowerShell(args) {
  return new Promise((resolve, reject) => {
    // Windows 縺ｮ繧ｷ繧ｹ繝・Β繝輔か繝ｫ繝縺九ｉ powershell.exe 縺ｮ邨ｶ蟇ｾ繝代せ繧貞ｮ牙・縺ｫ隗｣豎ｺ
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

// 繝・ヰ繧､繧ｹ荳隕ｧ蜿門ｾ・
async function getDevices() {
  try {
    const output = await runPowerShell('-Action GetDevices');
    cachedDevices = output.split('\n').map(d => d.trim()).filter(Boolean);
    console.log("[AudioControl] Fetched devices:", cachedDevices);
    return cachedDevices;
  } catch (err) {
    console.error("[AudioControl] Failed to get devices:", err);
    return [];
  }
}

// 髻ｳ驥丞叙蠕・(0-100)
async function getVolume(device) {
  try {
    const output = await runPowerShell(`-Action GetVolume -DeviceName "${device}"`);
    const val = parseFloat(output.trim());
    return val >= 0 ? Math.round(val * 100) : 50;
  } catch (err) {
    console.error(`[AudioControl] Failed to get volume for ${device}:`, err);
    return 50;
  }
}

// 髻ｳ驥剰ｨｭ螳・(0-100)
async function setVolume(device, vol) {
  const val = vol / 100;
  await runPowerShell(`-Action SetVolume -DeviceName "${device}" -Value ${val}`);
}

// 繝溘Η繝ｼ繝育憾諷句叙蠕・
async function getMute(device) {
  try {
    const output = await runPowerShell(`-Action GetMute -DeviceName "${device}"`);
    return output.trim() === '1';
  } catch (err) {
    console.error(`[AudioControl] Failed to get mute state for ${device}:`, err);
    return false;
  }
}

// 繝溘Η繝ｼ繝郁ｨｭ螳・
async function setMute(device, mute) {
  const val = mute ? 1 : 0;
  await runPowerShell(`-Action SetMute -DeviceName "${device}" -Value ${val}`);
}

// 髻ｳ驥剰ｨｭ螳壹く繝･繝ｼ・磯｣邯壼屓霆｢譎ゅ・驕・ｻｶ繝ｻ隧ｰ縺ｾ繧企亟豁｢・・
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
        console.error(`[AudioControl] Error applying volume to ${device}:`, err);
      }
    }
    this.isExecuting[context] = false;
  }
};

// 逕ｻ髱｢陦ｨ遉ｺ繧呈峩譁ｰ縺吶ｋ (5%蛻ｻ縺ｿ縺ｮ陦ｨ遉ｺ蟇ｾ蠢・
async function updateDialUI(context) {
  const config = SETTINGS_CACHE[context];
  if (!config) return;

  // 0% 縲・100% 繧・%蛻ｻ縺ｿ縺ｫ荳ｸ繧√ｋ (0, 5, 10, 15, ..., 100)
  const vol5 = Math.max(0, Math.min(100, Math.round(config.currentVolume / 5) * 5));
  const iconRelPath = config.currentMute ? 'assets/vol_mute.png' : `assets/vol_${vol5}.png`;

  console.log(`[AudioControl] Updating Dial UI for ${context}: Vol=${config.currentVolume}%, Mute=${config.currentMute}, Path=${iconRelPath}`);
  
  // 繝溘Η繝ｼ繝育憾諷・vol_mute.png) 縺ｾ縺溘・ 5%蛻ｻ縺ｿ縺ｮ髻ｳ驥擾ｼ・判蜒・vol_X.png) 繧帝∽ｿ｡
  $UD.setPathIcon(context, iconRelPath, "");
}

const syncQueue = {};

// OS縺九ｉ譛譁ｰ迥ｶ諷九ｒ蜿門ｾ励＠縺ｦ繧ｭ繝｣繝・す繝･繧呈峩譁ｰ縺誘I縺ｫ蜿肴丐縺吶ｋ
async function syncFromSystem(context) {
  if (syncQueue[context]) {
    // 縺吶〒縺ｫ螳溯｡御ｸｭ縺ｮ蜷梧悄蜃ｦ逅・′縺ゅｋ蝣ｴ蜷医・螳御ｺ・ｒ蠕・■縲∵悴蜃ｦ逅・・隕∵ｱゅ′1縺､縺縺大ｾ・ｩ溘☆繧九ｈ縺・↓縺吶ｋ
    if (syncQueue[context].pending) return;
    syncQueue[context].pending = true;
    await syncQueue[context].promise;
  }

  let resolvePromise;
  const promise = new Promise((resolve) => {
    resolvePromise = resolve;
  });

  syncQueue[context] = {
    promise,
    pending: false
  };

  try {
    const config = SETTINGS_CACHE[context];
    if (config) {
      const device = config.device || "default";
      
      // PowerShell C#繧ｳ繝ｳ繝代う繝ｫ譎ゅ・繝輔ぃ繧､繝ｫ繝ｭ繝・け遶ｶ蜷医ｒ髦ｲ縺舌◆繧√∽ｸｦ陦後〒縺ｯ縺ｪ縺城・ｬ｡螳溯｡後☆繧・
      const vol = await getVolume(device);
      const mute = await getMute(device);

      config.currentVolume = vol;
      config.currentMute = mute;

      await updateDialUI(context);
    }
  } catch (err) {
    console.error(`[AudioControl] Failed to sync state from system for ${context}:`, err);
  } finally {
    resolvePromise();
    if (syncQueue[context] && !syncQueue[context].pending) {
      delete syncQueue[context];
    }
  }
}

// Ulanzi Studio 謗･邯夐幕蟋・
$UD.connect('com.ulanzi.ulanzistudio.lineincontrol');

$UD.onConnected(async () => {
  console.log("[app.js] Plugin main service connected to Ulanzi Studio");
  // 襍ｷ蜍墓凾縺ｫ繝・ヰ繧､繧ｹ荳隕ｧ繧定ｪｭ縺ｿ霎ｼ繧薙〒繧ｭ繝｣繝・す繝･
  await getDevices();
});

// 繧｢繧ｯ繧ｷ繝ｧ繝ｳ霑ｽ蜉譎・
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

  // 閭ｽ蜍慕噪縺ｫ險ｭ螳夲ｼ医ョ繝舌う繧ｹ蜷阪↑縺ｩ・峨ｒ隕∵ｱゅ☆繧・
  $UD.send('getSettings', {
    uuid: jsn.uuid,
    key: jsn.key,
    actionid: jsn.actionid
  });

  await syncFromSystem(context);
});

// 繧｢繝励Μ縺九ｉ險ｭ螳壹ョ繝ｼ繧ｿ繧貞女菫｡縺励◆縺ｨ縺・
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

// 繧｢繧ｯ繧ｷ繝ｧ繝ｳ縺ｮ繧｢繧ｯ繝・ぅ繝也憾諷句､牙喧・郁｡ｨ遉ｺ鬆伜沺縺ｮ蛻・ｊ譖ｿ縺医↑縺ｩ・・
$UD.onSetActive(async (jsn) => {
  const context = jsn.context;
  console.log("[app.js] Action SetActive:", context, jsn.active);
  if (jsn.active) {
    // 繧｢繧ｯ繝・ぅ繝悶↓縺ｪ縺｣縺溘ｉ譛譁ｰ迥ｶ諷九ｒ繧ｷ繧ｹ繝・Β縺ｨ蜷梧悄
    await syncFromSystem(context);
  }
});

// 繧｢繧ｯ繧ｷ繝ｧ繝ｳ蜑企勁譎・
$UD.onClear((jsn) => {
  if (jsn.param) {
    jsn.param.forEach(p => {
      console.log("[app.js] Action cleared:", p.context);
      delete SETTINGS_CACHE[p.context];
    });
  }
});

// Property Inspector 縺九ｉ險ｭ螳壼､画峩縺碁√ｉ繧後※縺阪◆縺ｨ縺・
$UD.onSendToPlugin(async (jsn) => {
  const context = jsn.context;
  const payload = jsn.payload;
  console.log("[app.js] Received settings from Property Inspector:", payload);

  // 螻翫＞縺・context 縺ｮ隗｣譫・
  const parts = context.split('___');
  const actionid = parts[2];

  // SETTINGS_CACHE 縺九ｉ荳閾ｴ縺吶ｋ actionid 繧呈戟縺､豁｣縺励＞繧ｭ繝ｼ諠・ｱ繧偵・繝ｼ繧ｸ縺吶ｋ
  let cacheKey = parts[1];
  for (const cacheCtx of Object.keys(SETTINGS_CACHE)) {
    const cacheParts = cacheCtx.split('___');
    if (cacheParts[2] === actionid && cacheParts[1]) {
      cacheKey = cacheParts[1];
      break;
    }
  }

  // 1. Action UUID 螳帙※縺ｮ繧ｳ繝ｳ繝・く繧ｹ繝医ｒ菴懈・
  const actionContext = `com.ulanzi.ulanzistudio.lineincontrol.control___${cacheKey}___${actionid}`;
  // 2. Plugin UUID 螳帙※縺ｮ繧ｳ繝ｳ繝・く繧ｹ繝医ｒ菴懈・
  const pluginContext = `com.ulanzi.ulanzistudio.lineincontrol___${cacheKey}___${actionid}`;

  if (payload.action === 'getDevices') {
    const list = await getDevices();
    
    // 荳｡譁ｹ縺ｮ繧ｳ繝ｳ繝・く繧ｹ繝医〒騾∽ｿ｡縺励。ridge 縺ｮ莉墓ｧ假ｼ・ction UUID 縺ｾ縺溘・ Plugin UUID・峨・縺ｩ縺｡繧峨〒繧ょｱ翫￥繧医≧縺ｫ縺吶ｋ
    console.log(`[app.js] Sending devices list via both UUIDs: key=${cacheKey}`);
    $UD.sendToPropertyInspector({ action: 'devicesList', devices: list }, actionContext);
    $UD.sendToPropertyInspector({ action: 'devicesList', devices: list }, pluginContext);
    return;
  }

  // SETTINGS_CACHE 縺ｮ譖ｴ譁ｰ蟇ｾ雎｡繧ｳ繝ｳ繝・く繧ｹ繝医・ uuid 縺ｯ Action UUID 縺ｨ縺吶ｋ
  const targetActionContext = `com.ulanzi.ulanzistudio.lineincontrol.control___${cacheKey}___${actionid}`;

  if (!SETTINGS_CACHE[targetActionContext]) {
    SETTINGS_CACHE[targetActionContext] = {
      device: "default",
      step: 5,
      currentVolume: 50,
      currentMute: false
    };
  }

  if (payload.device !== undefined) {
    SETTINGS_CACHE[targetActionContext].device = payload.device;
  }
  if (payload.step !== undefined) {
    SETTINGS_CACHE[targetActionContext].step = parseInt(payload.step) || 5;
  }

  // 險ｭ螳壹ｒ荳贋ｽ肴ｩ溘↓菫晏ｭ・
  $UD.setSettings({
    device: SETTINGS_CACHE[targetActionContext].device,
    step: SETTINGS_CACHE[targetActionContext].step
  }, targetActionContext);

  // 譁ｰ縺励＞繝・ヰ繧､繧ｹ縺ｮ髻ｳ驥上→蜷梧悄
  await syncFromSystem(targetActionContext);
});

// 荳贋ｽ肴ｩ溷・縺九ｉ繝代Λ繝｡繝ｼ繧ｿ蜷梧悄・・roperty Inspector隱ｭ縺ｿ霎ｼ縺ｿ譎ゅ↑縺ｩ・・
$UD.onParamFromApp(async (jsn) => {
  const context = jsn.context;
  if (!SETTINGS_CACHE[context]) {
    console.log(`[app.js] Cache not found in onParamFromApp. Initializing cache for ${context}`);
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

// 繝繧､繝､繝ｫ・医ヮ繝厄ｼ峨・蝗櫁ｻ｢繧､繝吶Φ繝・
$UD.onDialRotate(async (jsn) => {
  const context = jsn.context;
  const config = SETTINGS_CACHE[context];
  if (!config) return;

  const event = jsn.rotateEvent; // 'left' | 'right' | 'hold-left' | 'hold-right'
  console.log(`[app.js] Dial rotate event for ${context}: ${event}`);

  // 繝溘Η繝ｼ繝育憾諷九・蝣ｴ蜷医・髻ｳ驥丞､画峩縺ｧ繝溘Η繝ｼ繝郁ｧ｣髯､縺吶ｋ・井ｸ闊ｬ逧・↑繧ｪ繝ｼ繝・ぅ繧ｪ讖溷勣縺ｮ隕ｪ蛻・↑謖吝虚・・
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
    // 繝繧､繝､繝ｫ陦ｨ遉ｺ繧偵☆縺舌↓譖ｴ譁ｰ・磯≦蟒ｶ諢溘ｒ蜃ｺ縺輔↑縺・◆繧・ｼ・
    await updateDialUI(context);
    // OS蛛ｴ縺ｮ髻ｳ驥上ｒ髱槫酔譛溘〒螳牙・縺ｫ驕ｩ逕ｨ・医せ繝ｭ繝・ヨ繝ｪ繝ｳ繧ｰ・・
    await volumeQueue.apply(context, config.device || "default", newVol);
  }
});

// 繝繧､繝､繝ｫ縺ｮ謚ｼ縺嶺ｸ九￡・医け繝ｪ繝・け・峨う繝吶Φ繝・
$UD.onDialDown(async (jsn) => {
  const context = jsn.context;
  const config = SETTINGS_CACHE[context];
  if (!config) return;

  console.log(`[app.js] Dial down (mute toggle) for ${context}`);

  // 繝溘Η繝ｼ繝育憾諷九ｒ繝医げ繝ｫ
  config.currentMute = !config.currentMute;

  // 繝繧､繝､繝ｫ陦ｨ遉ｺ繧貞叉蠎ｧ縺ｫ譖ｴ譁ｰ
  await updateDialUI(context);

  // OS縺ｸ驕ｩ逕ｨ
  try {
    await setMute(config.device || "default", config.currentMute);
  } catch (err) {
    console.error("[app.js] Failed to toggle mute on system:", err);
  }
});

