'use strict';
'require baseclass';
'require ui';

return baseclass.extend({
	__init__: function() {
		ui.menu.load().then(L.bind(this.render, this)).catch(L.bind(this.renderError, this));
	},

	render: function(tree) {
		var nav = document.querySelector('#topmenu');
		if (!nav) return;
		nav.innerHTML = '';
		var root = tree;
		if (tree.children && tree.children.admin) root = tree.children.admin;
		this.renderLevel(root, nav, 'admin', 0);
		this.renderTabs(tree);
		this.enhanceContent();
		this.bindMobileSidebar();
	},

	renderError: function(err) {
		var nav = document.querySelector('#topmenu');
		if (!nav) return;
		nav.innerHTML = '';
		nav.appendChild(E('li', { 'class': 'cb-nav-error' }, [
			E('span', { 'class': 'cb-nav-label' }, [_('Menu unavailable')])
		]));
		L.error(err);
	},

	isActive: function(name, depth) {
		var path = L.env.dispatchpath || L.env.requestpath || [];
		return path.length > depth && path[depth] === name;
	},

	urlFor: function(parent, child) {
		return parent ? L.url(parent, child.name) : L.url(child.name);
	},

	renderLevel: function(tree, container, url, depth) {
		var children = ui.menu.getChildren(tree);
		children.forEach(function(child) {
			var nested = ui.menu.getChildren(child);
			var hasChildren = nested.length > 0;
			var active = this.isActive(child.name, depth + 1);
			var li = E('li', { 'class': (hasChildren ? 'cb-nav-group ' : '') + (active ? 'active open' : '') });

			if (hasChildren) {
				var heading = E('button', {
					'class': 'cb-nav-group-heading', 'type': 'button',
					'aria-expanded': active ? 'true' : 'false', 'title': _(child.title)
				}, [this.iconSvg(child.name, true), E('span', { 'class': 'cb-nav-label' }, [_(child.title)])]);
				var submenu = E('ul', { 'class': 'cb-nav-submenu cb-nav-level-' + (depth + 1) });
				this.renderLevel(child, submenu, url ? url + '/' + child.name : child.name, depth + 1);
				heading.addEventListener('click', function() {
					var open = li.classList.toggle('open');
					heading.setAttribute('aria-expanded', open ? 'true' : 'false');
				});
				li.appendChild(heading);
				li.appendChild(submenu);
			}
			else {
				li.appendChild(E('a', { 'href': this.urlFor(url, child), 'class': 'cb-nav-link', 'title': _(child.title) }, [
					this.iconSvg(child.name, false), E('span', { 'class': 'cb-nav-label' }, [_(child.title)])
				]));
			}
			container.appendChild(li);
		}, this);
	},

	renderTabs: function(tree) {
		var container = document.querySelector('#tabmenu');
		if (!container || !L.env.dispatchpath || L.env.dispatchpath.length < 3) return;
		var node = tree, url = '';
		for (var i = 0; i < 3 && node; i++) {
			var name = L.env.dispatchpath[i];
			node = node.children ? node.children[name] : null;
			url = url ? url + '/' + name : name;
		}
		if (!node) return;
		var children = ui.menu.getChildren(node);
		if (!children.length) return;
		var ul = E('ul', { 'class': 'cb-tabmenu' });
		var current = L.env.dispatchpath[3] || '';
		children.forEach(function(child) {
			ul.appendChild(E('li', { 'class': current === child.name ? 'cbi-tab' : '' }, [E('a', { 'href': L.url(url, child.name) }, [_(child.title)])]));
		});
		container.innerHTML = '';
		container.appendChild(ul);
		container.style.display = '';
	},

	enhanceContent: function() {
		var headings = document.querySelectorAll('#maincontent h2, #maincontent h3');
		headings.forEach(function(heading) {
			if (heading.querySelector('.cb-heading-icon')) return;
			var text = (heading.textContent || '').trim().toLowerCase();
			var icon = 'default';
			if (/firewall|security|filter|rule/.test(text)) icon = 'firewall';
			else if (/dhcp|dns|lease/.test(text)) icon = 'dhcp';
			else if (/route|routing|gateway/.test(text)) icon = 'routing';
			else if (/interface|network|switch|bridge|port|ethernet|wireless|wifi/.test(text)) icon = 'network';
			else if (/service|daemon|process/.test(text)) icon = 'services';
			else if (/memory|ram|cpu|load|processor/.test(text)) icon = 'memory';
			else if (/storage|disk|mount|filesystem/.test(text)) icon = 'storage';
			else if (/software|package|packages|opkg|apk/.test(text)) icon = 'software';
			else if (/backup|restore/.test(text)) icon = 'backup';
			else if (/reboot|restart/.test(text)) icon = 'reboot';
			else if (/startup|boot/.test(text)) icon = 'startup';
			else if (/system|administration|admin/.test(text)) icon = 'system';
			else if (/status|overview|statistics|traffic/.test(text)) icon = 'status';
			var svg = this.iconSvg(icon, false);
			svg.classList.add('cb-heading-icon');
			heading.insertBefore(svg, heading.firstChild);
		}, this);
		this.polishStatusPanels();
		this.bindEmptyStatusFallback();
	},

	polishStatusPanels: function() {
		var main = document.querySelector('#maincontent');
		if (!main) return;
		main.querySelectorAll('.cbi-section-descr, .cbi-map-descr').forEach(function(node) {
			if (!node.children.length && !(node.textContent || '').trim()) node.style.display = 'none';
		});
	},

	statusSectionHasData: function(section) {
		var rows = section.querySelectorAll('table tr');
		if (!rows.length) return true;

		for (var i = 0; i < rows.length; i++) {
			var cells = rows[i].querySelectorAll('td');
			if (cells.length < 2) continue;
			var valueCell = cells[cells.length - 1];
			if (valueCell.querySelector('.cbi-progressbar, .cbi-progressbar > div, svg, canvas, img')) return true;
			var text = (valueCell.textContent || '').replace(/\s+/g, ' ').trim();
			if (text && text !== '?') return true;
		}
		return false;
	},

	bindEmptyStatusFallback: function() {
		var main = document.querySelector('#maincontent');
		if (!main || main.dataset.cbEmptyStatusFallback) return;
		main.dataset.cbEmptyStatusFallback = '1';

		var check = function() {
			main.querySelectorAll('.cbi-section').forEach(function(section) {
				var heading = section.querySelector('.cbi-title h3');
				if (!heading) return;
				var title = (heading.textContent || '').replace(/^(Hide|Show)\s*/i, '').trim().toLowerCase();
				if (!/^(memory|storage|port status)$/.test(title)) return;
				if (!section.querySelector('table')) return;
				var empty = !this.statusSectionHasData(section);
				section.classList.toggle('cb-status-empty', empty);
				section.style.display = empty ? 'none' : '';
			}, this);
		};

		check();
		setTimeout(check, 1200);
		setTimeout(check, 3000);

		if (typeof MutationObserver === 'function') {
			var observer = new MutationObserver(function() { check(); });
			observer.observe(main, { childList: true, subtree: true, characterData: true });
			setTimeout(function() { observer.disconnect(); }, 10000);
		}
	},

	bindMobileSidebar: function() {
		var button = document.querySelector('.cb-sidebar-toggle');
		if (!button) return;
		button.onclick = function() {
			var open = document.body.classList.toggle('cb-sidebar-open');
			button.setAttribute('aria-expanded', open ? 'true' : 'false');
		};
		document.querySelectorAll('#topmenu a').forEach(function(link) {
			link.addEventListener('click', function() {
				document.body.classList.remove('cb-sidebar-open');
				button.setAttribute('aria-expanded', 'false');
			});
		});
	},

	iconSvg: function(name, group) {
		var paths = {
			status:'M3 12h4l2-7 4 14 2-7h6', system:'M9 4h6v4H9zM6 10h12v10H6zM9 14h6M9 17h4',
			services:'M4 5h16v14H4zM8 9h8M8 13h5M8 16h3', network:'M4 5h6v6H4zM14 13h6v6h-6zM10 8h4M17 11v2M10 8v6h4',
			interfaces:'M4 7h16M4 12h16M4 17h16M7 5v4M12 10v4M17 15v4', firewall:'M12 3l7 3v5c0 4.4-2.7 7.8-7 10-4.3-2.2-7-5.6-7-10V6zM9 12l2 2 4-4',
			dhcp:'M4 6h16M4 12h16M4 18h10M7 4v4M12 10v4M17 16v4', routing:'M5 19 19 5M19 5v6M19 5h-6M5 5v5M5 5h5', startup:'M7 4v16l12-8z',
			software:'M5 4h14v16H5zM8 8h8M8 12h8M8 16h5', backup:'M12 4v11m0 0-4-4m4 4 4-4M5 20h14', reboot:'M19 8a8 8 0 1 0 1 5M19 4v4h-4',
			logout:'M10 5H5v14h5M14 8l5 4-5 4M19 12H9', admin:'M12 3l7 7-7 7-7-7z', memory:'M5 6h14v12H5zM8 3v3m4-3v3m4-3v3M8 18v3m4-3v3m4-3v3',
			storage:'M5 5h14v14H5zM8 9h8M8 13h8M8 16h5', vpn:'M5 7h14M5 12h14M5 17h14M8 4v3M16 17v3',
			wireless:'M4 10c4.4-4.4 11.6-4.4 16 0M7 13c2.8-2.8 7.2-2.8 10 0M10 16c1.1-1.1 2.9-1.1 4 0M12 20h.01',
			logs:'M6 4h12v16H6zM9 8h6M9 12h6M9 16h4', default:'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18z'
		};
		var d = paths[name] || paths.default;
		return E('svg', {'class':'cb-nav-svg' + (group ? ' cb-nav-svg-group' : ''),'viewBox':'0 0 24 24','aria-hidden':'true','focusable':'false'}, [E('path', {'d':d})]);
	}
});
