(function() {
  var $doc, $menu, EMPTY, NAV_MODE, READ_MODE, SEARCH_MODE, docco, log, mode, search, select, setup, _mode;

  READ_MODE = 'readmode.docco';

  NAV_MODE = 'navmode.docco';

  SEARCH_MODE = 'searchmode.docco';

  EMPTY = 'empty.docco';

  docco = {
    debug: true
  };

  window.docco = docco;

  _mode = null;

  $doc = $(document);

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
    start = this.$selectableItems().filter('.selected').first().index();
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
      top = this.$scroller.get(0).scrollTop;
      top += this._itemHeight * increment;
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

  setup = function() {
    mode(READ_MODE);
    $doc.bind('keydown', 't', function(e) {
      var _ref;
      if ((_ref = mode()) !== NAV_MODE && _ref !== SEARCH_MODE) {
        mode(NAV_MODE);
      } else {
        mode(SEARCH_MODE, true);
      }
      return e.preventDefault();
    }).bind('keydown', 'up', function(e) {
      var _ref;
      if ((_ref = mode()) === NAV_MODE || _ref === SEARCH_MODE) {
        $menu.select(-1);
        return e.preventDefault();
      }
    }).bind('keydown', 'down', function(e) {
      var _ref;
      if ((_ref = mode()) === NAV_MODE || _ref === SEARCH_MODE) {
        $menu.select(1);
        return e.preventDefault();
      }
    }).bind('keydown', 'return', function(e) {
      var $selected, _ref;
      if ((_ref = mode()) === NAV_MODE || _ref === SEARCH_MODE) {
        $selected = $menu.$selectableItems().filter('.selected').first();
        console.log("Going to selected `" + $selected + "`");
        if ($selected.length) document.location = $selected.attr('href');
        return e.preventDefault();
      }
    }).bind('keydown', 'esc', function(e) {
      switch (mode()) {
        case NAV_MODE:
          return mode(READ_MODE);
        case SEARCH_MODE:
          return mode(NAV_MODE);
      }
    }).on({
      click: function() {
        switch (mode()) {
          case NAV_MODE:
            return mode(READ_MODE);
          case SEARCH_MODE:
            return mode(NAV_MODE);
        }
      }
    }).on(READ_MODE, function() {
      return $menu.hide();
    }).on(NAV_MODE, function() {
      $menu.reset();
      return $menu.show();
    }).on(SEARCH_MODE, function() {
      return $menu.$searchField.focus();
    });
    $menu.on('click', function(e) {
      return e.stopPropagation();
    }).on(EMPTY, function(e, referrer) {
      e.stopPropagation();
      switch (referrer) {
        case 'search':
          if (docco.no_results_html) {
            return $menu.$itemWrapper().empty().html(docco.no_results_html);
          }
      }
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
          return mode(SEARCH_MODE);
        case 'blur':
          if (!$menu.$searchItems) return mode(NAV_MODE);
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
    return $menu.select();
  };

  $(function() {
    var logger;
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
        case SEARCH_MODE:
          if (this.$searchItems) return this.$searchItems;
          break;
        default:
          return this.$items;
      }
    };
    $menu.$searchItems = $();
    $menu.select = select;
    $menu.search = search;
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
    if (docco.debug === true) {
      window.$menu = $menu;
      logger = function() {
        return console.log.apply(console, arguments);
      };
      window.log = log = console.log.bind ? console.log.bind(logger) : logger;
    }
    return setup();
  });

}).call(this);
