# Docco Client adds some additional UI features to the docco output:
# - Keyboard shortcuts: `g` to toggle nav mode, then `u` to show the jump menu.

#
# Constants
# ---------
# Mode constants are also the DOM event names.
READ_MODE = 'readmode.docco'
NAV_MODE  = 'navmode.docco'
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
#
# Global Methods
# --------------
mode = (constant) ->
  if constant? and constant isnt _mode
    _mode = constant
    $doc.trigger constant
    # console.log "docco: mode changed to `#{constant}`"
  _mode

#
# JQuery Object Methods
# ---------------------
select = (increment=0) ->
  # 1. Select toroidally by toggling class.
  start = @$items.filter('.selected').first().index()
  if start is -1 then start = 0
  # console.log "docco: select from start `#{start}`"
  last = @$items.length-1
  index = start + increment
  if index < 0 then index = last
  else if index > last then index = 0
  # console.log "docco: select at index `#{index}`"
  @$items
    .removeClass('selected')
    .eq(index).addClass('selected')
  # 2. Scroll toroidally as needed by updating scrollTop.
  if increment is 0 then return
  if not @_hasScroll
    @_hasScroll = @$itemWrapper.innerHeight() > @innerHeight()
    # console.log "docco: has-scroll is `#{@_hasScroll}`"
  if not @_itemHeight
    @_itemHeight = @$items.first().outerHeight() + 1
    # console.log "docco: remembered item-height as `#{@_itemHeight}`"
  if @_hasScroll is true
    top = @scroller.scrollTop
    top += @_itemHeight * increment
    if index is last then top = @$itemWrapper.innerHeight() - @innerHeight()
    else if index is 0 then top = 0
    @scroller.scrollTop = top
    # console.log "docco: scrolling"

#
# Procedures
# ----------
setup = () ->
  #
  # Read mode by default.
  mode READ_MODE
  #
  # Bind:
  # _Note_ Hotkeys plugin only works with `bind`.
  # 1. Key handlers.
  # 2. Other handlers.
  # 3. Mode handlers.
  $doc
    .bind 'keydown', 'g', () ->
      # Trigger nav mode.
      if mode() isnt NAV_MODE
        mode NAV_MODE

    .bind 'keydown', 'up', () ->
      if mode() is NAV_MODE 
        $menu.select -1
        return false

    .bind 'keydown', 'down', () ->
      if mode() is NAV_MODE 
        $menu.select 1
        return false

    .bind 'keydown', 'return', () ->
      if mode() is NAV_MODE
        $selected = $menu.$items.filter('.selected').first()
        console.log "Going to selected `#{$selected}`"
        if $selected.length then document.location = $selected.attr('href')

    .on
      click: () ->
        # Revert to read mode if click was not caught by children.
        mode READ_MODE

    .on READ_MODE, () ->
      # When reverting to read mode:
      # - Hide the menu.
      $menu.css 'display', 'none'
      $menu.attr 'style', ''

    .on NAV_MODE, () -> 
      $menu.css 'display', 'block'

  $menu.on 'click', (evt) -> evt.stopPropagation()

  $menu.select()

$(() ->
  $menu = $ '#jump_wrapper'
  # Properties
  $menu.$itemWrapper = $menu.find '#jump_page'
  $menu.$items = $menu.find 'a.source'
  $menu.scroller = document.getElementById 'jump_scroller'
  # Methods
  $menu.select = select
  if docco.debug is on then window.$menu = $menu
  setup()
)
