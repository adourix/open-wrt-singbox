'use strict';
'require view';
'require rpc';
'require ui';

var callStatus = rpc.declare({ object: 'luci.cowboy_bebop', method: 'status', expect: { '': {} } });
var callPreview = rpc.declare({ object: 'luci.cowboy_bebop', method: 'preview', params: { proxy_url: '' }, expect: { '': {} } });
var callApply = rpc.declare({ object: 'luci.cowboy_bebop', method: 'apply', params: { proxy_url: '' }, expect: { '': {} } });
var callStart = rpc.declare({ object: 'luci.cowboy_bebop', method: 'start', expect: { '': {} } });
var callStop = rpc.declare({ object: 'luci.cowboy_bebop', method: 'stop', expect: { '': {} } });
var callConfirm = rpc.declare({ object: 'luci.cowboy_bebop', method: 'confirm', expect: { '': {} } });
var callLogs = rpc.declare({ object: 'luci.cowboy_bebop', method: 'logs', expect: { '': {} } });

function button(label, cls, handler) {
	return E('button', { class: 'cbi-button ' + cls, click: handler }, [_(label)]);
}

function errorText(result, fallback) {
	return result && result.error ? result.error : fallback;
}

/* Self-contained styling: the page works with any LuCI theme (bootstrap,
 * material, openwrt2020, ...) and does not depend on a custom theme package. */
var PAGE_CSS = [
	'.cb-manager-page{max-width:960px}',
	'.cb-manager-hero h1{margin:.2em 0;font-size:1.6em}',
	'.cb-manager-hero p{opacity:.75;margin:0 0 1em}',
	'.cb-kicker{font-size:.75em;letter-spacing:.12em;opacity:.6;font-weight:600}',
	'.cb-config-card textarea{width:100%;box-sizing:border-box;font-family:monospace;min-height:5em}',
	'.cb-input-note{font-size:.85em;opacity:.7;margin:.25em 0 .5em}',
	'.cb-config-card .cbi-page-actions{display:flex;flex-wrap:wrap;gap:.5em;justify-content:flex-start;padding:.75em 0 0;margin:0;background:none;border:0}',
	'.cb-status-hero{padding:.75em 1em;border-radius:6px;border-left:4px solid #888;background:rgba(127,127,127,.08);margin-bottom:.75em}',
	'.cb-status-success{border-left-color:#2e9d50}.cb-status-warning{border-left-color:#d79a10}.cb-status-error{border-left-color:#d03b3b}.cb-status-neutral{border-left-color:#7a8594}',
	'.cb-status-label{font-weight:700;font-size:1.15em}.cb-status-subtitle{opacity:.75}',
	'.cb-status-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:.5em}',
	'.cb-status-item,.cb-profile-row{display:flex;justify-content:space-between;gap:1em;padding:.4em .6em;border-radius:4px;background:rgba(127,127,127,.06);word-break:break-all}',
	'.cb-status-item span,.cb-profile-row span{opacity:.7}',
	'.cb-profile-title{font-weight:600;margin-bottom:.4em}',
	'.cb-profile-row{margin-bottom:.3em}'
].join('\n');

function certificateLabel(value) {
	switch (value) {
	case 'pinned': return _('Pinned certificate');
	case 'not verified': return _('Not verified');
	case 'custom name': return _('Custom name');
	case 'reality': return _('Reality');
	case 'verified': return _('Verified');
	default: return value || '-';
	}
}

return view.extend({
	load: function() {
		return Promise.all([callStatus(), callLogs()]);
	},

	render: function(data) {
		var status = data[0] || {};
		var logs = data[1] || { lines: [] };
		var busy = false;

		var url = E('textarea', {
			class: 'cbi-input-text',
			rows: 3,
			spellcheck: false,
			autocomplete: 'off',
			placeholder: status.configured ? _('Saved - hidden') : _('vmess:// or vless://')
		});
		var previewBox = E('div', { class: 'cbi-section' });
		var statusBox = E('div', { class: 'cbi-section' });
		var actionBox = E('div', { class: 'cbi-page-actions' });
		var confirmBox = E('span', { class: 'cowboy-bebop-confirm' });
		var logBox = E('pre', { style: 'max-height:240px;overflow:auto;white-space:pre-wrap;' }, [document.createTextNode((logs.lines || []).join('\n'))]);

		function setBusy(value) {
			busy = value;
			[preview, apply, startButton, stopButton].forEach(function(node) {
				if (node) node.disabled = value;
			});
			url.disabled = value;
		}

		function refresh() {
			return Promise.all([callStatus(), callLogs()]).then(function(results) {
				setStatus(results[0]);
				logBox.textContent = (results[1].lines || []).join('\n');
				return results[0];
			});
		}

		function stateInfo(next) {
			var state = next.state || (next.running ? 'RUNNING' : (next.enabled ? 'ERROR' : 'STOPPED'));
			if (next.pending)
				return ['Confirm within 60 s', 'Auto-revert if no answer.', 'warning'];
			if (state === 'RUNNING')
				return ['Tunnel up', 'Smooth sailing.', 'success'];
			if (state === 'ERROR')
				return ['Safe mode', 'Direct routing restored.', 'error'];
			return ['Tunnel down', 'Router is on direct routes.', 'neutral'];
		}

		function setStatus(next) {
			status = next || {};
			statusBox.innerHTML = '';
			var info = stateInfo(status);

			statusBox.appendChild(E('div', { class: 'cb-status-hero cb-status-' + info[2] }, [
				E('div', { class: 'cb-status-label' }, [_(info[0])]),
				E('div', { class: 'cb-status-subtitle' }, [_(info[1])])
			]));

			var fields = [
				['Configuration', status.configuration_valid ? 'Valid' : 'Error'],
				['TUN', status.running ? (status.tun ? 'Ready' : 'Error') : 'Inactive'],
				['Routing', status.running ? (status.routing ? 'Ready' : 'Error') : 'Inactive']
			];
			if (status.protocol) fields.push(['Protocol', status.protocol.toUpperCase()]);
			if (status.server) fields.push(['Server', status.server]);
			if (status.server_port) fields.push(['Port', status.server_port]);
			if (status.transport) fields.push(['Transport', status.transport]);
			if (status.protocol) fields.push(['TLS', status.tls ? 'Enabled' : 'Disabled']);
			if (status.sni) fields.push(['SNI', status.sni]);
			if (status.certificate) fields.push(['Certificate', certificateLabel(status.certificate)]);

			var grid = E('div', { class: 'cb-status-grid' });
			fields.forEach(function(field) {
				grid.appendChild(E('div', { class: 'cb-status-item' }, [
					E('span', {}, [_(field[0])]),
					E('strong', {}, [document.createTextNode(String(field[1]))])
				]));
			});
			statusBox.appendChild(grid);

			url.placeholder = status.configured ? _('Saved - hidden') : _('vmess:// or vless://');
			confirmBox.innerHTML = '';
			if (status.pending) {
				confirmBox.appendChild(button('Confirm', 'cbi-button-action', function() {
					if (busy) return;
					setBusy(true);
					return callConfirm().then(function(result) {
						if (!result || result.ok !== true) throw new Error(errorText(result, _('Confirmation failed.')));
						ui.addNotification(null, E('p', [_('Configuration confirmed.')]), 'info');
						return refresh();
					}).catch(function(err) {
						ui.addNotification(null, E('p', [err.message || _('Confirmation failed.')]), 'error');
						return refresh();
					}).then(function(result) {
						setBusy(false);
						return result;
					});
				}));
			}
			startButton.disabled = busy || !!status.running || !status.configured || !!status.pending;
			stopButton.disabled = busy || !status.running;
			apply.disabled = busy || !!status.pending;
		}

		var preview = button('Detect / Preview', 'cbi-button-action', function() {
			if (busy) return;
			var value = url.value.trim();
			if (!value) {
				ui.addNotification(null, E('p', [_('Paste a VMess or VLESS URL first.')]), 'error');
				return;
			}
			setBusy(true);
			return callPreview({ proxy_url: value }).then(function(result) {
				if (!result || result.ok === false) throw new Error(errorText(result, _('Invalid or unsupported proxy URL.')));
				previewBox.innerHTML = '';
				previewBox.appendChild(E('div', { class: 'cb-profile-title' }, [_('Detected profile')]));
				[['Protocol', result.protocol], ['Server', result.server], ['Port', result.server_port], ['Transport', result.transport], ['TLS', result.tls ? 'Enabled' : 'Disabled'], ['SNI', result.sni || '-'], ['Certificate', result.tls ? certificateLabel(result.certificate) : '-'], ['Name', result.name || '-']].forEach(function(field) {
					previewBox.appendChild(E('div', { class: 'cb-profile-row' }, [
						E('span', {}, [_(field[0])]),
						E('strong', {}, [document.createTextNode(String(field[1]))])
					]));
				});
			}).catch(function(err) {
				previewBox.innerHTML = '';
				previewBox.appendChild(E('p', {}, [_(err.message || _('Invalid or unsupported proxy URL.'))]));
			}).then(function(result) {
				setBusy(false);
				return result;
			});
		});

		var apply = button('Save & Apply', 'cbi-button-apply', function() {
			if (busy) return;
			var value = url.value.trim();
			if (!value) {
				ui.addNotification(null, E('p', [_('Paste a new VMess or VLESS URL to apply changes.')]), 'error');
				return;
			}
			setBusy(true);
			statusBox.innerHTML = '';
			statusBox.appendChild(E('div', { class: 'cb-status-hero cb-status-warning' }, [
				E('div', { class: 'cb-status-label' }, [_('Checking configuration')]),
				E('div', { class: 'cb-status-subtitle' }, [_('Running validation.')])
			]));
			return callApply({ proxy_url: value }).then(function(result) {
				if (!result || result.ok !== true) throw new Error(errorText(result, _('Failed to apply configuration.')));
				url.value = '';
				previewBox.innerHTML = '';
				ui.addNotification(null, E('p', [_('Configuration applied. Confirm it before the safety timer expires.')]), 'info');
				return refresh();
			}).catch(function(err) {
				var reason = err.message || _('Failed to apply configuration.');
				var lines = [E('p', [_('Failed to apply configuration.')]), E('p', [_('Reason:') + ' ' + reason])];
				if (/roll(ing|ed) back/i.test(reason))
					lines.push(E('p', [_('Reverted to last good config. Nothing was lost.')]));
				ui.addNotification(null, E('div', lines), 'error');
				return refresh();
			}).then(function(result) {
				setBusy(false);
				return result;
			});
		});

		var startButton = button('Start', 'cbi-button-action', function() {
			if (busy) return;
			setBusy(true);
			return callStart().then(function(result) {
				if (!result || result.ok !== true) throw new Error(errorText(result, _('Failed to start service.')));
				return refresh();
			}).catch(function(err) {
				ui.addNotification(null, E('p', [err.message || _('Failed to start service.')]), 'error');
				return refresh();
			}).then(function(result) {
				setBusy(false);
				return result;
			});
		});

		var stopButton = button('Stop', 'cbi-button-negative', function() {
			if (busy) return;
			setBusy(true);
			return callStop().then(function(result) {
				if (!result || result.ok !== true) throw new Error(errorText(result, _('Failed to stop service.')));
				return refresh();
			}).catch(function(err) {
				ui.addNotification(null, E('p', [err.message || _('Failed to stop service.')]), 'error');
				return refresh();
			}).then(function(result) {
				setBusy(false);
				return result;
			});
		});

		var page = E('div', { class: 'cb-manager-page' }, [
			E('style', {}, [PAGE_CSS]),
			E('section', { class: 'cb-manager-hero' }, [
				E('div', {}, [
					E('div', { class: 'cb-kicker' }, [_('TUNNEL CONTROL')]),
					E('h1', {}, [_('Connection profile')]),
					E('p', {}, [_('Manage the active connection without exposing stored credentials.')])
				])
			]),
			E('section', { class: 'cbi-section cb-config-card' }, [
				E('label', { class: 'cbi-value-title' }, [_('Proxy URL')]),
				E('div', { class: 'cb-input-note' }, [_('VMess and VLESS share URLs are supported.')]),
				url,
				actionBox
			]),
			E('h3', {}, [_('Profile')]),
			previewBox,
			E('h3', {}, [_('Service status')]),
			statusBox,
			E('h3', {}, [_('Recent activity')]),
			logBox
		]);

		actionBox.appendChild(preview);
		actionBox.appendChild(startButton);
		actionBox.appendChild(apply);
		actionBox.appendChild(confirmBox);
		actionBox.appendChild(stopButton);
		setStatus(status);
		return page;
	}
});
