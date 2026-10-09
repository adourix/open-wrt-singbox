'use strict';
'require view';
'require rpc';
'require ui';
'require css';
'require css'('view/cowboy-bebop/overview.css');
var callStatus = rpc.declare({object:'luci.cowboy_bebop',method:'status',expect:{'':{}}});
var callHealth = rpc.declare({object:'luci.cowboy_bebop',method:'health',expect:{'':{}}});
var callLogs = rpc.declare({object:'luci.cowboy_bebop',method:'logs',expect:{'':{}}});
function node(tag,attrs,children){return E(tag,attrs||{},children||[]);}
function button(label,handler,cls){return node('button',{type:'button',class:'cbi-button '+(cls||''),click:handler},[_(label)]);}
function notify(text,type){ui.addNotification(null,E('p',[_ (text)]),type||'info');}
return view.extend({
 load:function(){return Promise.all([callStatus(),callLogs()]);},
 render:function(data){
  var status=data[0]||{}, logs=data[1]||{lines:[]}, root=node('div',{class:'cb-manager-page'});
  var logBox=node('pre',{class:'cb-log'},[document.createTextNode((logs.lines||[]).join('\n')||_('No recent logs.'))]);
  var rows=node('dl',{class:'cb-rows'});
  [['Service',status.state||(status.running?'RUNNING':'STOPPED')],['Configuration',status.configuration_valid?'Valid':(status.configured?'Invalid':'Not configured')],['TUN',status.tun?'Ready':'Inactive'],['Routing',status.routing?'Ready':'Inactive'],['Pending apply',status.pending?'Confirmation required':'None']].forEach(function(pair){
   rows.appendChild(node('div',{class:'cb-row'},[node('dt',{},[_(pair[0])]),node('dd',{},[String(pair[1])])]));
  });
  root.appendChild(node('div',{class:'cb-page-head'},[node('div',{},[node('div',{class:'cb-eyebrow'},['COWBOY BEBOP · DIAGNOSTICS']),node('h1',{},[_('Logs & diagnostics')]),node('p',{class:'cb-intro'},[_('Health checks and recent, redacted service logs.')])])]));
  root.appendChild(node('section',{class:'cb-card'},[
   node('div',{class:'cb-card-head'},[node('h2',{},[node('span',{class:'cb-heading-mark'},['✓']),_('Health checks')])]),
   rows,
   node('div',{class:'cb-actions'},[button('Run health check',function(){
    callHealth().then(function(r){if(!r||r.ok!==true)throw new Error(r&&r.error||'Health check failed.');notify('Health check completed.');}).catch(function(e){notify(e.message||'Health check failed.','error');});
   },'cbi-button-action')])
  ]));
  root.appendChild(node('section',{class:'cb-card'},[
   node('div',{class:'cb-card-head'},[node('h2',{},[node('span',{class:'cb-heading-mark'},['≡']),_('Recent service logs')]),button('Refresh',function(){
    callLogs().then(function(r){logBox.textContent=(r.lines||[]).join('\n')||_('No recent logs.');}).catch(function(){notify('Unable to refresh logs.','error');});
   })]),
   logBox
  ]));
  return root;
 }
});
