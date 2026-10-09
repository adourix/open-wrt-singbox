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
		this.renderLevel(tree, nav, '', 0);
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
			var active = this.isActive(child.name, depth);
			var li = E('li', { 'class': (hasChildren ? 'cb-nav-group ' : '') + (active ? 'active' : '') });
			var href = this.urlFor(url, child);

			if (hasChildren) {
				li.appendChild(E('a', { 'class': 'cb-nav-group-heading', 'href': href, 'title': _(child.title) }, [
					this.iconSvg(child.name, true),
					E('span', { 'class': 'cb-nav-label' }, [_(child.title)])
				]));
				var submenu = E('ul', { 'class': 'cb-nav-submenu cb-nav-level-' + (depth + 1) });
				this.renderLevel(child, submenu, url ? url + '/' + child.name : child.name, depth + 1);
				li.appendChild(submenu);
			}
			else {
				li.appendChild(E('a', { 'href': href, 'class': 'cb-nav-link', 'title': _(child.title) }, [
					this.iconSvg(child.name, false),
					E('span', { 'class': 'cb-nav-label' }, [_(child.title)])
				]));
			}
			container.appendChild(li);
		}, this);
	},

	renderTabs: function(tree) {
		var container = document.querySelector('#tabmenu');
		if (!container || !L.env.dispatchpath || L.env.dispatchpath.length < 3) return;

		var node = tree;
		var url = '';
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
			var active = current === child.name;
			ul.appendChild(E('li', { 'class': active ? 'cbi-tab' : '' }, [
				E('a', { 'href': L.url(url, child.name) }, [_(child.title)])
			]));
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
			if (text.indexOf('system') >= 0) icon = 'system';
			else if (text.indexOf('memory') >= 0) icon = 'memory';
			else if (text.indexOf('storage') >= 0 || text.indexOf('disk') >= 0) icon = 'storage';
			else if (text.indexOf('network') >= 0 || text.indexOf('interface') >= 0 || text.indexOf('port') >= 0) icon = 'network';
			else if (text.indexOf('service') >= 0) icon = 'services';
			else if (text.indexOf('status') >= 0) icon = 'status';
			var svg = this.iconSvg(icon, false);
			svg.classList.add('cb-heading-icon');
			heading.insertBefore(svg, heading.firstChild);
		}, this);

		var cleanEmpty = function() {
			document.querySelectorAll('#maincontent .cbi-value').forEach(function(row) {
				var field = row.querySelector('.cbi-value-field');
				if (!field) return;
				var text = (field.textContent || '').replace(/\u00a0/g, ' ').trim();
				if (!text && !field.querySelector('input, select, textarea, button, img, svg, iframe, canvas')) row.classList.add('cb-empty-value');
				else row.classList.remove('cb-empty-value');
			});
		};
		cleanEmpty();
		setTimeout(cleanEmpty, 150);
		setTimeout(cleanEmpty, 600);
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
			status:'M4 12h3l2-7 4 14 2-7h5',
			system:'M12 2v3m0 14v3M2 12h3m14 0h3M4.9 4.9l2.1 2.1m10 10 2.1 2.1M19.1 4.9 17 7m-10 10-2.1 2.1',
			services:'M4 5h16v14H4zM8 9h8M8 13h5',
			network:'M5 5h5v5H5zM14 14h5v5h-5zM10 7.5h4M16.5 10v4',
			interfaces:'M5 7h14M5 12h14M5 17h14',
			firewall:'M12 3l7 3v5c0 4.5-2.8 7.8-7 10-4.2-2.2-7-5.5-7-10V6z',
			dhcp:'M4 6h16M4 12h16M4 18h10',
			routing:'M5 19 19 5M19 5v6M19 5h-6',
			startup:'M8 5v14l11-7z',
			software:'M5 4h14v16H5zM8 8h8M8 12h8M8 16h5',
			backup:'M12 4v11m0 0-4-4m4 4 4-4M5 20h14',
			reboot:'M19 8a8 8 0 1 0 1 5',
			logout:'M10 5H5v14h5M14 8l5 4-5 4M19 12H9',
			admin:'M12 3l7 7-7 7-7-7z',
			memory:'M5 6h14v12H5zM8 3v3m4-3v3m4-3v3M8 18v3m4-3v3m4-3v3',
			storage:'M5 5h14v14H5zM8 9h8M8 13h8',
			default:'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18z'
		};
		var d = paths[name] || paths.default;
		return E('svg', { 'class':'cb-nav-svg' + (group ? ' cb-nav-svg-group' : ''), 'viewBox':'0 0 24 24', 'aria-hidden':'true', 'focusable':'false' }, [E('path', { 'd':d })]);
	}
});
