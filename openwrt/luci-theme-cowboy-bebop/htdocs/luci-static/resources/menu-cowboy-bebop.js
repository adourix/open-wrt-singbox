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
	},

	renderLevel: function(tree, container, url, depth) {
		var children = ui.menu.getChildren(tree);
		children.forEach(function(child) {
			var childUrl = url + '/' + child.name;
			var submenu = E('ul', { 'class': 'dropdown-menu' });
			var nested = depth < 1 ? ui.menu.getChildren(child) : [];
			var hasChildren = nested.length > 0;
			if (hasChildren) this.renderLevel(child, submenu, childUrl, depth + 1);
			var active = L.env.requestpath.length && child.name === L.env.requestpath[depth];
			var li = E('li', { 'class': (hasChildren ? 'dropdown ' : '') + (active ? 'active' : '') }, [
				E('a', { 'href': hasChildren ? '#' : L.url(childUrl), 'class': hasChildren ? 'menu' : '' }, [_(child.title)]),
				submenu
			]);
			container.appendChild(li);
		}, this);
	}
});
