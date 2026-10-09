'use strict';
'require rpc';

var callSystemInfo = rpc.declare({ object: 'system', method: 'info' });
var callSystemBoard = rpc.declare({ object: 'system', method: 'board' });
var callNetworkDump = rpc.declare({ object: 'network.interface', method: 'dump' });

function fmtBytes(value) {
	value = Number(value || 0);
	if (value < 1024) return value + ' B';
	if (value < 1024 * 1024) return (value / 1024).toFixed(1) + ' KB';
	if (value < 1024 * 1024 * 1024) return (value / 1024 / 1024).toFixed(1) + ' MB';
	return (value / 1024 / 1024 / 1024).toFixed(1) + ' GB';
}

function fmtUptime(seconds) {
	seconds = Number(seconds || 0);
	var days = Math.floor(seconds / 86400);
	seconds %= 86400;
	var hours = Math.floor(seconds / 3600);
	seconds %= 3600;
	var minutes = Math.floor(seconds / 60);
	if (days) return days + 'd ' + hours + 'h ' + minutes + 'm';
	if (hours) return hours + 'h ' + minutes + 'm';
	return minutes + 'm';
}

function statCard(label, value, meta) {
	return E('div', { 'class': 'cb-dashboard-stat' }, [
		E('div', { 'class': 'cb-dashboard-stat-label' }, [label]),
		E('div', { 'class': 'cb-dashboard-stat-value' }, [value]),
		E('div', { 'class': 'cb-dashboard-stat-meta' }, [meta || ''])
	]);
}

function interfaceCard(item) {
	var name = item.interface || item.name || 'interface';
	var up = item.up === true;
	var addresses = [];
	(item['ipv4-address'] || []).forEach(function(addr) {
		if (addr && addr.address) addresses.push(addr.address);
	});
	(item['ipv6-address'] || []).forEach(function(addr) {
		if (addr && addr.address && addresses.length < 2) addresses.push(addr.address);
	});
	return E('div', { 'class': 'cb-dashboard-interface' }, [
		E('div', { 'class': 'cb-dashboard-interface-head' }, [
			E('strong', {}, [String(name)]),
			E('span', { 'class': 'cb-dashboard-dot ' + (up ? 'up' : 'down') }, [up ? 'UP' : 'DOWN'])
		]),
		E('div', { 'class': 'cb-dashboard-interface-device' }, [String(item['l3_device'] || item.device || '—')]),
		E('div', { 'class': 'cb-dashboard-interface-address' }, [addresses.length ? addresses.join(' · ') : 'No address'])
	]);
}

function buildDashboard() {
	var path = L.env.dispatchpath || L.env.requestpath || [];
	if (path[1] !== 'status' || path[2] !== 'overview') return;

	var main = document.querySelector('#maincontent');
	if (!main || main.dataset.cbDashboardReady) return;
	main.dataset.cbDashboardReady = '1';

	main.querySelectorAll('.cbi-section').forEach(function(section) {
		var heading = section.querySelector('.cbi-title h3, .cbi-section-title h3, h3, h2, legend');
		if (!heading) return;
		var title = (heading.textContent || '').replace(/^(Hide|Show)\s*/i, '').trim().toLowerCase();
		if (/^(memory|storage|port status)$/.test(title)) section.remove();
	});

	var dashboard = E('section', { 'class': 'cb-dashboard' }, []);
	dashboard.appendChild(E('div', { 'class': 'cb-dashboard-head' }, [
		E('div', {}, [E('div', { 'class': 'cb-dashboard-eyebrow' }, ['SYSTEM OVERVIEW']), E('h2', {}, ['Router Health'])]),
		E('span', { 'class': 'cb-dashboard-live' }, [E('i', {}), 'LIVE'])
	]));

	var stats = E('div', { 'class': 'cb-dashboard-stats' }, []);
	stats.appendChild(statCard('Uptime', 'Loading…', 'System uptime'));
	stats.appendChild(statCard('Load', 'Loading…', '1 / 5 / 15 min'));
	stats.appendChild(statCard('Memory', 'Loading…', 'RAM usage'));
	stats.appendChild(statCard('Hostname', 'Loading…', 'Device identity'));
	dashboard.appendChild(stats);

	var networkPanel = E('div', { 'class': 'cb-dashboard-panel' }, [
		E('div', { 'class': 'cb-dashboard-panel-head' }, [E('h3', {}, ['Network Interfaces']), E('span', { 'class': 'cb-dashboard-muted' }, ['Live'])]),
		E('div', { 'class': 'cb-dashboard-interfaces' }, [E('div', { 'class': 'cb-dashboard-empty' }, ['Loading interfaces…'])])
	]);
	var systemPanel = E('div', { 'class': 'cb-dashboard-panel' }, [
		E('div', { 'class': 'cb-dashboard-panel-head' }, [E('h3', {}, ['System']), E('span', { 'class': 'cb-dashboard-muted' }, ['OpenWrt'])]),
		E('div', { 'class': 'cb-dashboard-system-list' }, [E('div', {}, ['Loading…'])])
	]);
	var grid = E('div', { 'class': 'cb-dashboard-grid' }, [networkPanel, systemPanel]);
	dashboard.appendChild(grid);

	var quick = E('div', { 'class': 'cb-dashboard-quick' }, [
		E('a', { 'href': L.url('admin/network/network') }, ['Network']),
		E('a', { 'href': L.url('admin/network/firewall') }, ['Firewall']),
		E('a', { 'href': L.url('admin/system/startup') }, ['Services']),
		E('a', { 'href': L.url('admin/system/packages') }, ['Software'])
	]);
	dashboard.appendChild(quick);
	main.insertBefore(dashboard, main.firstElementChild);

	Promise.all([callSystemInfo(), callSystemBoard(), callNetworkDump()]).then(function(results) {
		var info = results[0] || {};
		var board = results[1] || {};
		var network = results[2] || {};
		var memory = info.memory || {};
		var total = Number(memory.total || 0);
		var free = Number(memory.free || 0);
		var buffered = Number(memory.buffered || 0);
		var cached = Number(memory.cached || 0);
		var used = Math.max(0, total - free - buffered - cached);
		var percent = total ? Math.round((used / total) * 100) : 0;
		var load = (info.load || []).slice(0, 3).map(function(v) { return (Number(v) / 65536).toFixed(2); });
		var statValues = stats.querySelectorAll('.cb-dashboard-stat-value');
		statValues[0].textContent = fmtUptime(info.uptime);
		statValues[1].textContent = load.length ? load.join(' / ') : '—';
		statValues[2].textContent = total ? percent + '%' : '—';
		statValues[3].textContent = board.hostname || info.hostname || 'OpenWrt';

		var interfaces = network.interface || [];
		var interfaceList = networkPanel.querySelector('.cb-dashboard-interfaces');
		interfaceList.innerHTML = '';
		if (!interfaces.length) {
			interfaceList.appendChild(E('div', { 'class': 'cb-dashboard-empty' }, ['No network interfaces reported']));
		} else {
			interfaces.forEach(function(item) { interfaceList.appendChild(interfaceCard(item)); });
		}

		var systemList = systemPanel.querySelector('.cb-dashboard-system-list');
		systemList.innerHTML = '';
		[
			['Model', board.model || 'OpenWrt'],
			['Kernel', info.kernel || '—'],
			['Release', board.release && board.release.description ? board.release.description : '—'],
			['RAM', total ? fmtBytes(total) + ' total · ' + fmtBytes(used) + ' used' : '—']
		].forEach(function(row) {
			systemList.appendChild(E('div', {}, [E('span', {}, [row[0]]), E('strong', {}, [row[1]])]));
		});
	}).catch(function(err) {
		stats.querySelectorAll('.cb-dashboard-stat-value').forEach(function(node) { node.textContent = 'Unavailable'; });
		networkPanel.querySelector('.cb-dashboard-interfaces').innerHTML = '<div class="cb-dashboard-empty">System information unavailable</div>';
		L.error(err);
	});
}

setTimeout(buildDashboard, 0);
setTimeout(buildDashboard, 300);

return {};
