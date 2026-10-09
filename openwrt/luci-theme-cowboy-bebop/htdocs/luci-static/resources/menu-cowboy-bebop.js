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
		this.enhanceContent();
		this.bindMobileSidebar();
	},

	renderError: function(err) {
		var nav = document.querySelector('#topmenu');
		if (!nav) return;

		nav.innerHTML = '';
		nav.appendChild(E('li', { 'class': 'cb-nav-error' }, [
			E('span', { 'class': 'cb-nav-icon', 'aria-hidden': 'true' }, ['!']),
			E('span', { 'class': 'cb-nav-label' }, [_('Menu unavailable')])
		]));
		L.error(err);
	},

	trailingSlash: function(url) {
		return url ? url.replace(/\/+$/, '') : '';
	},

	isActive: function(name, depth) {
		var path = L.env.requestpath || L.env.dispatchpath || [];
		return path.length > depth && path[depth] === name;
	},

	renderLevel: function(tree, container, url, depth) {
		var children = ui.menu.getChildren(tree);

		children.forEach(function(child) {
			var childUrl = url + '/' + child.name;
			var nested = ui.menu.getChildren(child);
			var hasChildren = nested.length > 0;
			var active = this.isActive(child.name, depth);
			var li = E('li', {
				'class': (hasChildren ? 'cb-nav-group ' : '') + (active ? 'active' : '')
			});

			if (hasChildren) {
				/* Native LuCI hierarchy stays fully expanded; no dropdown navigation. */
				var heading = E('div', {
					'class': 'cb-nav-group-heading'
				}, [
					E('span', { 'class': 'cb-nav-icon', 'aria-hidden': 'true' }, [this.iconFor(child.name)]),
					E('span', { 'class': 'cb-nav-label' }, [_(child.title)])
				]);
				li.appendChild(heading);

				var submenu = E('ul', {
					'class': 'cb-nav-submenu cb-nav-level-' + (depth + 1)
				});
				this.renderLevel(child, submenu, childUrl, depth + 1);
				li.appendChild(submenu);
			}
			else {
				li.appendChild(E('a', {
					'href': L.url(this.trailingSlash(childUrl)),
					'class': 'cb-nav-link'
				}, [
					E('span', { 'class': 'cb-nav-icon', 'aria-hidden': 'true' }, [this.iconFor(child.name)]),
					E('span', { 'class': 'cb-nav-label' }, [_(child.title)])
				]));
			}

			container.appendChild(li);
		}, this);
	},

	enhanceContent: function() {
		var headings = document.querySelectorAll('#maincontent h3, #maincontent h2');
		headings.forEach(function(heading) {
			var text = (heading.textContent || '').trim().toLowerCase();
			var icon = '•';
			if (text.indexOf('system') >= 0) icon = '◉';
			else if (text.indexOf('memory') >= 0) icon = '▦';
			else if (text.indexOf('storage') >= 0 || text.indexOf('disk') >= 0) icon = '▤';
			else if (text.indexOf('network') >= 0) icon = '⌁';
			else if (text.indexOf('port') >= 0 || text.indexOf('interface') >= 0) icon = '⇄';
			else if (text.indexOf('service') >= 0) icon = '⚙';
			else if (text.indexOf('status') >= 0) icon = '✓';
			heading.setAttribute('data-cb-icon', icon);
		});

		/* Do not render misleading empty values. Keep rows as soon as LuCI has real data. */
		var cleanEmpty = function() {
			document.querySelectorAll('#maincontent .cbi-value').forEach(function(row) {
				var field = row.querySelector('.cbi-value-field');
				if (!field) return;
				var text = (field.textContent || '').replace(/\u00a0/g, ' ').trim();
				if (!text && !field.querySelector('input, select, textarea, button, img, svg, iframe, canvas'))
					row.classList.add('cb-empty-value');
				else
					row.classList.remove('cb-empty-value');
			});
		};

		cleanEmpty();
		setTimeout(cleanEmpty, 150);
		setTimeout(cleanEmpty, 600);
		if (window.MutationObserver) {
			var target = document.querySelector('#maincontent');
			if (target) new MutationObserver(cleanEmpty).observe(target, { childList: true, subtree: true });
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

	iconFor: function(name) {
		var icons = {
			status: '✓',
			system: '⚙',
			services: '▦',
			network: '⌁',
			logout: '↪',
			admin: '⌂',
			interfaces: '⇄',
			firewall: '◈',
			dhcp: '⌁',
			routing: '↗',
			startup: '▶',
			software: '▤',
			backup: '↓',
			reboot: '↻'
		};
		return icons[name] || '•';
	}
});
