'use strict';
'require view';
'require rpc';
'require ui';

var callStatus = rpc.declare({ object: 'luci.singbox', method: 'status', expect: { '': {} } });
var callSave = rpc.declare({ object: 'luci.singbox', method: 'save', params: { proxy_url: '', auto_start: true, ipv6_policy: '' } });
var callApply = rpc.declare({ object: 'luci.singbox', method: 'apply', expect: { '': {} } });
var callEnabled = rpc.declare({ object: 'luci.singbox', method: 'set_enabled', params: { enabled: true } });
var callLogs = rpc.declare({ object: 'luci.singbox', method: 'logs', expect: { '': {} } });

return view.extend({
    load: function() {
        return Promise.all([callStatus(), callLogs()]);
    },
    render: function(data) {
        var status = data[0] || {};
        var logs = data[1] || { lines: [] };
        var url = E('input', {
            type: 'password',
            class: 'cbi-input-text',
            autocomplete: 'off',
            placeholder: 'vmess:// or vless://'
        });
        var auto = E('input', { type: 'checkbox', checked: !!status.enabled });

        var statusBox = E('div', { class: 'cbi-section' });
        function updateStatus(s) {
            statusBox.innerHTML = '';
            [
                ['Enabled', s.enabled ? 'ON' : 'OFF'],
                ['Process', s.running ? 'OK' : 'STOPPED'],
                ['Configuration', s.configuration_valid ? 'OK' : 'ERROR'],
                ['TUN', s.tun ? 'OK' : 'ERROR'],
                ['Routing', s.routing ? 'OK' : 'ERROR']
            ].forEach(function (f) {
                statusBox.appendChild(E('div', {}, [
                    E('strong', {}, [_(f[0] + ': ')]),
                    document.createTextNode(f[1])
                ]));
            });
        }

        var save = E('button', {
            class: 'cbi-button cbi-button-save',
            click: function() {
                var value = url.value.trim();
                if (!value) {
                    ui.addNotification(null, E('p', _('Proxy URL is required.')), 'error');
                    return;
                }
                return callSave({ proxy_url: value, auto_start: auto.checked, ipv6_policy: 'block' })
                    .then(function() {
                        url.value = '';
                        ui.addNotification(null, E('p', _('Configuration saved.')), 'info');
                    })
                    .catch(function() {
                        ui.addNotification(null, E('p', _('Failed to save configuration.')), 'error');
                    });
            }
        }, [_('Save')]);

        var apply = E('button', {
            class: 'cbi-button cbi-button-apply',
            click: function() {
                return callApply().then(function() {
                    ui.addNotification(null, E('p', _('Configuration applied.')), 'info');
                    return callStatus();
                }).then(updateStatus).catch(function() {
                    ui.addNotification(null, E('p', _('Failed to apply configuration.')), 'error');
                });
            }
        }, [_('Save & Apply')]);

        var toggle = E('button', {
            class: 'cbi-button cbi-button-action',
            click: function() {
                var next = !auto.checked;
                return callEnabled({ enabled: next }).then(function() {
                    auto.checked = next;
                    return callStatus();
                }).then(updateStatus);
            }
        }, [_('ON / OFF')]);

        var logBox = E('pre', {
            style: 'max-height:360px;overflow:auto;white-space:pre-wrap;'
        }, [document.createTextNode((logs.lines || []).join('\n'))]);

        updateStatus(status);

        return E('div', { class: 'cbi-map' }, [
            E('h2', {}, [_('Sing-box')]),
            E('div', { class: 'cbi-section' }, [
                E('div', { class: 'cbi-value' }, [
                    E('label', { class: 'cbi-value-title' }, [_('Proxy URL')]),
                    E('div', { class: 'cbi-value-field' }, [url])
                ]),
                E('div', { class: 'cbi-value' }, [
                    E('label', { class: 'cbi-value-title' }, [_('Auto Start')]),
                    E('div', { class: 'cbi-value-field' }, [auto])
                ]),
                E('div', { class: 'cbi-page-actions' }, [save, apply, toggle])
            ]),
            E('h3', {}, [_('Status')]),
            statusBox,
            E('h3', {}, [_('Logs')]),
            logBox
        ]);
    }
});
