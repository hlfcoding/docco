# Docco Client 
# ============
# Adds some additional, mainly-Webkit-dependent UI features to the docco output:
#
# Shortcut Keys:
# --------------
# - `t` - Push into another mode. First time toggles nav mode and show jump menu.
#         Second time toggles search mode and focuses on search field.
# - `r` - Navigate to the current file in the jump menu.
# - `j` - Navigate to and open the previous file in the jump menu.
# - `k` - Navigate to and open the next file in the jump menu.
# - `s` - Save sticky. When selecting on the menu, the selected item is saved; 
#         if it's a sticky item, it's removed. Otherwise, the current file is
#         saved. Items are saved to local storage.
# - `ctrl+q` - Remove all stored data: stickies, text size, etc.
# - `up, down` - When in nav mode, select up and down the menu.
# - `ctrl+up, down` - Increase or decrease page text size.
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
REDRAW = 'redraw.docco'
#
# Globals
# -------
window.docco ?= {}
docco.debug = on

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
mode = (constant, force=no) ->
  if constant? and (constant not in [_mode, off] or force is yes)
    prev = _mode
    _mode = constant
    $doc.trigger constant, [prev]
  _mode

stop = (e) -> e.stopPropagation()
prevent = (e) -> e.preventDefault()
follow = ($link) -> if (href = $link.attr('href'))? then document.location = href

#
# JQuery Object Methods
# ---------------------
select = (increment=0, refresh=no) ->
  # 1. Select toroidally by toggling class.
  start = @$selectedItem().index()
  last = @$selectableItems().length-1
  index = start + increment
  if index < 0 then index = last
  else if index > last then index = 0
  @$selectableItems()
    .removeClass('selected')
    .eq(index).addClass 'selected'
  # 2. Scroll toroidally as needed by updating scrollTop.
  if increment is 0 and refresh is no then return
  if not @_hasScroll
    @_hasScroll = @$itemWrapper().innerHeight() > @innerHeight()
  if not @_itemHeight
    @_itemHeight = @$selectableItems().first().outerHeight() + 1
  if @_hasScroll is true
    top = @_itemHeight * index
    if index is last then top = @$itemWrapper().innerHeight() - @innerHeight()
    else if index is 0 then top = 0
    @$scroller.get(0).scrollTop = top
  @

navigate = (increment=1) ->
  # Navigate toroidally.
  last = @$selectableItems().length-1
  index = @$pageItem().index() + increment
  if index < 0 then index = last
  else if index > last then index = 0
  follow @$items.eq index

search = (query) ->
  query ?= @$searchField.val()
  results = 0
  if query?
    # Get search results.
    @$searchItems.remove() if @$searchItems
    @$searchItems = @$items
      .filter(":contains('#{query}'), [data-path*='#{query}']")
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
  @

# Main use: set or get item.
# Occasional use: clear or get store.
store = (key, json) ->
  return if not window.localStorage or not window.JSON
  if json?
    try
      log "json: #{JSON.stringify json}"
      if json is off then localStorage.removeItem key
      else localStorage.setItem key, JSON.stringify json
    catch error
      log error
      return no
  else if key?
    if key is off
      localStorage.clear()
    else return $.parseJSON localStorage.getItem key
  else return localStorage
  @

textSize = (increment) ->
  data = @_store('textSize') or { zoom: 1 }
  if increment?
    if increment is off
      @css 'zoom', 0
      @_store 'textSize', off
    else
      if increment is on then increment = 0
      data.zoom = increment + parseFloat data.zoom
      data.zoom = Math.max data.zoom, 0.5
      data.zoom = Math.min data.zoom, 1.5
      @css 'zoom', data.zoom.toFixed 1
      @_store 'textSize', data
  data

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
        mode NAV, mode()
      else mode SEARCH, yes
      prevent e
    
    .bind 'keydown', 'r', (e) =>
      # Shift to navigation as needed.
      if mode() not in [NAV, SEARCH] then mode NAV
      # Adapt to and use select method.
      to = @$pageItem().index()
      from = @$selectedItem().index()
      # Catch and deal with exceptions, like if target isn't in search results.
      if to is -1 or from is -1
        if mode() is SEARCH
          @one REDRAW, =>
            e = $.Event 'keydown'
            e.which = 82 # r
            $doc.trigger e
          mode NAV
        return
      increment = to - from
      @select increment, yes
      prevent e
    
    .bind 'keydown', 'j', (e) => 
      @navigate -1
      prevent e
    
    .bind 'keydown', 'k', (e) => 
      @navigate 1
      prevent e
    
    .bind 'keydown', 's', (e) =>
      if mode() in [NAV, SEARCH] and ($selected = @$selectedItem()).length
        @sticky (if $selected.is('.sticky') then DELETE else CREATE),
                $selected.data 'path'
      else if mode() is READ
        @sticky CREATE, $page.data 'path'
      prevent e
    
    .bind 'keydown', 'ctrl+q', (e) =>
      @sticky PURGE
      $page.textSize off
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
        if $selected.length then follow $selected
        prevent e
    
    .bind 'keydown', 'esc', (e) =>
      if @$clearSearch.is ':visible' then @$clearSearch.click()
      else switch mode()
        when NAV then mode READ
        when SEARCH then mode NAV
      prevent e
    
    .bind 'keydown', 'ctrl+up', (e) =>
      if mode() is READ
        $page.textSize 0.1
        prevent e
    
    .bind 'keydown', 'ctrl+down', (e) =>
      if mode() is READ
        $page.textSize -0.1
        prevent e
    
    .on
      click: () =>
        # Revert to read mode if click was not caught by children.
        mode READ
      
    .on READ, (e, prev) =>
      # When reverting to read mode:
      # - Hide the menu.
      @hide()
    
    .on NAV, (e, prev) =>
      # When switching to nav mode:
      # - Reset the menu.
      @reset() if not (prev? and prev is READ)
      # - Show the menu.
      @show()
    
    .on SEARCH, (e, prev) =>
      @$searchField.focus()
    
  #
  # Menu bindings
  @
    .on 'click', (e) =>
      stop e
    
    .on EMPTY, (e, ref) =>
      switch ref
        when 'search' then if !!docco.no_results_tpl
          @$itemWrapper().empty().html docco.no_results_tpl {}
      stop e
    
    .on CREATE, (e, ref, path) =>
      switch ref
        when 'sticky' then if !!docco.sticky_item_tpl
          @stick $ docco.sticky_item_tpl
            path: path
            href: @$items.filter("[data-path='#{path}']").first().attr 'href'
      stop e
    
    .on DELETE, (e, ref, path) =>
      switch ref
        when 'sticky' then @unstick ".sticky[data-path='#{path}']:first"
      stop e
    
    .on PURGE, (e, ref) =>
      switch ref
        when 'sticky' then @unstick ".sticky"
      stop e
    
    .on 'click', '.sticky .remove', (e) =>
      @sticky DELETE, $(e.target).closest('.sticky').data 'path'
      prevent e
    
  # Directory navigation works on top of search.
  @$navItems.on 'click', (e) =>
    $item = $ e.target
    prevent e
    return if $item.is '.selected'
    # Update UI and search.
    mode SEARCH
    @$navItems.removeClass 'selected'
    $item.addClass 'selected'
    # Update field.
    @$searchField.val $item.data 'path'
    @$searchWrapper.submit()
  
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
    mode NAV
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
  stickies = @_store 'sticky'
  if not stickies?
    @_store 'sticky', { stickies: [] }
  else
    html = for path, i in stickies.stickies
      docco.sticky_item_tpl 
        path: path
        href: @$items.filter("[data-path='#{path}']").first().attr('href')
    @stick $ html.join ''
  
  @select()

#
# Ready
# -----
$ ->
  # Setup page instance.
  $page = $ '#doc_page'
  $page.textSize = textSize
  $page._store = store
  $page.textSize on
  #
  # Setup menu instance.
  $menu = $ '#jump_wrapper'
  # Don't run at all if there's no menu (single-source project).
  return if not $menu.length
  # Hide search if there aren't enough files.
  SEARCH = off if $('a.source', $menu).length < 25
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
    @$pageItem = => @$items.filter("[data-path='#{$page.data('path')}']").first()
    # - temp
    @$searchItems = $()
    # Methods
    @select = select
    @navigate = navigate
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
      @
    
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
      @$navItems.removeClass 'selected'
      # Manipulate.
      @$itemWrapper().fadeOut 'fast', =>
        if @$searchItems
          @$searchItems.remove()
          @$searchItems = null
          @_didHeightFix = no
        @$itemWrapper().empty().append(@$items).fadeIn 'fast', =>
          @.trigger REDRAW
      
      @
    
    # - Override jQuery.
    @show = =>
      @css 'display', 'block'
      # Do menu height fix as needed.
      if not @_didHeightFix
        if not @_heightFixHeight
          @_heightFixHeight ?= @$scroller.height() - @$searchWrapper.height() - 3
        @$scroller.height @_heightFixHeight
        @_didHeightFix = yes
      @
    
    @hide = =>
      @css 'display', 'none'
      @attr 'style', ''
      @
    
    #
    # Setup handlers, etc.
    setup.call @
  f.call $menu

  #
  # Debug
  if docco.debug is on 
    window.$menu = $menu
    window.$page = $page
    logger = -> console.log.apply console, arguments
    window.log = log = if console.log.bind then console.log.bind(console) else logger

