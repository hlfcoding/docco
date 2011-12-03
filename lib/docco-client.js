(function() {
  var $doc, $menu, NAV_MODE, READ_MODE, mode, select, setup, _mode;
  READ_MODE = 'readmode.docco';
  NAV_MODE = 'navmode.docco';
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
    var index, last, start;
    if (increment == null) {
      increment = 0;
    }
    start = this.$items.filter('.selected').first().index();
    if (start === -1) {
      start = 0;
    }
    last = this.$items.length - 1;
    index = start + increment;
    if (index < 0) {
      index = last;
    } else if (index > last) {
      index = 0;
    }
    return this.$items.removeClass('selected').eq(index).addClass('selected');
  };
  setup = function() {
    mode(READ_MODE);
    $doc.bind('keydown', 'g', function() {
      if (mode() !== NAV_MODE) {
        return mode(NAV_MODE);
      }
    }).bind('keydown', 'u', function() {
      if (mode() === NAV_MODE) {
        return $menu.css('display', 'block');
      }
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
        if ($selected.length) {
          return document.location = $selected.attr('href');
        }
      }
    }).on({
      click: function() {
        return mode(READ_MODE);
      }
    }).on(READ_MODE, function() {
      $menu.css('display', 'none');
      return $menu.attr('style', '');
    }).on(NAV_MODE, function() {
      return false;
    });
    $menu.on('click', function(evt) {
      return evt.stopPropagation();
    });
    return $menu.select();
  };
  $(function() {
    $menu = $('#jump_wrapper');
    $menu.$items = $menu.find('a.source');
    $menu.select = select;
    return setup();
  });
}).call(this);
