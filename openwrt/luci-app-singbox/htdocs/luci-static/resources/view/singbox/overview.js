'use strict';
'require view';
'require rpc';
'require ui';

var callStatus = rpc.declare({
	object: 'luci.singbox',
	method: 'status',
	expect: { '': {} }
});
var callPreview = rpc.declare({
	object: 'luci.singbox',
	method: 'preview',
	params: { proxy_url: '', allow_insecure: false },
	expect: { '': {} }
});
var callApply = rpc.declare({
	object: 'luci.singbox',
	method: 'apply',
	params: { proxy_url: '', auto_start: true, allow_insecure: false },
	expect: { '': {} }
});
var callStart = rpc.declare({
	object: 'luci.singbox',
	method: 'start',
	expect: { '': {} }
});
var callStop = rpc.declare({
	object: 'luci.singbox',
	method: 'stop',
	expect: { '': {} }
});
var callConfirm = rpc.declare({
	object: 'luci.singbox',
	method: 'confirm',
	expect: { '': {} }
});
var callLogs = rpc.declare({
	object: 'luci.singbox',
	method: 'logs',
	expect: { '': {} }
});

function button(label, cls, handler) {
	return E('button', {
		class: 'cbi-button ' + cls,
		click: handler
	}, [_(label)]);
}

return view.extend({
	load: function() {
		return Promise.all([callStatus(), callLogs()]);
	},

	render: function(data) {
		var status = data[0] || {};
		var logs = data[1] || { lines: [] };
		var page = E('div', { class: 'singbox-page' });
		var url = E('textarea', {
			class: 'cbi-input-text',
			rows: 3,
			spellcheck: false,
			autocomplete: 'off',
			placeholder: status.configured ? _('Saved - hidden') : _('vmess:// or vless://')
		});
		var auto = E('input', {
			type: 'checkbox',
			checked: !!status.auto_start
		});
		var allowInsecure = E('input', {
			type: 'checkbox',
			checked: !!status.allow_insecure
		});
		var previewBox = E('div', { class: 'cbi-section' });
		var statusBox = E('div', { class: 'cbi-section' });
		var actionBox = E('div', { class: 'cbi-page-actions' });
		var confirmBox = E('span', { style: 'margin-right:0.5em' });
		var logBox = E('pre', {
			style: 'max-height:240px;overflow:auto;white-space:pre-wrap;'
		}, [document.createTextNode((logs.lines || []).join('\n'))]);

		function errorText(result, fallback) {
			return result && result.error ? result.error : fallback;
		}

		function refresh() {
			return Promise.all([callStatus(), callLogs()]).then(function(results) {
				setStatus(results[0]);
				logBox.textContent = (results[1].lines || []).join('\n');
				return results[0];
			});
		}

		function setStatus(next) {
			status = next || {};
			statusBox.innerHTML = '';

			var state = status.state || (status.running ? 'RUNNING' : (status.enabled ? 'ERROR' : 'STOPPED'));
			var fields = [
				['Status', state.charAt(0) + state.slice(1).toLowerCase()],
				['Configuration', status.configuration_valid ? 'Valid' : 'Error'],
				['TUN', status.running ? (status.tun ? 'OK' : 'Error') : 'Inactive'],
				['Routing', status.running ? (status.routing ? 'OK' : 'Error') : 'Inactive']
			];
			if (status.protocol) fields.push(['Protocol', status.protocol.toUpperCase()]);
			if (status.server) fields.push(['Server', status.server]);
			if (status.server_port) fields.push(['Port', status.server_port]);
			if (status.transport) fields.push(['Transport', status.transport]);
			if (status.protocol) fields.push(['TLS', status.tls ? 'Enabled' : 'Disabled']);

			fields.forEach(function(field) {
				statusBox.appendChild(E('div', {}, [
					E('strong', {}, [_(field[0] + ': ')]),
					document.createTextNode(String(field[1]))
				]));
			});

			auto.checked = !!status.auto_start;
			allowInsecure.checked = !!status.allow_insecure;
			url.placeholder = status.configured ? _('Saved - hidden') : _('vmess:// or vless://');

			confirmBox.innerHTML = '';
			if (status.pending) {
				confirmBox.appendChild(button('Confirm', 'cbi-button-action', function() {
					return callConfirm().then(function(result) {
						if (!result || result.ok !== true)
							throw new Error(errorText(result, _('Confirmation failed.')));
						ui.addNotification(null, E('p', [_('Configuration confirmed.')]), 'info');
						return refresh();
					}).catch(function(err) {
						ui.addNotification(null, E('p', [_(err.message || _('Confirmation failed.'))]), 'error');
						return refresh();
					});
				}));
			}

			startButton.disabled = !!status.running || !status.configured || !!status.pending;
			stopButton.disabled = !status.running;
			apply.disabled = !!status.pending;
		}

		var preview = button('Detect / Preview', 'cbi-button-action', function() {
			var value = url.value.trim();
			if (!value) {
				ui.addNotification(null, E('p', [_('Paste a VMess or VLESS URL first.')]), 'error');
				return;
			}
			return callPreview({
				proxy_url: value,
				allow_insecure: !!allowInsecure.checked
			}).then(function(result) {
				if (!result || result.ok === false)
					throw new Error(errorText(result, _('Invalid or unsupported proxy URL.')));
				previewBox.innerHTML = '';
				[
					['Protocol', result.protocol],
					['Server', result.server],
					['Port', result.server_port],
					['Transport', result.transport],
					['TLS', result.tls ? 'Enabled' : 'Disabled'],
					['Name', result.name || '-']
				].forEach(function(field) {
					previewBox.appendChild(E('div', {}, [
						E('strong', {}, [_(field[0] + ': ')]),
						document.createTextNode(String(field[1]))
					]));
				});
			}).catch(function(err) {
				previewBox.innerHTML = '';
				previewBox.appendChild(E('p', {}, [_(err.message || _('Invalid or unsupported proxy URL.'))]));
			});
		});

		var apply = button('Save & Apply', 'cbi-button-apply', function() {
			var value = url.value.trim();
			if (!value) {
				ui.addNotification(null, E('p', [_('Paste a new VMess or VLESS URL to apply changes.')]), 'error');
				return;
			}
			return callApply({
				proxy_url: value,
				auto_start: !!auto.checked,
				allow_insecure: !!allowInsecure.checked
			}).then(function(result) {
				if (!result || result.ok !== true)
					throw new Error(errorText(result, _('Failed to apply configuration.')));
				url.value = '';
				previewBox.innerHTML = '';
				ui.addNotification(null, E('p', [_('Configuration applied. Confirm it before the safety timer expires.')]), 'info');
				return refresh();
			}).catch(function(err) {
				ui.addNotification(null, E('p', [err.message || _('Failed to apply configuration.')]), 'error');
				return refresh();
			});
		});

		var startButton = button('Start', 'cbi-button-action', function() {
			return callStart().then(function(result) {
				if (!result || result.ok !== true)
					throw new Error(errorText(result, _('Failed to start sing-box.')));
				return refresh();
			}).catch(function(err) {
				ui.addNotification(null, E('p', [_(err.message || _('Failed to start sing-box.'))]), 'error');
				return refresh();
			});
		});

		var stopButton = button('Stop', 'cbi-button-negative', function() {
			return callStop().then(function(result) {
				if (!result || result.ok !== true)
					throw new Error(errorText(result, _('Failed to stop sing-box.')));
				return refresh();
			}).catch(function(err) {
				ui.addNotification(null, E('p', [_(err.message || _('Failed to stop sing-box.'))]), 'error');
				return refresh();
			});
		});

		page.appendChild(E('h2', {}, [_('Sing-box')]));
		page.appendChild(E('div', { class: 'cbi-section' }, [
			E('div', { class: 'cbi-value' }, [
				E('label', { class: 'cbi-value-title' }, [_('Proxy URL')]),
				E('div', { class: 'cbi-value-field' }, [url])
			]),
			E('div', { class: 'cbi-value' }, [
				E('label', { class: 'cbi-value-title' }, [_('Allow insecure TLS')]),
				E('div', { class: 'cbi-value-field' }, [
					allowInsecure,
					E('span', { style: 'margin-left:0.5em' }, [_('Only enable when the URL explicitly requires skipping certificate verification.')])
				])
			]),
			E('div', { class: 'cbi-value' }, [
				E('label', { class: 'cbi-value-title' }, [_('Auto Start')]),
				E('div', { class: 'cbi-value-field' }, [auto])
			]),
			actionBox
		]));

		page.appendChild(E('h3', {}, [_('Profile Preview')]));
		page.appendChild(previewBox);
		page.appendChild(E('h3', {}, [_('Status')]));
		page.appendChild(statusBox);
		page.appendChild(E('h3', {}, [_('Logs')]));
		page.appendChild(logBox);

		actionBox.appendChild(preview);
		actionBox.appendChild(apply);
		actionBox.appendChild(confirmBox);
		actionBox.appendChild(startButton);
		actionBox.appendChild(stopButton);
		setStatus(status);

		return page;
	}
});
