'use strict';
'require view';
'require rpc';
'require ui';
'require css';
'require css'('view/cowboy-bebop/overview.css');
var callStatus=rpc.declare({object:'luci.cowboy_bebop',method:'status',expect:{'':{}}});
var callRecovery=rpc.declare({object:'luci.cowboy_bebop',method:'recovery',expect:{'':{}}});
var callStop=rpc.declare({object:'luci.cowboy_bebop',method:'stop',expect:{'':{}}});
var callConfirm=rpc.declare({object:'luci.cowboy_bebop',method:'confirm',expect:{'':{}}});
function node(tag,attrs,children){return E(tag,attrs||{},children||[]);}
function button(label,handler,cls){return node('button',{type:'button',class:'cbi-button '+(cls||''),click:handler},[_(label)]);}
function notify(text,type){ui.addNotification(null,E('p',[_ (text)]),type||'info');}
return view.extend({
 load:function(){return callStatus();},
 render:function(status){
  status=status||{};
  var root=node('div',{class:'cb-manager-page'});
  function execute(call,success){
   call().then(function(r){if(!r||r.ok!==true)throw new Error(r&&r.error||'Operation failed.');notify(success);location.reload();}).catch(function(e){notify(e.message||'Operation failed.','error');});
  }
  root.appendChild(node('div',{class:'cb-page-head'},[node('div',{},[node('div',{class:'cb-eyebrow'},['COWBOY BEBOP · SAFETY']),node('h1',{},[_('Recovery & rollback')]),node('p',{class:'cb-intro'},[_('Recover the router path without changing native LuCI network settings.')])])]));
  root.appendChild(node('section',{class:'cb-card'},[
   node('div',{class:'cb-card-head'},[node('h2',{},[node('span',{class:'cb-heading-mark'},['!']),_('Current safety state')])]),
   node('div',{class:'cb-status-banner '+(status.pending?'is-pending':(status.state==='ERROR'?'is-error':''))},[
    node('div',{},[node('strong',{},[status.pending? _('Configuration awaits confirmation'):(status.running? _('Proxy is running'):_('Proxy is stopped'))]),node('small',{},[status.pending? _('Confirm only after testing router access and real client connectivity. Otherwise allow automatic rollback.') : _('Recovery stops interception and attempts to restore direct routing.')])])
   ]),
   node('dl',{class:'cb-rows'},[
    node('div',{class:'cb-row'},[node('dt',{},[_('Saved profile')]),node('dd',{},[status.configured? _('Stored; credentials hidden'):_('Not configured')])]),
    node('div',{class:'cb-row'},[node('dt',{},[_('Configuration')]),node('dd',{},[status.configuration_valid?_('Valid'):_('Not confirmed or invalid')])]),
    node('div',{class:'cb-row'},[node('dt',{},[_('TUN / routing')]),node('dd',{},[status.tun&&status.routing?_('Present'):_('Not confirmed')])])
   ]),
   node('div',{class:'cb-actions'},[
    button('Run safe recovery',function(){
     if(!window.confirm(_('Recovery stops proxy interception and attempts to restore direct router access. Continue?')))return;
     execute(callRecovery,'Recovery completed.');
    },'cbi-button-negative'),
    button('Stop proxy',function(){execute(callStop,'Proxy stopped; the saved profile remains.');}),
    button('Confirm pending configuration',function(){
     if(!status.pending){notify('No pending configuration to confirm.','error');return;}
     if(!window.confirm(_('Confirm only after real connectivity tests. Continue?')))return;
     execute(callConfirm,'Configuration confirmed.');
    },'cbi-button-action')
   ]),
   node('div',{class:'cb-callout'},[_('A TUN interface alone is not proof of working proxy traffic. Verify a LAN client and router management access before confirming.')])
  ]));
  return root;
 }
});
