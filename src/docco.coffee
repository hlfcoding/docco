# **Docco** is a quick-and-dirty, hundred-line-long, literate-programming-style
# documentation generator. It produces HTML
# that displays your comments alongside your code. Comments are passed through
# [Markdown](http://daringfireball.net/projects/markdown/syntax), and code is
# passed through [Pygments](http://pygments.org/) syntax highlighting.
# This page is the result of running Docco against its own source file.
#
# If you install Docco, you can run it from the command-line:
#
#     docco src/*.coffee
#
# ...will generate an HTML documentation page for each of the named source files, 
# with a menu linking to the other pages, saving it into a `docs` folder.
#
# The [source for Docco](http://github.com/jashkenas/docco) is available on GitHub,
# and released under the MIT license.
#
# To install Docco, first make sure you have [Node.js](http://nodejs.org/),
# [Pygments](http://pygments.org/) (install the latest dev version of Pygments
# from [its Mercurial repo](http://dev.pocoo.org/hg/pygments-main)), and
# [CoffeeScript](http://coffeescript.org/). Then, with NPM:
#
#     sudo npm install -g docco
#
# Docco can be used to process CoffeeScript, JavaScript, Ruby, Python, or TeX files.
# Only single-line comments are processed -- block comments are ignored.
#
#### Partners in Crime:
#
# * If **Node.js** doesn't run on your platform, or you'd prefer a more 
# convenient package, get [Ryan Tomayko](http://github.com/rtomayko)'s 
# [Rocco](http://rtomayko.github.com/rocco/rocco.html), the Ruby port that's 
# available as a gem. 
# 
# * If you're writing shell scripts, try
# [Shocco](http://rtomayko.github.com/shocco/), a port for the **POSIX shell**,
# also by Mr. Tomayko.
# 
# * If Python's more your speed, take a look at 
# [Nick Fitzgerald](http://github.com/fitzgen)'s [Pycco](http://fitzgen.github.com/pycco/). 
#
# * For **Clojure** fans, [Fogus](http://blog.fogus.me/)'s 
# [Marginalia](http://fogus.me/fun/marginalia/) is a bit of a departure from 
# "quick-and-dirty", but it'll get the job done.
#
# * **Lua** enthusiasts can get their fix with 
# [Robert Gieseke](https://github.com/rgieseke)'s [Locco](http://rgieseke.github.com/locco/).
# 
# * And if you happen to be a **.NET**
# aficionado, check out [Don Wilson](https://github.com/dontangg)'s 
# [Nocco](http://dontangg.github.com/nocco/).

#### Main Documentation Generation Functions

# Generate the documentation for a source file by reading it in, splitting it
# up into comment/code sections, highlighting them for the appropriate language,
# and merging them into an HTML template.
generate_documentation = (source, callback) ->
  jump_menu_html = docco_jump_template
    sources: sources
    path: path
    destination: destination
    dirs: sub_dirs
  fs.readFile source, "utf-8", (error, code) ->
    throw error if error
    sections = parse source, code
    highlight source, sections, ->
      generate_html source, sections, jump_menu_html
      callback()

# Given a string of source code, parse out each comment and the code that
# follows it, and create an individual **section** for it.
# Sections take the form:
#
#     {
#       docs_text: ...
#       docs_html: ...
#       code_text: ...
#       code_html: ...
#     }
#
parse = (source, code) ->
  lines    = code.split '\n'
  sections = []
  language = get_language source
  has_code = docs_text = code_text = ''

  save = (docs, code) ->
    sections.push docs_text: docs, code_text: code

  for line in lines
    if line.match(language.comment_matcher) and not line.match(language.comment_filter)
      if has_code
        save docs_text, code_text
        has_code = docs_text = code_text = ''
      docs_text += line.replace(language.comment_matcher, '') + '\n'
    else
      has_code = yes
      code_text += line + '\n'
  save docs_text, code_text
  sections

# Highlights a single chunk of CoffeeScript code, using **Pygments** over stdio,
# and runs the text of its corresponding comment through **Markdown**, using
# [Showdown.js](http://attacklab.net/showdown/).
#
# We process the entire file in a single call to Pygments by inserting little
# marker comments between each section and then splitting the result string
# wherever our markers occur.
highlight = (source, sections, callback) ->
  language = get_language source
  pygments = spawn 'pygmentize', ['-l', language.name, '-f', 'html', '-O', 'encoding=utf-8,tabsize=2']
  output   = ''
  
  pygments.stderr.addListener 'data',  (error)  ->
    console.error error.toString() if error
    
  pygments.stdin.addListener 'error',  (error)  ->
    console.error "Could not use Pygments to highlight the source."
    process.exit 1
    
  pygments.stdout.addListener 'data', (result) ->
    output += result if result
    
  pygments.addListener 'exit', ->
    output = output.replace(highlight_start, '').replace(highlight_end, '')
    fragments = output.split language.divider_html
    for section, i in sections
      section.code_html = highlight_start + fragments[i] + highlight_end
      section.docs_html = showdown.makeHtml section.docs_text
    callback()
    
  if pygments.stdin.writable
    pygments.stdin.write((section.code_text for section in sections).join(language.divider_text))
    pygments.stdin.end()
  
# Once all of the code is finished highlighting, we can generate the HTML file
# and write out the documentation. Pass the completed sections into the template
# found in `resources/docco.jst`
generate_html = (source, sections, jump_menu_html) ->
  title = path.basename source
  dest  = destination source
  html  = docco_template 
    title: title 
    sections: sections 
    sources: sources
    source: source
    jump_menu_html: jump_menu_html
  if not conf.quiet then console.log "docco: #{source} -> #{dest}"
  fs.writeFile dest, html

#### Helpers & Setup

# Require our external dependencies, including **Showdown.js**
# (the JavaScript implementation of Markdown).
fs       = require 'fs'
path     = require 'path'
showdown = require('./../vendor/showdown').Showdown
{spawn, exec} = require 'child_process'

# A list of the languages that Docco supports, mapping the file extension to
# the name of the Pygments lexer and the symbol that indicates a comment. To
# add another language to Docco's repertoire, add it here.
languages =
  '.coffee':
    name: 'coffee-script', symbol: '#'
  '.js':
    name: 'javascript', symbol: '//'
  '.rb':
    name: 'ruby', symbol: '#'
  '.py':
    name: 'python', symbol: '#'
  '.tex':
    name: 'tex', symbol: '%'
  '.latex':
    name: 'tex', symbol: '%'
  '.c':
    name: 'c', symbol: '//'
  '.h':
    name: 'c', symbol: '//'

# Build out the appropriate matchers and delimiters for each language.
for ext, l of languages

  # Does the line begin with a comment?
  l.comment_matcher = new RegExp('^\\s*' + l.symbol + '\\s?')

  # Ignore [hashbangs](http://en.wikipedia.org/wiki/Shebang_(Unix\))
  # and interpolations...
  l.comment_filter = new RegExp('(^#![/]|^\\s*#\\{)')

  # The dividing token we feed into Pygments, to delimit the boundaries between
  # sections.
  l.divider_text = '\n' + l.symbol + 'DIVIDER\n'

  # The mirror of `divider_text` that we expect Pygments to return. We can split
  # on this to recover the original sections.
  # Note: the class is "c" for Python and "c1" for the other languages
  l.divider_html = new RegExp('\\n*<span class="c1?">' + l.symbol + 'DIVIDER<\\/span>\\n*')

# Get the current language we're documenting, based on the extension.
get_language = (source) -> languages[path.extname(source)]

# Compute the destination HTML path for an input source file path. If the source
# is `lib/example.coffee`, the HTML will be at `docs/example.html`
destination = (filepath, do_true=no) ->
  filepath = if path.basename(filepath) is conf.index_file and do_true is no # TODO - assuming it's a root file
  then 'docs/index.html'
  else "docs/#{filepath.replace(/\//g, '.')}.html"

# Ensure that the destination directory exists.
ensure_directory = (dir, callback) ->
  exec "mkdir -p #{dir}", -> callback()

# Micro-templating, originally by John Resig, borrowed by way of
# [Underscore.js](http://documentcloud.github.com/underscore/).
template = (str) ->
  new Function 'obj',
    'var p=[],print=function(){p.push.apply(p,arguments);};' +
    'with(obj){p.push(\'' +
    str.replace(/[\r\t\n]/g, " ")
       .replace(/'(?=[^<]*%>)/g,"\t")
       .split("'").join("\\'")
       .split("\t").join("'")
       .replace(/<%=(.+?)%>/g, "',$1,'")
       .split('<%').join("');")
       .split('%>').join("p.push('") +
       "');}return p.join('');"

# Get directory files and do something to them.
get_directory_files = (dir, callback) ->
  fs.readdirSync(dir).forEach (file) ->
    fpath = "#{dir}/#{file}"
    fstat = fs.statSync fpath
    if fstat.isFile() then callback fpath
    if fstat.isDirectory() then get_directory_files fpath, callback
  

# Create the templates that we will use to generate the Docco HTML page.
docco_template      = template fs.readFileSync(__dirname + '/../resources/docco.jst').toString()
docco_jump_template = template fs.readFileSync(__dirname + '/../resources/docco-jump.jst').toString()

# The CSS styles we'd like to apply to the documentation.
docco_styles    = fs.readFileSync(__dirname + '/../resources/docco.css').toString()

# The JS scripts we'd like to apply to the documentation. We'll concatenate the
# required js files and prepend them to the main client script. This does not
# include jQuery, which is loaded via cdn.
docco_client_scripts = (->
  includes = []
  get_directory_files(__dirname + '/../vendor/client', (full_path) ->
    includes.push fs.readFileSync(full_path).toString()
  )
  console.log "docco: found #{includes.length} client script include(s)..."
  includes = includes.join("\n")
  return includes + "\n" + fs.readFileSync(__dirname + '/../lib/docco-client.js').toString()
)()

# The start of each Pygments highlight block.
highlight_start = '<div class="highlight"><pre>'

# The end of each Pygments highlight block.
highlight_end   = '</pre></div>'

# Load and process config `./docco.json` file if it exists.
conf = JSON.parse fs.readFileSync("#{process.cwd()}/docco.json")
conf.base_dir ?= ''
conf.file_types ?= ['js']
conf.exclude_dirs ?= ''
conf.exclude_files ?= ''
conf.index_file ?= ''
conf.dir_floor ?= 1
conf.dir_ceil ?= 4

# Loop through arguments; make the tough decisions.
sources = []
args = process.ARGV.slice()
while args.length
  switch (arg = args.shift())
    # If you want to see the Docco version using `--version`, your ride ends here
    when '--version'
      console.log "Docco v#{version}"
      return
    # `--recursive` will recursively find all files that match any **patterns** passed to
    # docco. These patterns will use Javascript Regex and match against the entire
    # file path. This will also trigger the directories to be structured and trigger
    # the css to render inline.
    #
    # An example of using the --recursive flag would be:
    # 
    #    docco --recursive .*\.js .*\.coffee
    # 
    when '--recursive' then conf.recursive = true
    # `--quiet` will omit certain log statements.
    when '--quiet' then conf.quiet = true
    # Additional args can be set via a `docco.json` in the cwd.
    else sources.push arg

# Main generator.
run_script = -> 
  sources = sources.map (s) -> path.normalize s
  sources.sort()
  if sources.length
    console.log "docco: generating for #{sources.length} files..."
    ensure_directory 'docs', ->
      fs.writeFile 'docs/docco.css', docco_styles
      fs.writeFile 'docs/docco-client.js', docco_client_scripts
      files = sources.slice()
      next_file = -> generate_documentation files.shift(), next_file if files.length
      next_file()

# Directory tree walking helper.
# Not the same as `get_directory_files`.
skipped = 0
walk = (full_path, callback, _level=0) ->
  _level++
  children = fs.readdirSync full_path
  console.log "docco: generating for #{full_path}..."
  # Make the path relative.
  file_path = full_path.replace base_path
  callback file_path, _level
  for c in children
    p = "#{file_path}/#{c}"
    fp = "#{full_path}/#{c}"
    stat = fs.statSync fp
    if stat.isFile() and type_pattern.test(p) and not file_pattern.test(p) then sources.push p 
    else if stat.isDirectory() and not dir_pattern.test(p) then walk.call this, fp, callback, _level
    else if not conf.quiet then console.log "docco: skipped (#{skipped++}) #{p}"
  skipped

# Run the walker script as needed.
if conf.recursive
  sources = []
  sub_dirs = []
  base_path = "#{process.cwd()}/#{conf.base_dir}"
  base_pattern = new RegExp "^#{conf.base_dir}/"
  console.log "docco: generating recursively, reseting and getting files..."
  type_pattern = new RegExp "\\.(#{conf.file_types.join('|')})$", 'i'
  file_pattern = new RegExp "\\/\\.[^\\/]*
#{(if conf.exclude_files.length then '|(' else '')}
#{conf.exclude_files.join('|')})$", 'i'
  dir_pattern = new RegExp "\\/\\.[^\\/]*
#{(if conf.exclude_dirs.length then '|' else '')}
#{conf.exclude_dirs.join('|')}$", 'i'
  console.log "patterns: #{type_pattern}, #{file_pattern}, #{dir_pattern}"
  walk conf.base_dir, (path, level) -> 
    sub_dirs.push path if conf.dir_floor < level < conf.dir_ceil

# Run the generator script.
run_script()
