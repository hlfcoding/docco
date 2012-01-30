(function() {
  var $doc, $menu, $page, CREATE, DELETE, EMPTY, NAV, PURGE, READ, SEARCH, UPDATE, docco, log, mode, prevent, search, select, setup, stop, store, _mode;

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

  stop = function(e) {
    return e.stopPropagation();
  };

  prevent = function(e) {
    return e.preventDefault();
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
    var html, stickies,
      _this = this;
    mode(READ);
    $doc.bind('keydown', 't', function(e) {
      var _ref;
      if ((_ref = mode()) !== NAV && _ref !== SEARCH) {
        mode(NAV);
      } else {
        mode(SEARCH, true);
      }
      return prevent(e);
    }).bind('keydown', 's', function(e) {
      var $selected, _ref;
      if (((_ref = mode()) === NAV || _ref === SEARCH) && ($selected = _this.$selectedItem()).length) {
        _this.sticky(($selected.is('.sticky') ? DELETE : CREATE), $selected.data('path'));
      } else if (mode() === READ) {
        _this.sticky(CREATE, $page.data('path'));
      }
      return prevent(e);
    }).bind('keydown', 'ctrl+q', function(e) {
      _this.sticky(PURGE);
      return prevent(e);
    }).bind('keydown', 'up', function(e) {
      var _ref;
      if ((_ref = mode()) === NAV || _ref === SEARCH) {
        _this.select(-1);
        return prevent(e);
      }
    }).bind('keydown', 'down', function(e) {
      var _ref;
      if ((_ref = mode()) === NAV || _ref === SEARCH) {
        _this.select(1);
        return prevent(e);
      }
    }).bind('keydown', 'return', function(e) {
      var $selected, _ref;
      if ((_ref = mode()) === NAV || _ref === SEARCH) {
        $selected = _this.$selectedItem();
        log("Going to selected `" + $selected + "`");
        if ($selected.length) document.location = $selected.attr('href');
        return prevent(e);
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
      return _this.hide();
    }).on(NAV, function() {
      _this.reset();
      return _this.show();
    }).on(SEARCH, function() {
      return _this.$searchField.focus();
    });
    this.on('click', function(e) {
      return stop(e);
    }).on(EMPTY, function(e, ref) {
      switch (ref) {
        case 'search':
          if (!!docco.no_results_tpl) {
            _this.$itemWrapper().empty().html(docco.no_results_tpl());
          }
      }
      return stop(e);
    }).on(CREATE, function(e, ref, path) {
      switch (ref) {
        case 'sticky':
          if (!!docco.sticky_item_tpl) {
            _this.stick($(docco.sticky_item_tpl({
              path: path,
              href: _this.$items.filter("[data-path='" + path + "']").first().attr('href')
            })));
          }
      }
      return stop(e);
    }).on(DELETE, function(e, ref, path) {
      switch (ref) {
        case 'sticky':
          _this.unstick(".sticky[data-path='" + path + "']:first");
      }
      return stop(e);
    }).on(PURGE, function(e, ref) {
      switch (ref) {
        case 'sticky':
          _this.unstick(".sticky");
      }
      return stop(e);
    }).on('click', 'a', function(e) {
      if (mode() !== SEARCH) return;
      prevent(e);
      return stop(e);
    }).on('click', '.sticky .remove', function(e) {
      prevent(e);
      return _this.sticky(DELETE, $(e.target).closest('.sticky').data('path'));
    });
    this.$navItems.on('click', function(e) {
      var $item;
      $item = $(e.target);
      prevent(e);
      if ($item.is('.selected')) return;
      _this.$navItems.removeClass('selected');
      _this.search($item.addClass('selected').data('path'));
      return _this.$searchField.val($item.data('path')).blur();
    });
    this.$searchWrapper.on('submit', function(e) {
      _this.search();
      _this.$searchField.blur();
      return prevent(e);
    });
    this.$searchField.on('focus blur', function(e) {
      _this.$clearSearch.toggle(!!$(e.target).val());
      switch (e.type) {
        case 'focus':
          return mode(SEARCH);
        case 'blur':
          if (!_this.$searchItems) return mode(NAV);
      }
    });
    this.$clearSearch.on('click', function() {
      _this.$searchField.val('');
      _this.$searchItems;
      return _this.reset();
    });
    $(window).on('resize', function() {
      if (!_this._didHeightFix) return;
      _this.$scroller.css('height', '100%');
      _this._heightFixHeight = null;
      _this._didHeightFix = false;
      if (_this.is(':visible')) {
        _this.hide();
        return _this.show();
      }
    });
    stickies = this._store('sticky');
    if (!(stickies != null)) {
      this._store('sticky', {
        stickies: []
      });
    } else {
      html = [];
      $.each(stickies.stickies, function(i, path) {
        return html.push(docco.sticky_item_tpl({
          path: path,
          href: _this.$items.filter("[data-path='" + path + "']").first().attr('href')
        }));
      });
      this.stick($(html.join('')));
    }
    return this.select();
  };

  $(function() {
    var f, logger;
    $page = $('#doc_page');
    $menu = $('#jump_wrapper');
    f = function() {
      var _this = this;
      this.$itemWrapper = function() {
        return _this.find('#jump_page');
      };
      this.$items = this.find('a.source');
      this.$navItems = this.find('#jump_dirs a.dir');
      this.$searchWrapper = this.find('#jump_search_wrapper');
      this.$searchField = this.find('#jump_search');
      this.$clearSearch = this.$searchWrapper.find('#clear_search');
      this.$scroller = this.find('#jump_scroller');
      this.$selectableItems = function() {
        switch (mode()) {
          case SEARCH:
            if (_this.$searchItems && _this.$searchItems.length) {
              return _this.$searchItems;
            }
            break;
          default:
            return _this.$items;
        }
      };
      this.$selectedItem = function() {
        return _this.$selectableItems().filter('.selected').first();
      };
      this.$searchItems = $();
      this.select = select;
      this.search = search;
      this._store = store;
      this.sticky = function(act, id) {
        var did, i, stickies;
        if (act == null) act = READ;
        stickies = _this._store('sticky').stickies;
        did = false;
        switch (act) {
          case CREATE:
            if ((id != null) && stickies.indexOf(id) === -1) {
              stickies.push(id);
              did = _this._store('sticky', {
                stickies: stickies
              });
            }
            break;
          case DELETE:
            if ((id != null) && (i = stickies.indexOf(id)) !== -1) {
              stickies.splice(i, 1);
              did = _this._store('sticky', {
                stickies: stickies
              });
            }
            break;
          case PURGE:
            _this._store('sticky', {
              stickies: []
            });
            did = true;
            break;
          case READ:
            return _this._store('sticky');
        }
        if (did) _this.trigger(act, id != null ? ['sticky', id] : ['sticky']);
        return _this;
      };
      this.stick = function($items) {
        _this.$itemWrapper().prepend($items);
        return _this.$items = _this.$items.add($items);
      };
      this.unstick = function(filter) {
        _this.$itemWrapper().find(filter).remove();
        return _this.$items = _this.$items.not(filter);
      };
      this.reset = function() {
        _this.$searchField.blur();
        _this.$itemWrapper().fadeOut('fast', function() {
          if (_this.$searchItems) {
            _this.$searchItems.remove();
            _this.$searchItems = null;
            _this._didHeightFix = false;
          }
          return _this.$itemWrapper().empty().append(_this.$items).fadeIn('fast');
        });
        return _this;
      };
      this.show = function() {
        _this.css('display', 'block');
        if (!_this._didHeightFix) {
          if (!_this._heightFixHeight) {
            if (_this._heightFixHeight == null) {
              _this._heightFixHeight = _this.$scroller.height() - _this.$searchWrapper.height() - 3;
            }
          }
          _this.$scroller.height(_this._heightFixHeight);
          _this._didHeightFix = true;
        }
        return _this;
      };
      this.hide = function() {
        _this.css('display', 'none');
        _this.attr('style', '');
        return _this;
      };
      return setup.call(this);
    };
    f.call($menu);
    if (docco.debug === true) {
      window.$menu = $menu;
      logger = function() {
        return console.log.apply(console, arguments);
      };
      return window.log = log = console.log.bind ? console.log.bind(logger) : logger;
    }
  });

}).call(this);
