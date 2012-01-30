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
$doc = $ document
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

stop = (e) -> e.stopPropagation()
prevent = (e) -> e.preventDefault()
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
# Setup menu handlers, etc.
# -------------------------
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
    .bind 'keydown', 't', (e) =>
      # Trigger nav mode.
      if mode() not in [NAV, SEARCH] 
        mode NAV 
      else mode SEARCH, true
      prevent e
    
    .bind 'keydown', 's', (e) =>
      if mode() in [NAV, SEARCH] and ($selected = @$selectedItem()).length
        @sticky (if $selected.is('.sticky') then DELETE else CREATE),
          $selected.data('path')
      else if mode() is READ
        @sticky CREATE, $page.data('path')
      prevent e
    
    .bind 'keydown', 'ctrl+q', (e) =>
      @sticky PURGE
      prevent e
    
    .bind 'keydown', 'up', (e) =>
      if mode() in [NAV, SEARCH]
        @select -1
        prevent e
    
    .bind 'keydown', 'down', (e) =>
      if mode() in [NAV, SEARCH]
        @select 1
        prevent e
    
    .bind 'keydown', 'return', (e) =>
      if mode() in [NAV, SEARCH]
        $selected = @$selectedItem()
        log "Going to selected `#{$selected}`"
        if $selected.length then document.location = $selected.attr('href')
        prevent e
    
    .bind 'keydown', 'esc', (e) =>
      switch mode()
        when NAV then mode READ
        when SEARCH then mode NAV
    
    .on
      click: () =>
        # Revert to read mode if click was not caught by children.
        switch mode()
          when NAV then mode READ
          when SEARCH then mode NAV
      
    .on READ, =>
      # When reverting to read mode:
      # - Hide the menu.
      @hide()
    
    .on NAV, =>
      # When switching to nav mode:
      # - Reset the menu.
      @reset()
      # - Show the menu.
      @show()
    
    .on SEARCH, =>
      @$searchField.focus()
    
  #
  # Menu bindings
  @
    .on 'click', (e) =>
      stop e
    
    .on EMPTY, (e, ref) =>
      switch ref
        when 'search' then if !!docco.no_results_tpl
          @$itemWrapper().empty().html docco.no_results_tpl({})
      stop e
    
    .on CREATE, (e, ref, path) =>
      switch ref
        when 'sticky' then if !!docco.sticky_item_tpl
          @stick $(docco.sticky_item_tpl(
            path: path
            href: @$items.filter("[data-path='#{path}']").first().attr('href')
          ))
      stop e
    
    .on DELETE, (e, ref, path) =>
      switch ref
        when 'sticky' then @unstick ".sticky[data-path='#{path}']:first"
      stop e
    
    .on PURGE, (e, ref) =>
      switch ref
        when 'sticky' then @unstick ".sticky"
      stop e
    
    # Allow going back to nav mode.
    .on 'click', 'a', (e) =>
      return if mode() isnt SEARCH
      prevent e
      stop e
    
    .on 'click', '.sticky .remove', (e) =>
      prevent e
      @sticky DELETE, $(e.target).closest('.sticky').data('path')
    
  # Directory navigation works on top of search.
  @$navItems.on 'click', (e) =>
    $item = $ e.target
    prevent e
    return if $item.is '.selected'
    # Update UI and search.
    @$navItems.removeClass 'selected'
    @search $item.addClass('selected').data('path')
    # Update field.
    @$searchField.val($item.data('path')).blur()
  
  #
  # Search bindings
  @$searchWrapper.on 'submit', (e) =>
    @search()
    @$searchField.blur()
    prevent e
  
  @$searchField.on 'focus blur', (e) =>
    @$clearSearch.toggle !!$(e.target).val()
    switch e.type
      when 'focus' then mode SEARCH
      when 'blur' then if not @$searchItems then mode NAV
  
  @$clearSearch.on 'click', =>
    @$searchField.val ''
    @$searchItems
    @reset()
  
  #
  # Fix for height fix.
  $(window).on 'resize', =>
    # Throttle.
    return if not @_didHeightFix
    # Reset height.
    @$scroller.css 'height', '100%'
    @_heightFixHeight = null
    @_didHeightFix = no
    # Redraw as needed.
    if @is ':visible'
      @hide()
      @show()
  
  #
  # Initialize.
  stickies = @_store('sticky')
  if not stickies?
    @_store 'sticky', { stickies: [] }
  else
    html = []
    $.each stickies.stickies, (i, path) =>
      html.push docco.sticky_item_tpl 
        path: path
        href: @$items.filter("[data-path='#{path}']").first().attr('href')
    
    @stick $(html.join(''))
  
  @select()

#
# Ready
# -----
$ ->
  # Setup page instance.
  $page = $ '#doc_page'
  #
  # Setup menu instance.
  $menu = $ '#jump_wrapper'
  f = ->
    # Properties
    @$itemWrapper = => @find '#jump_page'
    @$items = @find 'a.source'
    @$navItems = @find '#jump_dirs a.dir'
    @$searchWrapper = @find '#jump_search_wrapper'
    @$searchField = @find '#jump_search'
    @$clearSearch = @$searchWrapper.find '#clear_search'
    @$scroller = @find '#jump_scroller'
    @$selectableItems = =>
      switch mode()
        when SEARCH then if @$searchItems and @$searchItems.length then @$searchItems
        else @$items
    
    @$selectedItem = => @$selectableItems().filter('.selected').first()
    # - temp
    @$searchItems = $()
    # Methods
    @select = select
    @search = search
    @_store = store
    # - A simple sticky interface over `_store`.
    @sticky = (act=READ, id) =>
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
    @stick = ($items) =>
      @$itemWrapper().prepend $items
      @$items = @$items.add $items
    
    @unstick = (filter) =>
      @$itemWrapper().find(filter).remove()
      @$items = @$items.not filter
    
    # - Helper DOM method.
    @reset = =>
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
    @show = =>
      @css 'display', 'block'
      # Do menu height fix as needed.
      if not @_didHeightFix
        if not @_heightFixHeight
          @_heightFixHeight ?= @$scroller.height() - @$searchWrapper.height() - 3
        @$scroller.height @_heightFixHeight
        @_didHeightFix = yes
      return @
    
    @hide = =>
      @css 'display', 'none'
      @attr 'style', ''
      return @
    
    #
    # Setup handlers, etc.
    setup.call @
  f.call $menu

  #
  # Debug
  if docco.debug is on 
    window.$menu = $menu
    logger = -> console.log.apply console, arguments
    window.log = log = if console.log.bind then console.log.bind(logger) else logger

