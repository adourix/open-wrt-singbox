'use strict';
'require view';
'require rpc';
'require ui';
'require css';
'require css'('view/cowboy-bebop/overview.css');

var callStatus = rpc.declare({ object: 'luci.cowboy_bebop', method: 'status', expect: { '': {} } });
var callSettings = rpc.declare({ object: 'luci.cowboy_bebop', method: 'settings', expect: { '': {} } });
var callSetSettings = rpc.declare({ object: 'luci.cowboy_bebop', method: 'set_settings', params: { auto_start: false, allow_insecure: false, ipv6_policy: '' }, expect: { '': {} } });
var callLogs = rpc.declare({ object: 'luci.cowboy_bebop', method: 'logs', expect: { '': {} } });
function node(tag, attrs, children) { return E(tag, attrs || {}, children || []); }
function button(label, handler, cls) { return node('button', { type: 'button', class: 'cbi-button ' + (cls || ''), click: handler }, [ _(label) ]); }
function notify(text, type) { ui.addNotification(null, E('p', [ _(text) ]), type || 'info'); }
return view.extend({
 load: function() { return Promise.all([callStatus(), callSettings(), callLogs()]); },
 render: function(data) {
  var status=data[0]||{}, settings=data[1]||{}, logs=data[2]||{lines:[]}, root=node('div',{class:'cb-manager-page'});
  var auto=node('input',{type:'checkbox',checked:!!settings.auto_start}), insecure=node('input',{type:'checkbox',checked:!!settings.allow_insecure});
  var ipv6=node('select',{},[
   node('option',{value:'block',selected:(settings.ipv6_policy||'block')==='block'},[_('Block IPv6 to prevent bypass')]),
   node('option',{value:'proxy',selected:settings.ipv6_policy==='proxy'},[_('Proxy IPv6 after end-to-end testing')])
  ]);
  var logBox=node('pre',{class:'cb-log'},[document.createTextNode((logs.lines||[]).join('\n')||_('No recent logs.'))]);
  function save(){
   callSetSettings({auto_start:!!auto.checked,allow_insecure:!!insecure.checked,ipv6_policy:ipv6.value}).then(function(r){
    if(!r||r.ok!==true)throw new Error(r&&r.error||'Unable to save settings.');
    notify('Settings saved.');
   }).catch(function(e){notify(e.message||'Unable to save settings.','error');});
  }
  root.appendChild(node('div',{class:'cb-page-head'},[node('div',{},[
   node('div',{class:'cb-eyebrow'},['COWBOY BEBOP · CONFIGURATION']),
   node('h1',{},[_('Configuration & preferences')]),
   node('p',{class:'cb-intro'},[_('App-specific tunnel settings. Native LuCI network, wireless, firewall and system pages are unchanged.')])
  ])]));
  root.appendChild(node('section',{class:'cb-card'},[
   node('div',{class:'cb-card-head'},[node('h2',{},[node('span',{class:'cb-heading-mark'},['⚙']),_('Runtime settings')])]),
   node('label',{class:'cb-option'},[node('span',{},[_('Start automatically on boot')]),node('span',{class:'cb-switch'},[auto,node('span')])]),
   node('label',{class:'cb-option'},[node('span',{},[_('Allow invalid TLS certificates')]),node('span',{class:'cb-switch'},[insecure,node('span')])]),
   node('div',{class:'cb-option'},[node('span',{},[_('IPv6 policy')]),ipv6]),
   button('Save settings',save,'cbi-button-action')
  ]));
  root.appendChild(node('section',{class:'cb-card'},[
   node('div',{class:'cb-card-head'},[node('h2',{},[node('span',{class:'cb-heading-mark'},['▤']),_('Current configuration')])]),
   node('dl',{class:'cb-rows'},[
    node('div',{class:'cb-row'},[node('dt',{},[_('Status')]),node('dd',{},[status.state||'STOPPED'])]),
    node('div',{class:'cb-row'},[node('dt',{},[_('Configuration')]),node('dd',{},[status.configuration_valid? _('Valid') : (status.configured? _('Invalid') : _('Not configured'))])]),
    node('div',{class:'cb-row'},[node('dt',{},[_('Profile')]),node('dd',{},[status.protocol?String(status.protocol).toUpperCase():'—'])]),
    node('div',{class:'cb-row'},[node('dt',{},[_('Server')]),node('dd',{},[status.server||'—'])]),
    node('div',{class:'cb-row'},[node('dt',{},[_('TUN')]),node('dd',{},[status.tun?'Ready':'Inactive'])]),
    node('div',{class:'cb-row'},[node('dt',{},[_('Routing')]),node('dd',{},[status.routing?'Ready':'Inactive'])])
   ])
  ]));
  root.appendChild(node('section',{class:'cb-card'},[
   node('div',{class:'cb-card-head'},[node('h2',{},[node('span',{class:'cb-heading-mark'},['≡']),_('Redacted log tail')]),button('Refresh',function(){
    callLogs().then(function(r){logBox.textContent=(r.lines||[]).join('\n')||_('No recent logs.');}).catch(function(){notify('Unable to refresh logs.','error');});
   })]),
   logBox
  ]));
  return root;
 }
});
