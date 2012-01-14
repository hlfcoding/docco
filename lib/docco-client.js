(function() {
  var $doc, $menu, NAV_MODE, READ_MODE, docco, mode, select, setup, _mode;

  READ_MODE = 'readmode.docco';

  NAV_MODE = 'navmode.docco';

  docco = {
    debug: true
  };

  window.docco = docco;

  _mode = null;

  $doc = $(document);

  $menu = null;

  mode = function(constant) {
    if ((constant != null) && constant !== _mode) {
      _mode = constant;
      $doc.trigger(constant);
    }
    return _mode;
  };

  select = function(increment) {
    var index, last, start, top;
    if (increment == null) increment = 0;
    start = this.$items.filter('.selected').first().index();
    if (start === -1) start = 0;
    last = this.$items.length - 1;
    index = start + increment;
    if (index < 0) {
      index = last;
    } else if (index > last) {
      index = 0;
    }
    this.$items.removeClass('selected').eq(index).addClass('selected');
    if (increment === 0) return;
    if (!this._hasScroll) {
      this._hasScroll = this.$itemWrapper.innerHeight() > this.innerHeight();
    }
    if (!this._itemHeight) {
      this._itemHeight = this.$items.first().outerHeight() + 1;
    }
    if (this._hasScroll === true) {
      top = this.scroller.scrollTop;
      top += this._itemHeight * increment;
      if (index === last) {
        top = this.$itemWrapper.innerHeight() - this.innerHeight();
      } else if (index === 0) {
        top = 0;
      }
      return this.scroller.scrollTop = top;
    }
  };

  setup = function() {
    mode(READ_MODE);
    $doc.bind('keydown', 't', function() {
      if (mode() !== NAV_MODE) return mode(NAV_MODE);
    }).bind('keydown', 'up', function() {
      if (mode() === NAV_MODE) {
        $menu.select(-1);
        return false;
      }
    }).bind('keydown', 'down', function() {
      if (mode() === NAV_MODE) {
        $menu.select(1);
        return false;
      }
    }).bind('keydown', 'return', function() {
      var $selected;
      if (mode() === NAV_MODE) {
        $selected = $menu.$items.filter('.selected').first();
        console.log("Going to selected `" + $selected + "`");
        if ($selected.length) return document.location = $selected.attr('href');
      }
    }).on({
      click: function() {
        return mode(READ_MODE);
      }
    }).on(READ_MODE, function() {
      $menu.css('display', 'none');
      return $menu.attr('style', '');
    }).on(NAV_MODE, function() {
      return $menu.css('display', 'block');
    });
    $menu.on('click', function(evt) {
      return evt.stopPropagation();
    });
    return $menu.select();
  };

  $(function() {
    $menu = $('#jump_wrapper');
    $menu.$itemWrapper = $menu.find('#jump_page');
    $menu.$items = $menu.find('a.source');
    $menu.scroller = document.getElementById('jump_scroller');
    $menu.select = select;
    if (docco.debug === true) window.$menu = $menu;
    return setup();
  });

}).call(this);
