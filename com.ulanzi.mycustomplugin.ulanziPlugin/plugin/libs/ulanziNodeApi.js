import WebSocket from 'ws';
import EventEmitter from 'events';

export default class UlanziNodeApi extends EventEmitter {
  constructor() {
    super();
    this.websocket = null;
    this.key = "";
    this.uuid = "";
    this.actionid = "";
  }

  connect(uuid) {
    this.uuid = uuid;
    const args = process.argv.slice(2);
    const address = args[0] || '127.0.0.1';
    const port = args[1] || '3906';
    
    console.log(`[UlanziNodeApi] Connecting to ws://${address}:${port} for UUID: ${this.uuid}`);
    this.websocket = new WebSocket(`ws://${address}:${port}`);

    this.websocket.on('open', () => {
      console.log(`[UlanziNodeApi] Connected to Ulanzi Studio Bridge`);
      const json = {
        code: 0,
        cmd: 'connected',
        actionid: this.actionid,
        key: this.key,
        uuid: this.uuid,
      };
      this.websocket.send(JSON.stringify(json));
      this.emit('connected');
    });

    this.websocket.on('message', (data) => {
      try {
        const msg = JSON.parse(data.toString());

        if (msg.cmd === 'clear') {
          if (msg.param) {
            msg.param.forEach(p => {
              p.context = `${p.uuid}___${p.key}___${p.actionid}`;
            });
          }
        } else {
          msg.context = `${msg.uuid}___${msg.key}___${msg.actionid}`;
        }
        
        if (this.uuid.split('.').length === 4 && msg.cmd !== 'connected') {
          this.websocket.send(JSON.stringify({
            cmd: msg.cmd,
            code: 0,
            ...msg
          }));
        }

        let cmd = msg.cmd;
        if (cmd === 'daildown') cmd = 'dialdown';
        if (cmd === 'dailup') cmd = 'dialup';

        this.emit(cmd, msg);
      } catch (err) {
        console.error(`[UlanziNodeApi] Error parsing message:`, err);
      }
    });

    this.websocket.on('error', (err) => {
      console.error(`[UlanziNodeApi] WebSocket error:`, err);
      this.emit('error', err);
    });

    this.websocket.on('close', () => {
      console.log(`[UlanziNodeApi] WebSocket connection closed`);
      this.emit('close');
    });
  }

  send(cmd, params) {
    if (this.websocket && this.websocket.readyState === WebSocket.OPEN) {
      const msg = {
        cmd,
        uuid: this.uuid,
        key: this.key,
        actionid: this.actionid,
        ...params
      };
      this.websocket.send(JSON.stringify(msg));
    } else {
      console.warn(`[UlanziNodeApi] Cannot send command ${cmd}: Socket is not open`);
    }
  }

  setSettings(settings, context) {
    const parts = context.split('___');
    this.send('setSettings', {
      uuid: parts[0],
      key: parts[1],
      actionid: parts[2],
      settings
    });
  }

  sendToPropertyInspector(payload, context) {
    const parts = context.split('___');
    this.send('sendToPropertyInspector', {
      uuid: parts[0],
      key: parts[1],
      actionid: parts[2],
      payload
    });
  }

  setFeedback(payload, context) {
    const parts = context.split('___');
    this.send('setFeedback', {
      uuid: parts[0],
      key: parts[1],
      actionid: parts[2],
      payload
    });
  }

  onConnected(fn) { this.on('connected', fn); }
  onAdd(fn) { this.on('add', fn); }
  onRun(fn) { this.on('run', fn); }
  onSetActive(fn) { this.on('setactive', fn); }
  onClear(fn) { this.on('clear', fn); }
  onDialDown(fn) { this.on('dialdown', fn); }
  onDialUp(fn) { this.on('dialup', fn); }
  onDialRotate(fn) { this.on('dialrotate', fn); }
  onSendToPlugin(fn) { this.on('sendToPlugin', fn); }
  onParamFromApp(fn) { this.on('paramfromapp', fn); }
}
