# Docco Client 
# ============
# Adds some additional, mainly-Webkit-dependent UI features to the docco output:
#
# Shortcut Keys:
# --------------
# - `t` - Push into another mode. First time toggles nav mode and show jump menu.
#         Second time toggles search mode and focuses on search field.
# - `s` - Save sticky. When selecting on the menu, the selected item is saved; 
#         if it's a sticky item, it's removed. Otherwise, the current file is
#         saved. Items are saved to local storage.
# - `ctrl+q` - Remove all stickies.
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
READ = 'readmode.docco'
NAV  = 'navmode.docco'
SEARCH  = 'searchmode.docco'
EMPTY = 'empty.docco'
CREATE = 'create.docco'
READ = 'read.docco'
UPDATE = 'update.docco'
DELETE = 'delete.docco'
PURGE = 'purge.docco'
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
$page = null
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

# Main use: set or get item.
# Occasional use: clear or get store.
store = (key, json) ->
  return if not window.localStorage or not window.JSON
  if json?
    try
      log "json: #{JSON.stringify(json)}"
      if json is off then localStorage.removeItem key
      else localStorage.setItem key, JSON.stringify(json)
    catch error
      log error
      return no
  else if key?
    if key is off
      localStorage.clear()
    else return $.parseJSON localStorage.getItem(key)
  else return localStorage
  return @

#
# Handlers
# --------
setup = () ->
  #
  # Read mode by default.
  mode READ
  #
  # Document bindings:
  # _Note_ Hotkeys plugin only works with `bind`.
  # 1. Key handlers.
  # 2. Other handlers.
  # 3. Mode handlers.
  $doc
    .bind 'keydown', 't', (e) ->
      # Trigger nav mode.
      if mode() not in [NAV, SEARCH] 
        mode NAV 
      else mode SEARCH, true
      e.preventDefault()
    
    .bind 'keydown', 's', (e) ->
      if mode() in [NAV, SEARCH] and ($selected = $menu.$selectedItem()).length
        $menu.sticky (if $selected.is('.sticky') then DELETE else CREATE),
          $selected.data('path')
      else if mode() is READ
        $menu.sticky CREATE, $page.data('path')
      e.preventDefault()
    
    .bind 'keydown', 'ctrl+q', (e) ->
      $menu.sticky PURGE
      e.preventDefault()
    
    .bind 'keydown', 'up', (e) ->
      if mode() in [NAV, SEARCH]
        $menu.select -1
        e.preventDefault()
    
    .bind 'keydown', 'down', (e) ->
      if mode() in [NAV, SEARCH]
        $menu.select 1
        e.preventDefault()
    
    .bind 'keydown', 'return', (e) ->
      if mode() in [NAV, SEARCH]
        $selected = $menu.$selectedItem()
        log "Going to selected `#{$selected}`"
        if $selected.length then document.location = $selected.attr('href')
        e.preventDefault()
    
    .bind 'keydown', 'esc', (e) ->
      switch mode()
        when NAV then mode READ
        when SEARCH then mode NAV
    
    .on
      click: () ->
        # Revert to read mode if click was not caught by children.
        switch mode()
          when NAV then mode READ
          when SEARCH then mode NAV

    .on READ, ->
      # When reverting to read mode:
      # - Hide the menu.
      $menu.hide()
    
    .on NAV, ->
      # When switching to nav mode:
      # - Reset the menu.
      $menu.reset()
      # - Show the menu.
      $menu.show()
    
    .on SEARCH, ->
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
    
    .on CREATE, (e, ref, path) ->
      switch ref
        when 'sticky' then if !!docco.sticky_item_tpl
          $menu.stick $(docco.sticky_item_tpl(
            path: path
            href: $menu.$items.filter("[data-path='#{path}']").first().attr('href')
          ))
      e.stopPropagation()
    
    .on DELETE, (e, ref, path) ->
      switch ref
        when 'sticky' then $menu.unstick ".sticky[data-path='#{path}']:first"
      e.stopPropagation()
    
    .on PURGE, (e, ref) ->
      switch ref
        when 'sticky' then $menu.unstick ".sticky"
      e.stopPropagation()
    
    # Allow going back to nav mode.
    .on 'click', 'a', (e) ->
      return if mode() isnt SEARCH
      e.preventDefault()
      e.stopPropagation()
    
    .on 'click', '.sticky .remove', (e) ->
      e.preventDefault()
      $menu.sticky DELETE, $(@).closest('.sticky').data('path')
    
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
      when 'focus' then mode SEARCH
      when 'blur' then if not $menu.$searchItems then mode NAV
  
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
  stickies = $menu._store('sticky')
  if not stickies?
    $menu._store 'sticky', { stickies: [] }
  else
    html = []
    $.each stickies.stickies, (i, path) ->
      html.push docco.sticky_item_tpl 
        path: path
        href: $menu.$items.filter("[data-path='#{path}']").first().attr('href')
    
    $menu.stick $(html.join(''))
  
  $menu.select()

#
# Ready
# -----
$(() ->
  # Setup page instance.
  $page = $ '#doc_page'
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
      when SEARCH then if @$searchItems then @$searchItems
      else @$items
  
  $menu.$selectedItem = -> @$selectableItems().filter('.selected').first()
  # - temp
  $menu.$searchItems = $()
  # Methods
  $menu.select = select
  $menu.search = search
  $menu._store = store
  # - A simple sticky interface over `_store`.
  $menu.sticky = (act=READ, id) ->
    stickies = @_store('sticky').stickies
    did = no
    switch act
      when CREATE then if id? and stickies.indexOf(id) is -1
        stickies.push id
        did = @_store 'sticky', { stickies: stickies }
      when DELETE then if id? and (i = stickies.indexOf(id)) isnt -1
        stickies.splice i, 1
        did = @_store 'sticky', { stickies: stickies }
      when PURGE
        @_store 'sticky', { stickies: [] }
        did = yes
      when READ
        return @_store 'sticky'
    if did then @.trigger act, 
      if id? then ['sticky', id] else ['sticky']
    return @

  # - Helper DOM method.
  $menu.stick = ($items) ->
    @$itemWrapper().prepend $items
    @$items = @$items.add $items
  
  $menu.unstick = (filter) ->
    @$itemWrapper().find(filter).remove()
    @$items = @$items.not filter
  
  # - Helper DOM method.
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
