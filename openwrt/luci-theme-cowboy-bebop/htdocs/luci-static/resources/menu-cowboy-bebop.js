'use strict';
'require baseclass';
'require ui';

return baseclass.extend({
	__init__: function() {
		ui.menu.load().then(L.bind(this.render, this));
	},

	render: function(tree) {
		var nav = document.querySelector('#topmenu');
		if (!nav) return;
		nav.innerHTML = '';
		this.renderLevel(tree, nav, '', 0);
		this.bindToggles(nav);
	},

	railingSlash: function(url) {
		return url ? url.replace(/\/+$/, '') : '';
	},

	renderLevel: function(tree, container, url, depth) {
		var children = ui.menu.getChildren(tree);
		children.forEach(function(child) {
			var childUrl = url + '/' + child.name;
			var nested = depth < 1 ? ui.menu.getChildren(child) : [];
			var hasChildren = nested.length > 0;
			var active = L.env.requestpath.length && child.name === L.env.requestpath[depth];
			var li = E('li', { 'class': (hasChildren ? 'cb-nav-group ' : '') + (active ? 'active' : '') });

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
					'class': 'cb-nav-submenu',
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
