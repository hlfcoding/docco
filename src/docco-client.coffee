# Docco Client 
# ============
# Adds some additional, mainly-Webkit-dependent UI features to the docco output:
#
# Shortcut Keys:
# --------------
# - `t` - Push into another mode. First time toggles nav mode and show jump menu.
#         Second time toggles search mode and focuses on search field.
# - `up, down` - When in nav mode, select up and down the menu.
# - `return` - Go to selected item.
# - `esc` - Pop out of current mode, which updates the ui accordingly.
#
# UI Additions:
# -------------
# - Port to SCSS (see `docco.scss`).
# - Nicer blockquotes.
# - Horizontal rule (`<hr/> # ---`) styling.
# - Webkit scrollbars.
# - Jump menu:
#   - Scrollability.
#   - Integrated search and secondary navigation.

#
# Constants
# ---------
# Mode constants are also the DOM event names.
READ_MODE = 'readmode.docco'
NAV_MODE  = 'navmode.docco'
SEARCH_MODE  = 'searchmode.docco'
EMPTY = 'empty.docco'
#
# Globals
# -------
docco =
  debug: on
window.docco = docco
#
# Scope Globals
# -------------
_mode = null
$doc = $(document)
$menu = null
log = $.noop
#
# Global Methods
# --------------
mode = (constant, force=off) ->
  if constant? and (constant isnt _mode or force is on)
    _mode = constant
    $doc.trigger constant
    # log "docco: mode changed to `#{constant}`"
  _mode

#
# JQuery Object Methods
# ---------------------
select = (increment=0) ->
  # 1. Select toroidally by toggling class.
  start = @$selectedItem().index()
  if start is -1 then start = 0
  # log "docco: select from start `#{start}`"
  last = @$selectableItems().length-1
  index = start + increment
  if index < 0 then index = last
  else if index > last then index = 0
  # log "docco: select at index `#{index}`"
  @$selectableItems()
    .removeClass('selected')
    .eq(index).addClass('selected')
  # 2. Scroll toroidally as needed by updating scrollTop.
  if increment is 0 then return
  if not @_hasScroll
    @_hasScroll = @$itemWrapper().innerHeight() > @innerHeight()
    # log "docco: has-scroll is `#{@_hasScroll}`"
  if not @_itemHeight
    @_itemHeight = @$selectableItems().first().outerHeight() + 1
    # log "docco: remembered item-height as `#{@_itemHeight}`"
  if @_hasScroll is true
    top = @_itemHeight * index
    if index is last then top = @$itemWrapper().innerHeight() - @innerHeight()
    else if index is 0 then top = 0
    @$scroller.get(0).scrollTop = top
    # log "docco: scrolling"
  return @

search = (query) ->
  query ?= @$searchField.val()
  results = 0
  if query?
    # Get search results.
    @$searchItems = @$items.filter(":contains('#{query}'), [data-path*='#{query}']")
      .clone()
    results = @$searchItems.length
    # Manipulate.
    if !!results
      @$itemWrapper().fadeOut 'fast', =>
        @$items.detach()
        @_didHeightFix = no
        # Empty to make sure.
        @$itemWrapper().empty().append(@$searchItems).fadeIn 'fast'
      
    else @trigger EMPTY, ['search']
  return @

#
# Handlers
# --------
setup = () ->
  #
  # Read mode by default.
  mode READ_MODE
  #
  # Document bindings:
  # _Note_ Hotkeys plugin only works with `bind`.
  # 1. Key handlers.
  # 2. Other handlers.
  # 3. Mode handlers.
  $doc
    .bind 'keydown', 't', (e) ->
      # Trigger nav mode.
      if mode() not in [NAV_MODE, SEARCH_MODE] 
        mode NAV_MODE 
      else mode SEARCH_MODE, true
      e.preventDefault()
    
    .bind 'keydown', 'up', (e) ->
      if mode() in [NAV_MODE, SEARCH_MODE]
        $menu.select -1
        e.preventDefault()
    
    .bind 'keydown', 'down', (e) ->
      if mode() in [NAV_MODE, SEARCH_MODE]
        $menu.select 1
        e.preventDefault()
    
    .bind 'keydown', 'return', (e) ->
      if mode() in [NAV_MODE, SEARCH_MODE]
        $selected = $menu.$selectedItem()
        log "Going to selected `#{$selected}`"
        if $selected.length then document.location = $selected.attr('href')
        e.preventDefault()
    
    .bind 'keydown', 'esc', (e) ->
      switch mode()
        when NAV_MODE then mode READ_MODE
        when SEARCH_MODE then mode NAV_MODE
    
    .on
      click: () ->
        # Revert to read mode if click was not caught by children.
        switch mode()
          when NAV_MODE then mode READ_MODE
          when SEARCH_MODE then mode NAV_MODE

    .on READ_MODE, ->
      # When reverting to read mode:
      # - Hide the menu.
      $menu.hide()
    
    .on NAV_MODE, ->
      # When switching to nav mode:
      # - Reset the menu.
      $menu.reset()
      # - Show the menu.
      $menu.show()
    
    .on SEARCH_MODE, ->
      $menu.$searchField.focus()
    
  #
  # Menu bindings
  $menu
    .on 'click', (e) ->
      e.stopPropagation()
    
    .on EMPTY, (e, ref) ->
      switch ref
        when 'search' then if !!docco.no_results_tpl
          $menu.$itemWrapper().empty().html docco.no_results_tpl()
      e.stopPropagation()
      e.stopPropagation()
    
  # Directory navigation works on top of search.
  $menu.$navItems.on 'click', (e) ->
    $item = $ @
    e.preventDefault()
    return if $item.is '.selected'
    # Update UI and search.
    $menu.$navItems.removeClass 'selected'
    $menu.search $item.addClass('selected').data('path')
    # Update field.
    $menu.$searchField.val($item.data('path')).blur()
  
  #
  # Search bindings
  $menu.$searchWrapper.on 'submit', (e) ->
    $menu.search()
    $menu.$searchField.blur()
    e.preventDefault()
  
  $menu.$searchField.on 'focus blur', (e) ->
    $menu.$clearSearch.toggle !!$(@).val()
    switch e.type
      when 'focus' then mode SEARCH_MODE
      when 'blur' then if not $menu.$searchItems then mode NAV_MODE
  
  $menu.$clearSearch.click -> 
    $menu.$searchField.val ''
    $menu.reset()
  
  #
  # Fix for height fix.
  $(window).on 'resize', ->
    # Throttle.
    return if not $menu._didHeightFix
    # Reset height.
    $menu.$scroller.css 'height', '100%'
    $menu._heightFixHeight = null
    $menu._didHeightFix = no
    # Redraw as needed.
    if $menu.is ':visible'
      $menu.hide()
      $menu.show()
  
  #
  # Initialize.
  $menu.select()
  

#
# Ready
# -----
$(() ->
  #
  # Setup menu instance.
  $menu = $ '#jump_wrapper'
  # Properties
  $menu.$itemWrapper = -> $menu.find '#jump_page'
  $menu.$items = $menu.find 'a.source'
  $menu.$navItems = $menu.find '#jump_dirs a.dir'
  $menu.$searchWrapper = $menu.find '#jump_search_wrapper'
  $menu.$searchField = $menu.find '#jump_search'
  $menu.$clearSearch = $menu.$searchWrapper.find '#clear_search'
  $menu.$scroller = $menu.find '#jump_scroller'
  $menu.$selectableItems = -> 
    switch mode()
      when SEARCH_MODE then if @$searchItems then @$searchItems
      else @$items
  
  $menu.$selectedItem = -> @$selectableItems().filter('.selected').first()
  # - temp
  $menu.$searchItems = $()
  # Methods
  $menu.select = select
  $menu.search = search
  $menu.reset = ->
    @$searchField.blur()
    # Manipulate.
    @$itemWrapper().fadeOut 'fast', =>
      if @$searchItems
        @$searchItems.remove()
        @$searchItems = null
        @_didHeightFix = no
      @$itemWrapper().empty().append(@$items).fadeIn 'fast'
    
    return @
  
  # - Override jQuery.
  $menu.show = ->
    @css 'display', 'block'
    # Do menu height fix as needed.
    if not @_didHeightFix
      if not @_heightFixHeight
        @_heightFixHeight ?= @$scroller.height() - @$searchWrapper.height() - 3
      @$scroller.height @_heightFixHeight
      @_didHeightFix = yes
    return @
  
  $menu.hide = -> 
    @css 'display', 'none'
    @attr 'style', ''
    return @
  
  # 
  # Setup handlers, etc.
  setup()
  #
  # Debug
  if docco.debug is on 
    window.$menu = $menu
    logger = -> console.log.apply(console, arguments)
    window.log = log = if console.log.bind then console.log.bind(logger) else logger
)
