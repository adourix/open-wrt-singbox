'use strict';
'require view';
'require rpc';
'require ui';
'require css';
'require css'('view/cowboy-bebop/overview.css');

var callStatus = rpc.declare({ object: 'luci.cowboy_bebop', method: 'status', expect: { '': {} } });
var callHealth = rpc.declare({ object: 'luci.cowboy_bebop', method: 'health', expect: { '': {} } });
var callPreview = rpc.declare({ object: 'luci.cowboy_bebop', method: 'preview', params: { proxy_url: '' }, expect: { '': {} } });
var callApply = rpc.declare({ object: 'luci.cowboy_bebop', method: 'apply', params: { proxy_url: '' }, expect: { '': {} } });
var callStart = rpc.declare({ object: 'luci.cowboy_bebop', method: 'start', expect: { '': {} } });
var callStop = rpc.declare({ object: 'luci.cowboy_bebop', method: 'stop', expect: { '': {} } });
var callConfirm = rpc.declare({ object: 'luci.cowboy_bebop', method: 'confirm', expect: { '': {} } });
var callLogs = rpc.declare({ object: 'luci.cowboy_bebop', method: 'logs', expect: { '': {} } });
var callSettings = rpc.declare({ object: 'luci.cowboy_bebop', method: 'settings', expect: { '': {} } });
var callSetSettings = rpc.declare({ object: 'luci.cowboy_bebop', method: 'set_settings', params: { auto_start: false, allow_insecure: false, ipv6_policy: '' }, expect: { '': {} } });
var callRecovery = rpc.declare({ object: 'luci.cowboy_bebop', method: 'recovery', expect: { '': {} } });

function node(tag, attrs, children) { return E(tag, attrs || {}, children || []); }
function button(label, handler, cls) { return node('button', { type: 'button', class: 'cbi-button ' + (cls || ''), click: handler }, [ _(label) ]); }
function msg(result, fallback) { return result && result.error ? result.error : fallback; }
function notify(text, type) { ui.addNotification(null, E('p', [ _(text) ]), type || 'info'); }
function ensureOk(result, fallback) { if (!result || result.ok !== true) throw new Error(msg(result, fallback)); return result; }
function text(value, fallback) { return value === undefined || value === null || value === '' ? (fallback || '—') : String(value); }
function badge(label, cls) { return node('span', { class: 'cb-badge ' + (cls || '') }, [ _(label) ]); }

return view.extend({
 load: function() {
  return Promise.all([
   callStatus().catch(function() { return {}; }),
   callLogs().catch(function() { return { lines: [] }; }),
   callSettings().catch(function() { return {}; })
  ]);
 },
 render: function(data) {
  var status = data[0] || {}, logs = data[1] || { lines: [] }, settings = data[2] || {};
  var root = node('div', { class: 'cb-manager-page' });
  var url, summary, pill, profileRows, settingsRows, logBox, previewBox, confirmBox;
  var previewButton, applyButton, startButton, stopButton, refreshButton, logsButton, auto, insecure, ipv6;
  var busy = false;

  function setBusy(value) {
   busy = value;
   [previewButton, applyButton, startButton, stopButton, refreshButton, logsButton].forEach(function(el) { if (el) el.disabled = value; });
   if (url) url.disabled = value;
  }
  function currentState(s) {
   if (s.pending) return { label: 'Confirmation required', title: 'Confirm this configuration', detail: 'The safety rollback window is active.', cls: 'is-pending' };
   var state = s.state || (s.running ? 'RUNNING' : (s.enabled ? 'ERROR' : 'STOPPED'));
   if (state === 'RUNNING') return { label: 'Tunnel up', title: 'Proxy service is running', detail: 'Verify TUN, routes, and real client traffic before relying on the tunnel.', cls: 'is-running' };
   if (state === 'ERROR') return { label: 'Safe mode', title: 'Service reports an error', detail: 'Check diagnostics or run recovery to restore normal routing.', cls: 'is-error' };
   return { label: 'Tunnel down', title: 'Proxy service is stopped', detail: 'The saved profile is preserved; router networking remains managed by OpenWrt.', cls: '' };
  }
  function pair(parent, label, value) {
   parent.appendChild(node('div', { class: 'cb-row' }, [node('dt', {}, [ _(label) ]), node('dd', {}, [ document.createTextNode(String(value)) ])]));
  }
  function renderProfile() {
   profileRows.innerHTML = '';
   if (!status.protocol) {
    profileRows.appendChild(node('div', { class: 'cb-empty' }, [ _('No saved connection details are available yet.') ]));
    return;
   }
   pair(profileRows, 'Protocol', text(status.protocol).toUpperCase());
   pair(profileRows, 'Server', text(status.server));
   pair(profileRows, 'Port', text(status.server_port));
   pair(profileRows, 'Transport', text(status.transport, 'TCP'));
   pair(profileRows, 'TLS', status.tls ? 'Enabled' : 'Disabled');
  }
  function renderSummary() {
   var state = currentState(status);
   pill.className = 'cb-state-pill ' + state.cls;
   pill.innerHTML = '';
   pill.appendChild(node('span', { class: 'cb-dot' }));
   pill.appendChild(document.createTextNode(state.label));
   summary.innerHTML = '';
   summary.appendChild(node('div', { class: 'cb-status-banner ' + state.cls }, [
    node('span', { class: 'cb-heading-mark' }, [ status.pending ? '!' : (status.running ? '✓' : '•') ]),
    node('div', {}, [node('strong', {}, [ _(state.title) ]), node('small', {}, [ _(state.detail) ])])
   ]));
   var grid = node('div', { class: 'cb-status-grid' });
   [
    ['Configuration', status.configuration_valid ? 'Valid' : (status.configured ? 'Invalid' : 'Not configured'), status.configuration_valid ? 'good' : 'bad'],
    ['TUN interface', status.running ? (status.tun ? 'Ready' : 'Missing') : 'Inactive', status.running && status.tun ? 'good' : ''],
    ['Routing', status.running ? (status.routing ? 'Ready' : 'Check required') : 'Inactive', status.running && status.routing ? 'good' : ''],
    ['Start at boot', status.auto_start ? 'Enabled' : 'Disabled', status.auto_start ? 'good' : '']
   ].forEach(function(row) {
    grid.appendChild(node('div', { class: 'cb-stat' }, [node('span', {}, [ _(row[0]) ]), node('strong', {}, [ badge(row[1], row[2]) ])]));
   });
   summary.appendChild(grid);
   startButton.disabled = busy || !!status.running || !status.configured || !!status.pending;
   stopButton.disabled = busy || !status.running;
   applyButton.disabled = busy || !!status.pending;
   confirmBox.innerHTML = '';
   if (status.pending) {
    confirmBox.appendChild(node('div', { class: 'cb-callout' }, [ _('Confirm only after verifying router access and real internet traffic. If the test fails, allow the rollback timer to expire.') ]));
    confirmBox.appendChild(button('Confirm configuration', confirmCurrent, 'cbi-button-action'));
   }
  }
  function renderSettings() {
   settingsRows.innerHTML = '';
   var autoLabel = node('label', { class: 'cb-option' }, [
    node('span', {}, [ _('Start automatically on boot') ]),
    node('span', { class: 'cb-switch' }, [ auto = node('input', { type: 'checkbox', checked: !!settings.auto_start, 'aria-label': _('Start automatically on boot') }), node('span') ])
   ]);
   var insecureLabel = node('label', { class: 'cb-option' }, [
    node('span', {}, [ _('Allow invalid TLS certificates') ]),
    node('span', { class: 'cb-switch' }, [ insecure = node('input', { type: 'checkbox', checked: !!settings.allow_insecure, 'aria-label': _('Allow invalid TLS certificates') }), node('span') ])
   ]);
   var ipv6Label = node('div', { class: 'cb-option' }, [
    node('span', {}, [ _('IPv6 policy') ]),
    ipv6 = node('select', {}, [
     node('option', { value: 'block', selected: (settings.ipv6_policy || 'block') === 'block' }, [ _('Block IPv6 to prevent bypass') ]),
     node('option', { value: 'proxy', selected: settings.ipv6_policy === 'proxy' }, [ _('Proxy IPv6 (requires verification)') ])
    ])
   ]);
   settingsRows.appendChild(autoLabel);
   settingsRows.appendChild(insecureLabel);
   settingsRows.appendChild(ipv6Label);
   settingsRows.appendChild(button('Save settings', saveSettings, 'cbi-button-action'));
  }
  function refresh() {
   return Promise.all([
    callStatus().catch(function() { return status; }),
    callLogs().catch(function() { return logs; }),
    callSettings().catch(function() { return settings; })
   ]).then(function(rows) {
    status = rows[0] || status; logs = rows[1] || logs; settings = rows[2] || settings;
    logBox.textContent = (logs.lines || []).join('\n') || _('No recent log entries.');
    renderSummary(); renderProfile(); renderSettings();
    return status;
   });
  }
  function run(promise, failure, success) {
   setBusy(true);
   return promise.then(function(result) {
    ensureOk(result, failure);
    if (success) notify(success);
    return refresh();
   }).catch(function(err) {
    notify(err.message || failure, 'error');
    return refresh();
   }).then(function(result) { setBusy(false); renderSummary(); return result; });
  }
  function detect() {
   var value = url.value.trim();
   if (!value) { notify('Paste a VMess or VLESS URL first.', 'error'); return; }
   setBusy(true);
   return callPreview({ proxy_url: value }).then(function(result) {
    if (!result || result.ok === false || !result.protocol) throw new Error(msg(result, 'Invalid or unsupported proxy URL.'));
    previewBox.className = 'cb-card';
    previewBox.innerHTML = '';
    previewBox.appendChild(node('div', { class: 'cb-card-head' }, [node('h2', {}, [node('span', { class: 'cb-heading-mark' }, ['↳']), _('Detected profile')]), badge(text(result.protocol).toUpperCase(), 'good')]));
    var dl = node('dl', { class: 'cb-rows' });
    [['Protocol', text(result.protocol).toUpperCase()], ['Server', text(result.server)], ['Port', text(result.server_port)], ['Transport', text(result.transport, 'TCP')], ['TLS', result.tls ? 'Enabled' : 'Disabled'], ['Profile name', text(result.name)]].forEach(function(p) { pair(dl, p[0], p[1]); });
    previewBox.appendChild(dl);
   }).catch(function(err) {
    previewBox.className = 'cb-card';
    previewBox.innerHTML = '';
    previewBox.appendChild(node('div', { class: 'alert-message error' }, [ document.createTextNode(err.message || _('Invalid proxy link.')) ]));
   }).then(function() { setBusy(false); renderSummary(); });
  }
  function apply() {
   if (!url.value.trim()) { notify('Paste a new VMess or VLESS URL before applying.', 'error'); return; }
   var value = url.value.trim();
   run(callApply({ proxy_url: value }), 'Failed to apply configuration.', 'Configuration applied. Confirm it before the safety timer expires.').then(function() { url.value = ''; return refresh(); });
  }
  function start() { run(callStart(), 'Failed to start service.', 'Service started.'); }
  function stop() { run(callStop(), 'Failed to stop service.', 'Service stopped; the saved profile is preserved.'); }
  function confirmCurrent() { run(callConfirm(), 'Confirmation failed.', 'Configuration confirmed.'); }
  function recover() {
   if (!window.confirm(_('Recovery stops proxy interception and attempts to restore direct router access. Continue?'))) return;
   run(rpc.declare({ object: 'luci.cowboy_bebop', method: 'recovery', expect: { '': {} } })(), 'Recovery failed.', 'Recovery completed.');
  }
  function saveSettings() {
   run(callSetSettings({ auto_start: !!auto.checked, allow_insecure: !!insecure.checked, ipv6_policy: ipv6.value }), 'Unable to save settings.', 'Settings saved.');
  }
  function refreshLogs() {
   setBusy(true);
   return callLogs().then(function(result) { logs = result || { lines: [] }; logBox.textContent = (logs.lines || []).join('\n') || _('No recent log entries.'); })
    .catch(function(err) { notify(err.message || 'Log refresh failed.', 'error'); })
    .then(function() { setBusy(false); });
  }

  pill = node('div', { class: 'cb-state-pill' });
  summary = node('div');
  profileRows = node('dl', { class: 'cb-rows' });
  settingsRows = node('div');
  confirmBox = node('div');
  logBox = node('pre', { class: 'cb-log' }, [ document.createTextNode((logs.lines || []).join('\n') || _('No recent log entries.')) ]);
  previewBox = node('div', { class: 'cb-card cb-empty' }, [ _('No preview yet. Paste a link and select Detect / Preview.') ]);
  url = node('textarea', { rows: 4, spellcheck: false, autocomplete: 'off', autocapitalize: 'off', placeholder: status.configured ? _('Saved profile is hidden; paste a new URL to replace it') : _('Paste a vmess:// or vless:// link') });

  previewButton = button('Detect / Preview', detect, 'cbi-button-action');
  applyButton = button('Save & Apply', apply, 'cbi-button-apply');
  startButton = button('ON / Start', start, 'cbi-button-action');
  stopButton = button('OFF / Stop', stop, 'cbi-button-negative');
  refreshButton = button('Refresh status', function() { run(callHealth(), 'Health check failed.', 'Health check completed.'); });
  logsButton = button('Refresh logs', refreshLogs);

  root.appendChild(node('div', { class: 'cb-page-head' }, [
   node('div', {}, [node('div', { class: 'cb-eyebrow' }, ['COWBOY BEBOP · NETWORK SERVICES']), node('h1', {}, [ _('Cowboy Bebop Manager') ]), node('p', { class: 'cb-intro' }, [ _('Manage the tunnel while keeping the original LuCI router interface intact.') ])]),
   pill
  ]));
  var grid = node('div', { class: 'cb-grid' });
  var left = node('div'), right = node('div');
  left.appendChild(node('section', { class: 'cb-card' }, [
   node('div', { class: 'cb-card-head' }, [node('h2', {}, [node('span', { class: 'cb-heading-mark' }, ['↗']), _('Connection profile')]), badge(status.configured ? 'Configured' : 'Not configured', status.configured ? 'good' : '')]),
   node('p', { class: 'cb-subtext' }, [ _('VMess and VLESS share links are supported; saved credentials are never sent back to the browser.') ]),
   node('label', { class: 'cb-form-label' }, [ _('Proxy URL') ]),
   url,
   node('div', { class: 'cb-input-help' }, [node('span', {}, [ _('Protocol and transport are detected automatically.') ]), node('span', {}, [ _('UUID hidden after apply.') ])]),
   node('div', { class: 'cb-actions' }, [previewButton, applyButton])
  ]));
  left.appendChild(previewBox);
  right.appendChild(node('section', { class: 'cb-card' }, [node('div', { class: 'cb-card-head' }, [node('h2', {}, [node('span', { class: 'cb-heading-mark' }, ['◉']), _('Service status')])]), summary, node('div', { class: 'cb-actions' }, [refreshButton])]));
  right.appendChild(node('section', { class: 'cb-card' }, [node('div', { class: 'cb-card-head' }, [node('h2', {}, [node('span', { class: 'cb-heading-mark' }, ['⇄']), _('Connection details')])]), profileRows]));
  right.appendChild(node('section', { class: 'cb-card' }, [node('div', { class: 'cb-card-head' }, [node('h2', {}, [node('span', { class: 'cb-heading-mark' }, ['⚙']), _('Service controls')])]), node('p', { class: 'cb-subtext' }, [ _('Turning the service off keeps the saved profile.') ]), confirmBox, node('div', { class: 'cb-actions' }, [startButton, stopButton]), node('div', { class: 'cb-callout' }, [ _('Confirm new routing only after testing real client traffic and router access.') ]), button('Run recovery', recover, 'cbi-button-negative')]));
  right.appendChild(node('section', { class: 'cb-card' }, [node('div', { class: 'cb-card-head' }, [node('h2', {}, [node('span', { class: 'cb-heading-mark' }, ['⚑']), _('Preferences')])]), settingsRows]));
  grid.appendChild(left); grid.appendChild(right); root.appendChild(grid);
  root.appendChild(node('section', { class: 'cb-card' }, [node('div', { class: 'cb-card-head' }, [node('h2', {}, [node('span', { class: 'cb-heading-mark' }, ['≡']), _('Recent logs')]), logsButton]), logBox]));
  renderSummary(); renderProfile(); renderSettings();
  return root;
 }
});
