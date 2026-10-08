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

return view.extend({
	load: function() { return Promise.all([callStatus(), callLogs()]); },
	render: function(data) {
		var status = data[0] || {};
		var logs = data[1] || { lines: [] };
		var busy = false;
		var page = E('div', { class: 'cowboy-bebop-page' });
		var url = E('textarea', { class: 'cbi-input-text', rows: 3, spellcheck: false, autocomplete: 'off', placeholder: status.configured ? _('Saved - hidden') : _('vmess:// or vless://') });
		var previewBox = E('div', { class: 'cbi-section' });
		var statusBox = E('div', { class: 'cbi-section' });
		var actionBox = E('div', { class: 'cbi-page-actions cowboy-bebop-primary-actions' });
		var confirmBox = E('span', { style: 'margin-right:0.5em' });
		var logBox = E('pre', { style: 'max-height:240px;overflow:auto;white-space:pre-wrap;' }, [document.createTextNode((logs.lines || []).join('\n'))]);

		if (!document.getElementById('cowboy-bebop-hide-generic-actions')) {
			var style = E('style', { id: 'cowboy-bebop-hide-generic-actions' }, [document.createTextNode('.cbi-page-actions:not(.cowboy-bebop-primary-actions){display:none!important;}')]);
			document.head.appendChild(style);
		}
		function errorText(result, fallback) { return result && result.error ? result.error : fallback; }
		function setBusy(value) {
			busy = value;
			[preview, apply, startButton, stopButton].forEach(function(buttonNode) { if (buttonNode) buttonNode.disabled = value; });
			if (confirmBox) confirmBox.style.opacity = value ? '0.5' : '1';
			url.disabled = value;
		}
		function refresh() {
			return Promise.all([callStatus(), callLogs()]).then(function(results) { setStatus(results[0]); logBox.textContent = (results[1].lines || []).join('\n'); return results[0]; });
		}
		function setStatus(next) {
			status = next || {};
			statusBox.innerHTML = '';
			var state = status.state || (status.running ? 'RUNNING' : (status.enabled ? 'ERROR' : 'STOPPED'));
			var fields = [['Status', state.charAt(0) + state.slice(1).toLowerCase()], ['Configuration', status.configuration_valid ? 'Valid' : 'Error'], ['TUN', status.running ? (status.tun ? 'OK' : 'Error') : 'Inactive'], ['Routing', status.running ? (status.routing ? 'OK' : 'Error') : 'Inactive']];
			if (status.protocol) fields.push(['Protocol', status.protocol.toUpperCase()]);
			if (status.server) fields.push(['Server', status.server]);
			if (status.server_port) fields.push(['Port', status.server_port]);
			if (status.transport) fields.push(['Transport', status.transport]);
			if (status.protocol) fields.push(['TLS', status.tls ? 'Enabled' : 'Disabled']);
			fields.forEach(function(field) { statusBox.appendChild(E('div', {}, [E('strong', {}, [_(field[0] + ': ')]), document.createTextNode(String(field[1]))])); });
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
					}).catch(function(err) { ui.addNotification(null, E('p', [_(err.message || _('Confirmation failed.'))]), 'error'); return refresh(); }).then(function(result) { setBusy(false); return result; });
				}));
			}
			startButton.disabled = busy || !!status.running || !status.configured || !!status.pending;
			stopButton.disabled = busy || !status.running;
			apply.disabled = busy || !!status.pending;
		}
		var preview = button('Detect / Preview', 'cbi-button-action', function() {
			if (busy) return;
			var value = url.value.trim();
			if (!value) { ui.addNotification(null, E('p', [_('Paste a VMess or VLESS URL first.')]), 'error'); return; }
			setBusy(true);
			return callPreview({ proxy_url: value }).then(function(result) {
				if (!result || result.ok === false) throw new Error(errorText(result, _('Invalid or unsupported proxy URL.')));
				previewBox.innerHTML = '';
				[['Protocol', result.protocol], ['Server', result.server], ['Port', result.server_port], ['Transport', result.transport], ['TLS', result.tls ? 'Enabled' : 'Disabled'], ['Name', result.name || '-']].forEach(function(field) { previewBox.appendChild(E('div', {}, [E('strong', {}, [_(field[0] + ': ')]), document.createTextNode(String(field[1]))])); });
			}).catch(function(err) { previewBox.innerHTML = ''; previewBox.appendChild(E('p', {}, [_(err.message || _('Invalid or unsupported proxy URL.'))])); }).then(function(result) { setBusy(false); return result; });
		});
		var apply = button('Save & Apply', 'cbi-button-apply', function() {
			if (busy) return;
			var value = url.value.trim();
			if (!value) { ui.addNotification(null, E('p', [_('Paste a new VMess or VLESS URL to apply changes.')]), 'error'); return; }
			setBusy(true);
			return callApply({ proxy_url: value }).then(function(result) {
				if (!result || result.ok !== true) throw new Error(errorText(result, _('Failed to apply configuration.')));
				url.value = ''; previewBox.innerHTML = '';
				ui.addNotification(null, E('p', [_('Configuration applied. Confirm it before the safety timer expires.')]), 'info');
				return refresh();
			}).catch(function(err) { ui.addNotification(null, E('p', [err.message || _('Failed to apply configuration.')]), 'error'); return refresh(); }).then(function(result) { setBusy(false); return result; });
		});
		var startButton = button('Start', 'cbi-button-action', function() {
			if (busy) return;
			setBusy(true);
			return callStart().then(function(result) { if (!result || result.ok !== true) throw new Error(errorText(result, _('Failed to start sing-box.'))); return refresh(); }).catch(function(err) { ui.addNotification(null, E('p', [_(err.message || _('Failed to start sing-box.'))]), 'error'); return refresh(); }).then(function(result) { setBusy(false); return result; });
		});
		var stopButton = button('Stop', 'cbi-button-negative', function() {
			if (busy) return;
			setBusy(true);
			return callStop().then(function(result) { if (!result || result.ok !== true) throw new Error(errorText(result, _('Failed to stop sing-box.'))); return refresh(); }).catch(function(err) { ui.addNotification(null, E('p', [_(err.message || _('Failed to stop sing-box.'))]), 'error'); return refresh(); }).then(function(result) { setBusy(false); return result; });
		});
		page.appendChild(E('h2', {}, [_('Cowboy Bebop Manager')]));
		page.appendChild(E('div', { class: 'cbi-section' }, [E('div', { class: 'cbi-value' }, [E('label', { class: 'cbi-value-title' }, [_('Proxy URL')]), E('div', { class: 'cbi-value-field' }, [url])]), actionBox]));
		page.appendChild(E('h3', {}, [_('Profile Preview')])); page.appendChild(previewBox);
		page.appendChild(E('h3', {}, [_('Status')])); page.appendChild(statusBox);
		page.appendChild(E('h3', {}, [_('Logs')])); page.appendChild(logBox);
		actionBox.appendChild(preview); actionBox.appendChild(startButton); actionBox.appendChild(apply); actionBox.appendChild(confirmBox); actionBox.appendChild(stopButton);
		setStatus(status); return page;
	}
});
