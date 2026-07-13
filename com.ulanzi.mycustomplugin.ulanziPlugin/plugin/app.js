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

// 未受託の例外とPromise拒否をキャッチして強制ログ出力する
process.on('uncaughtException', (err) => {
  console.error('Uncaught Exception:', err);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

console.log("Plugin debug log system initialized. argv:", process.argv);

// ローカル画像を Base64 データURLに変換する処理
function getBase64Image(relativePath) {
  try {
    const fullPath = path.join(__dirname, '..', relativePath);
    const fileBuffer = fs.readFileSync(fullPath);
    return `data:image/png;base64,${fileBuffer.toString('base64')}`;
  } catch (err) {
    console.error(`[app.js] Failed to read image for Base64: ${relativePath}`, err);
    return "";
  }
}

const micOnBase64 = getBase64Image('assets/mic_on.png');
const micOffBase64 = getBase64Image('assets/mic_off.png');

const UlanziNodeApi = require('./libs/ulanziNodeApi.js');
const scriptPath = path.join(__dirname, 'libs', 'audioControl.ps1');
const $UD = new UlanziNodeApi();

// 各アクションインスタンスの設定キャッシュ
// context => { device: string, step: number, currentVolume: number, currentMute: boolean }
const SETTINGS_CACHE = {};

// デバイス一覧のメモリキャッシュ
let cachedDevices = [];

// PowerShell実行ラッパー
function runPowerShell(args) {
  return new Promise((resolve, reject) => {
    // Windows のシステムフォルダから powershell.exe の絶対パスを安全に解決
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

// デバイス一覧取得
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

// 音量取得 (0-100)
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

// 音量設定 (0-100)
async function setVolume(device, vol) {
  const val = vol / 100;
  await runPowerShell(`-Action SetVolume -DeviceName "${device}" -Value ${val}`);
}

// ミュート状態取得
async function getMute(device) {
  try {
    const output = await runPowerShell(`-Action GetMute -DeviceName "${device}"`);
    return output.trim() === '1';
  } catch (err) {
    console.error(`[AudioControl] Failed to get mute state for ${device}:`, err);
    return false;
  }
}

// ミュート設定
async function setMute(device, mute) {
  const val = mute ? 1 : 0;
  await runPowerShell(`-Action SetMute -DeviceName "${device}" -Value ${val}`);
}

// 音量設定キュー（連続回転時の遅延・詰まり防止）
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

// 画面表示を更新する
async function updateDialUI(context) {
  const config = SETTINGS_CACHE[context];
  if (!config) return;

  const volText = config.currentMute ? "MUTE" : `${config.currentVolume}%`;
  const iconData = config.currentMute ? micOffBase64 : micOnBase64;

  console.log(`[AudioControl] Updating Dial UI for ${context}: Vol=${volText}, Mute=${config.currentMute}`);
  
  // カスタムキーを指定して layout.json の表示要素を個別に更新
  $UD.setFeedback({
    "mic_icon": iconData,
    "volume_text": volText
  }, context);
}

const syncQueue = {};

// OSから最新状態を取得してキャッシュを更新しUIに反映する
async function syncFromSystem(context) {
  if (syncQueue[context]) {
    // すでに実行中の同期処理がある場合は完了を待ち、未処理の要求が1つだけ待機するようにする
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
      
      // PowerShell C#コンパイル時のファイルロック競合を防ぐため、並行ではなく順次実行する
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

// Ulanzi Studio 接続開始
$UD.connect('com.ulanzi.ulanzistudio.lineincontrol');

$UD.onConnected(async () => {
  console.log("[app.js] Plugin main service connected to Ulanzi Studio");
  // 起動時にデバイス一覧を読み込んでキャッシュ
  await getDevices();
});

// アクション追加時
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

  // 能動的に設定（デバイス名など）を要求する
  $UD.send('getSettings', {
    uuid: jsn.uuid,
    key: jsn.key,
    actionid: jsn.actionid
  });

  await syncFromSystem(context);
});

// アプリから設定データを受信したとき
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

// アクションのアクティブ状態変化（表示領域の切り替えなど）
$UD.onSetActive(async (jsn) => {
  const context = jsn.context;
  console.log("[app.js] Action SetActive:", context, jsn.active);
  if (jsn.active) {
    // アクティブになったら最新状態をシステムと同期
    await syncFromSystem(context);
  }
});

// アクション削除時
$UD.onClear((jsn) => {
  if (jsn.param) {
    jsn.param.forEach(p => {
      console.log("[app.js] Action cleared:", p.context);
      delete SETTINGS_CACHE[p.context];
    });
  }
});

// Property Inspector から設定変更が送られてきたとき
$UD.onSendToPlugin(async (jsn) => {
  const context = jsn.context;
  const payload = jsn.payload;
  console.log("[app.js] Received settings from Property Inspector:", payload);

  if (payload.action === 'getDevices') {
    // デバイス一覧のリクエストがあれば即座に取得して返す
    const list = await getDevices();
    $UD.sendToPropertyInspector({ action: 'devicesList', devices: list }, context);
    return;
  }

  if (!SETTINGS_CACHE[context]) {
    SETTINGS_CACHE[context] = {
      device: "default",
      step: 5,
      currentVolume: 50,
      currentMute: false
    };
  }

  if (payload.device !== undefined) {
    SETTINGS_CACHE[context].device = payload.device;
  }
  if (payload.step !== undefined) {
    SETTINGS_CACHE[context].step = parseInt(payload.step) || 5;
  }

  // 設定を上位機に保存
  $UD.setSettings({
    device: SETTINGS_CACHE[context].device,
    step: SETTINGS_CACHE[context].step
  }, context);

  // 新しいデバイスの音量と同期
  await syncFromSystem(context);
});

// 上位機側からパラメータ同期（Property Inspector読み込み時など）
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

// ダイヤル（ノブ）の回転イベント
$UD.onDialRotate(async (jsn) => {
  const context = jsn.context;
  const config = SETTINGS_CACHE[context];
  if (!config) return;

  const event = jsn.rotateEvent; // 'left' | 'right' | 'hold-left' | 'hold-right'
  console.log(`[app.js] Dial rotate event for ${context}: ${event}`);

  // ミュート状態の場合は音量変更でミュート解除する（一般的なオーディオ機器の親切な挙動）
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
    // ダイヤル表示をすぐに更新（遅延感を出さないため）
    await updateDialUI(context);
    // OS側の音量を非同期で安全に適用（スロットリング）
    await volumeQueue.apply(context, config.device || "default", newVol);
  }
});

// ダイヤルの押し下げ（クリック）イベント
$UD.onDialDown(async (jsn) => {
  const context = jsn.context;
  const config = SETTINGS_CACHE[context];
  if (!config) return;

  console.log(`[app.js] Dial down (mute toggle) for ${context}`);

  // ミュート状態をトグル
  config.currentMute = !config.currentMute;

  // ダイヤル表示を即座に更新
  await updateDialUI(context);

  // OSへ適用
  try {
    await setMute(config.device || "default", config.currentMute);
  } catch (err) {
    console.error("[app.js] Failed to toggle mute on system:", err);
  }
});
