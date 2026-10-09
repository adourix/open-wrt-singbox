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
		this.bindToggles(nav);
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
				var toggle = E('button', {
					'class': 'cb-nav-group-toggle',
					'type': 'button',
					'aria-expanded': active ? 'true' : 'false'
				}, [
					E('span', { 'class': 'cb-nav-icon', 'aria-hidden': 'true' }, [this.iconFor(child.name)]),
					E('span', { 'class': 'cb-nav-label' }, [_(child.title)]),
					E('span', { 'class': 'cb-nav-chevron', 'aria-hidden': 'true' }, ['›'])
				]);
				li.appendChild(toggle);

				var submenu = E('ul', {
					'class': 'cb-nav-submenu cb-nav-level-' + (depth + 1),
					'hidden': !active
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

	bindToggles: function(nav) {
		nav.querySelectorAll('.cb-nav-group-toggle').forEach(function(toggle) {
			toggle.addEventListener('click', function() {
				var group = toggle.parentNode;
				var submenu = group.querySelector(':scope > .cb-nav-submenu');
				var expanded = toggle.getAttribute('aria-expanded') === 'true';
				toggle.setAttribute('aria-expanded', expanded ? 'false' : 'true');
				if (submenu) submenu.hidden = expanded;
			});
		});
	},

	bindMobileSidebar: function() {
		var button = document.querySelector('.cb-sidebar-toggle');
		if (!button) return;

		button.addEventListener('click', function() {
			var open = document.body.classList.toggle('cb-sidebar-open');
			button.setAttribute('aria-expanded', open ? 'true' : 'false');
		});

		document.querySelectorAll('#topmenu a').forEach(function(link) {
			link.addEventListener('click', function() {
				document.body.classList.remove('cb-sidebar-open');
				button.setAttribute('aria-expanded', 'false');
			});
		});
	},

	iconFor: function(name) {
		var icons = {
			status: '◉',
			system: '⚙',
			services: '▣',
			network: '⌁',
			logout: '↪',
			admin: '⌂'
		};
		return icons[name] || '•';
	}
});
