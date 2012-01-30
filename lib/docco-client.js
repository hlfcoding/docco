(function() {
  var $doc, $menu, $page, CREATE, DELETE, EMPTY, NAV, PURGE, READ, SEARCH, UPDATE, docco, log, mode, search, select, setup, store, _mode;

  READ = 'readmode.docco';

  NAV = 'navmode.docco';

  SEARCH = 'searchmode.docco';

  EMPTY = 'empty.docco';

  CREATE = 'create.docco';

  READ = 'read.docco';

  UPDATE = 'update.docco';

  DELETE = 'delete.docco';

  PURGE = 'purge.docco';

  docco = {
    debug: true
  };

  window.docco = docco;

  _mode = null;

  $doc = $(document);

  $page = null;

  $menu = null;

  log = $.noop;

  mode = function(constant, force) {
    if (force == null) force = false;
    if ((constant != null) && (constant !== _mode || force === true)) {
      _mode = constant;
      $doc.trigger(constant);
    }
    return _mode;
  };

  select = function(increment) {
    var index, last, start, top;
    if (increment == null) increment = 0;
    start = this.$selectedItem().index();
    if (start === -1) start = 0;
    last = this.$selectableItems().length - 1;
    index = start + increment;
    if (index < 0) {
      index = last;
    } else if (index > last) {
      index = 0;
    }
    this.$selectableItems().removeClass('selected').eq(index).addClass('selected');
    if (increment === 0) return;
    if (!this._hasScroll) {
      this._hasScroll = this.$itemWrapper().innerHeight() > this.innerHeight();
    }
    if (!this._itemHeight) {
      this._itemHeight = this.$selectableItems().first().outerHeight() + 1;
    }
    if (this._hasScroll === true) {
      top = this._itemHeight * index;
      if (index === last) {
        top = this.$itemWrapper().innerHeight() - this.innerHeight();
      } else if (index === 0) {
        top = 0;
      }
      this.$scroller.get(0).scrollTop = top;
    }
    return this;
  };

  search = function(query) {
    var results,
      _this = this;
    if (query == null) query = this.$searchField.val();
    results = 0;
    if (query != null) {
      this.$searchItems = this.$items.filter(":contains('" + query + "'), [data-path*='" + query + "']").clone();
      results = this.$searchItems.length;
      if (!!results) {
        this.$itemWrapper().fadeOut('fast', function() {
          _this.$items.detach();
          _this._didHeightFix = false;
          return _this.$itemWrapper().empty().append(_this.$searchItems).fadeIn('fast');
        });
      } else {
        this.trigger(EMPTY, ['search']);
      }
    }
    return this;
  };

  store = function(key, json) {
    if (!window.localStorage || !window.JSON) return;
    if (json != null) {
      try {
        log("json: " + (JSON.stringify(json)));
        if (json === false) {
          localStorage.removeItem(key);
        } else {
          localStorage.setItem(key, JSON.stringify(json));
        }
      } catch (error) {
        log(error);
        return false;
      }
    } else if (key != null) {
      if (key === false) {
        localStorage.clear();
      } else {
        return $.parseJSON(localStorage.getItem(key));
      }
    } else {
      return localStorage;
    }
    return this;
  };

  setup = function() {
    var html, stickies;
    mode(READ);
    $doc.bind('keydown', 't', function(e) {
      var _ref;
      if ((_ref = mode()) !== NAV && _ref !== SEARCH) {
        mode(NAV);
      } else {
        mode(SEARCH, true);
      }
      return e.preventDefault();
    }).bind('keydown', 's', function(e) {
      var $selected, _ref;
      if (((_ref = mode()) === NAV || _ref === SEARCH) && ($selected = $menu.$selectedItem()).length) {
        $menu.sticky(($selected.is('.sticky') ? DELETE : CREATE), $selected.data('path'));
      } else if (mode() === READ) {
        $menu.sticky(CREATE, $page.data('path'));
      }
      return e.preventDefault();
    }).bind('keydown', 'ctrl+q', function(e) {
      $menu.sticky(PURGE);
      return e.preventDefault();
    }).bind('keydown', 'up', function(e) {
      var _ref;
      if ((_ref = mode()) === NAV || _ref === SEARCH) {
        $menu.select(-1);
        return e.preventDefault();
      }
    }).bind('keydown', 'down', function(e) {
      var _ref;
      if ((_ref = mode()) === NAV || _ref === SEARCH) {
        $menu.select(1);
        return e.preventDefault();
      }
    }).bind('keydown', 'return', function(e) {
      var $selected, _ref;
      if ((_ref = mode()) === NAV || _ref === SEARCH) {
        $selected = $menu.$selectedItem();
        log("Going to selected `" + $selected + "`");
        if ($selected.length) document.location = $selected.attr('href');
        return e.preventDefault();
      }
    }).bind('keydown', 'esc', function(e) {
      switch (mode()) {
        case NAV:
          return mode(READ);
        case SEARCH:
          return mode(NAV);
      }
    }).on({
      click: function() {
        switch (mode()) {
          case NAV:
            return mode(READ);
          case SEARCH:
            return mode(NAV);
        }
      }
    }).on(READ, function() {
      return $menu.hide();
    }).on(NAV, function() {
      $menu.reset();
      return $menu.show();
    }).on(SEARCH, function() {
      return $menu.$searchField.focus();
    });
    $menu.on('click', function(e) {
      return e.stopPropagation();
    }).on(EMPTY, function(e, ref) {
      switch (ref) {
        case 'search':
          if (!!docco.no_results_tpl) {
            $menu.$itemWrapper().empty().html(docco.no_results_tpl());
          }
      }
      return e.stopPropagation();
    }).on(CREATE, function(e, ref, path) {
      switch (ref) {
        case 'sticky':
          if (!!docco.sticky_item_tpl) {
            $menu.stick($(docco.sticky_item_tpl({
              path: path,
              href: $menu.$items.filter("[data-path='" + path + "']").first().attr('href')
            })));
          }
      }
      return e.stopPropagation();
    }).on(DELETE, function(e, ref, path) {
      switch (ref) {
        case 'sticky':
          $menu.unstick(".sticky[data-path='" + path + "']:first");
      }
      return e.stopPropagation();
    }).on(PURGE, function(e, ref) {
      switch (ref) {
        case 'sticky':
          $menu.unstick(".sticky");
      }
      return e.stopPropagation();
    }).on('click', 'a', function(e) {
      if (mode() !== SEARCH) return;
      e.preventDefault();
      return e.stopPropagation();
    }).on('click', '.sticky .remove', function(e) {
      e.preventDefault();
      return $menu.sticky(DELETE, $(this).closest('.sticky').data('path'));
    });
    $menu.$navItems.on('click', function(e) {
      var $item;
      $item = $(this);
      e.preventDefault();
      if ($item.is('.selected')) return;
      $menu.$navItems.removeClass('selected');
      $menu.search($item.addClass('selected').data('path'));
      return $menu.$searchField.val($item.data('path')).blur();
    });
    $menu.$searchWrapper.on('submit', function(e) {
      $menu.search();
      $menu.$searchField.blur();
      return e.preventDefault();
    });
    $menu.$searchField.on('focus blur', function(e) {
      $menu.$clearSearch.toggle(!!$(this).val());
      switch (e.type) {
        case 'focus':
          return mode(SEARCH);
        case 'blur':
          if (!$menu.$searchItems) return mode(NAV);
      }
    });
    $menu.$clearSearch.click(function() {
      $menu.$searchField.val('');
      return $menu.reset();
    });
    $(window).on('resize', function() {
      if (!$menu._didHeightFix) return;
      $menu.$scroller.css('height', '100%');
      $menu._heightFixHeight = null;
      $menu._didHeightFix = false;
      if ($menu.is(':visible')) {
        $menu.hide();
        return $menu.show();
      }
    });
    stickies = $menu._store('sticky');
    if (!(stickies != null)) {
      $menu._store('sticky', {
        stickies: []
      });
    } else {
      html = [];
      $.each(stickies.stickies, function(i, path) {
        return html.push(docco.sticky_item_tpl({
          path: path,
          href: $menu.$items.filter("[data-path='" + path + "']").first().attr('href')
        }));
      });
      $menu.stick($(html.join('')));
    }
    return $menu.select();
  };

  $(function() {
    var logger;
    $page = $('#doc_page');
    $menu = $('#jump_wrapper');
    $menu.$itemWrapper = function() {
      return $menu.find('#jump_page');
    };
    $menu.$items = $menu.find('a.source');
    $menu.$navItems = $menu.find('#jump_dirs a.dir');
    $menu.$searchWrapper = $menu.find('#jump_search_wrapper');
    $menu.$searchField = $menu.find('#jump_search');
    $menu.$clearSearch = $menu.$searchWrapper.find('#clear_search');
    $menu.$scroller = $menu.find('#jump_scroller');
    $menu.$selectableItems = function() {
      switch (mode()) {
        case SEARCH:
          if (this.$searchItems) return this.$searchItems;
          break;
        default:
          return this.$items;
      }
    };
    $menu.$selectedItem = function() {
      return this.$selectableItems().filter('.selected').first();
    };
    $menu.$searchItems = $();
    $menu.select = select;
    $menu.search = search;
    $menu._store = store;
    $menu.sticky = function(act, id) {
      var did, i, stickies;
      if (act == null) act = READ;
      stickies = this._store('sticky').stickies;
      did = false;
      switch (act) {
        case CREATE:
          if ((id != null) && stickies.indexOf(id) === -1) {
            stickies.push(id);
            did = this._store('sticky', {
              stickies: stickies
            });
          }
          break;
        case DELETE:
          if ((id != null) && (i = stickies.indexOf(id)) !== -1) {
            stickies.splice(i, 1);
            did = this._store('sticky', {
              stickies: stickies
            });
          }
          break;
        case PURGE:
          this._store('sticky', {
            stickies: []
          });
          did = true;
          break;
        case READ:
          return this._store('sticky');
      }
      if (did) this.trigger(act, id != null ? ['sticky', id] : ['sticky']);
      return this;
    };
    $menu.stick = function($items) {
      this.$itemWrapper().prepend($items);
      return this.$items = this.$items.add($items);
    };
    $menu.unstick = function(filter) {
      this.$itemWrapper().find(filter).remove();
      return this.$items = this.$items.not(filter);
    };
    $menu.reset = function() {
      var _this = this;
      this.$searchField.blur();
      this.$itemWrapper().fadeOut('fast', function() {
        if (_this.$searchItems) {
          _this.$searchItems.remove();
          _this.$searchItems = null;
          _this._didHeightFix = false;
        }
        return _this.$itemWrapper().empty().append(_this.$items).fadeIn('fast');
      });
      return this;
    };
    $menu.show = function() {
      this.css('display', 'block');
      if (!this._didHeightFix) {
        if (!this._heightFixHeight) {
          if (this._heightFixHeight == null) {
            this._heightFixHeight = this.$scroller.height() - this.$searchWrapper.height() - 3;
          }
        }
        this.$scroller.height(this._heightFixHeight);
        this._didHeightFix = true;
      }
      return this;
    };
    $menu.hide = function() {
      this.css('display', 'none');
      this.attr('style', '');
      return this;
    };
    setup();
    if (docco.debug === true) {
      window.$menu = $menu;
      logger = function() {
        return console.log.apply(console, arguments);
      };
      return window.log = log = console.log.bind ? console.log.bind(logger) : logger;
    }
  });

}).call(this);
