(function() {
  var arg, args, base_path, base_pattern, conf, destination, dir_pattern, docco_client_scripts, docco_styles, docco_template, ensure_directory, exec, ext, file_pattern, fs, generate_documentation, generate_html, get_directory_files, get_language, highlight, highlight_end, highlight_start, l, languages, parse, path, run_script, showdown, skipped, sources, spawn, sub_dirs, template, type_pattern, walk, _ref;

  generate_documentation = function(source, callback) {
    return fs.readFile(source, "utf-8", function(error, code) {
      var sections;
      if (error) throw error;
      sections = parse(source, code);
      return highlight(source, sections, function() {
        generate_html(source, sections);
        return callback();
      });
    });
  };

  parse = function(source, code) {
    var code_text, docs_text, has_code, language, line, lines, save, sections, _i, _len;
    lines = code.split('\n');
    sections = [];
    language = get_language(source);
    has_code = docs_text = code_text = '';
    save = function(docs, code) {
      return sections.push({
        docs_text: docs,
        code_text: code
      });
    };
    for (_i = 0, _len = lines.length; _i < _len; _i++) {
      line = lines[_i];
      if (line.match(language.comment_matcher) && !line.match(language.comment_filter)) {
        if (has_code) {
          save(docs_text, code_text);
          has_code = docs_text = code_text = '';
        }
        docs_text += line.replace(language.comment_matcher, '') + '\n';
      } else {
        has_code = true;
        code_text += line + '\n';
      }
    }
    save(docs_text, code_text);
    return sections;
  };

  highlight = function(source, sections, callback) {
    var language, output, pygments, section;
    language = get_language(source);
    pygments = spawn('pygmentize', ['-l', language.name, '-f', 'html', '-O', 'encoding=utf-8,tabsize=2']);
    output = '';
    pygments.stderr.addListener('data', function(error) {
      if (error) return console.error(error.toString());
    });
    pygments.stdin.addListener('error', function(error) {
      console.error("Could not use Pygments to highlight the source.");
      return process.exit(1);
    });
    pygments.stdout.addListener('data', function(result) {
      if (result) return output += result;
    });
    pygments.addListener('exit', function() {
      var fragments, i, section, _len;
      output = output.replace(highlight_start, '').replace(highlight_end, '');
      fragments = output.split(language.divider_html);
      for (i = 0, _len = sections.length; i < _len; i++) {
        section = sections[i];
        section.code_html = highlight_start + fragments[i] + highlight_end;
        section.docs_html = showdown.makeHtml(section.docs_text);
      }
      return callback();
    });
    if (pygments.stdin.writable) {
      pygments.stdin.write(((function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = sections.length; _i < _len; _i++) {
          section = sections[_i];
          _results.push(section.code_text);
        }
        return _results;
      })()).join(language.divider_text));
      return pygments.stdin.end();
    }
  };

  generate_html = function(source, sections) {
    var dest, html, title;
    title = path.basename(source);
    dest = destination(source);
    html = docco_template({
      title: title,
      sections: sections,
      sources: sources,
      path: path,
      destination: destination,
      dirs: sub_dirs
    });
    console.log("docco: " + source + " -> " + dest);
    return fs.writeFile(dest, html);
  };

  fs = require('fs');

  path = require('path');

  showdown = require('./../vendor/showdown').Showdown;

  _ref = require('child_process'), spawn = _ref.spawn, exec = _ref.exec;

  languages = {
    '.coffee': {
      name: 'coffee-script',
      symbol: '#'
    },
    '.js': {
      name: 'javascript',
      symbol: '//'
    },
    '.rb': {
      name: 'ruby',
      symbol: '#'
    },
    '.py': {
      name: 'python',
      symbol: '#'
    },
    '.tex': {
      name: 'tex',
      symbol: '%'
    },
    '.latex': {
      name: 'tex',
      symbol: '%'
    },
    '.c': {
      name: 'c',
      symbol: '//'
    },
    '.h': {
      name: 'c',
      symbol: '//'
    }
  };

  for (ext in languages) {
    l = languages[ext];
    l.comment_matcher = new RegExp('^\\s*' + l.symbol + '\\s?');
    l.comment_filter = new RegExp('(^#![/]|^\\s*#\\{)');
    l.divider_text = '\n' + l.symbol + 'DIVIDER\n';
    l.divider_html = new RegExp('\\n*<span class="c1?">' + l.symbol + 'DIVIDER<\\/span>\\n*');
  }

  get_language = function(source) {
    return languages[path.extname(source)];
  };

  destination = function(filepath, do_true) {
    if (do_true == null) do_true = false;
    return filepath = path.basename(filepath) === conf.index_file && do_true === false ? 'docs/index.html' : "docs/" + (filepath.replace(/\//g, '.')) + ".html";
  };

  ensure_directory = function(dir, callback) {
    return exec("mkdir -p " + dir, function() {
      return callback();
    });
  };

  template = function(str) {
    return new Function('obj', 'var p=[],print=function(){p.push.apply(p,arguments);};' + 'with(obj){p.push(\'' + str.replace(/[\r\t\n]/g, " ").replace(/'(?=[^<]*%>)/g, "\t").split("'").join("\\'").split("\t").join("'").replace(/<%=(.+?)%>/g, "',$1,'").split('<%').join("');").split('%>').join("p.push('") + "');}return p.join('');");
  };

  get_directory_files = function(dir, callback) {
    return fs.readdirSync(dir).forEach(function(file) {
      var fpath, fstat;
      fpath = "" + dir + "/" + file;
      fstat = fs.statSync(fpath);
      if (fstat.isFile()) callback(fpath);
      if (fstat.isDirectory()) return get_directory_files(fpath, callback);
    });
  };

  docco_template = template(fs.readFileSync(__dirname + '/../resources/docco.jst').toString());

  docco_styles = fs.readFileSync(__dirname + '/../resources/docco.css').toString();

  docco_client_scripts = (function() {
    var includes;
    includes = [];
    get_directory_files(__dirname + '/../vendor/client', function(full_path) {
      return includes.push(fs.readFileSync(full_path).toString());
    });
    console.log("docco: found " + includes.length + " client script include(s)...");
    includes = includes.join("\n");
    return includes + "\n" + fs.readFileSync(__dirname + '/../lib/docco-client.js').toString();
  })();

  highlight_start = '<div class="highlight"><pre>';

  highlight_end = '</pre></div>';

  conf = JSON.parse(fs.readFileSync("" + (process.cwd()) + "/docco.json"));

  if (conf.base_dir == null) conf.base_dir = '';

  if (conf.file_types == null) conf.file_types = ['js'];

  if (conf.exclude_dirs == null) conf.exclude_dirs = '';

  if (conf.exclude_files == null) conf.exclude_files = '';

  if (conf.index_file == null) conf.index_file = '';

  if (conf.dir_floor == null) conf.dir_floor = 1;

  if (conf.dir_ceil == null) conf.dir_ceil = 4;

  sources = [];

  args = process.ARGV.slice();

  while (args.length) {
    switch ((arg = args.shift())) {
      case '--version':
        console.log("Docco v" + version);
        return;
      case '--recursive':
        conf.recursive = true;
        break;
      default:
        sources.push(arg);
    }
  }

  run_script = function() {
    sources = sources.map(function(s) {
      return path.normalize(s);
    });
    sources.sort();
    if (sources.length) {
      console.log("docco: generating for " + sources.length + " files...");
      return ensure_directory('docs', function() {
        var files, next_file;
        fs.writeFile('docs/docco.css', docco_styles);
        fs.writeFile('docs/docco-client.js', docco_client_scripts);
        files = sources.slice();
        next_file = function() {
          if (files.length) {
            return generate_documentation(files.shift(), next_file);
          }
        };
        return next_file();
      });
    }
  };

  skipped = 0;

  walk = function(full_path, callback, _level) {
    var c, children, file_path, fp, p, stat, _i, _len;
    if (_level == null) _level = 0;
    _level++;
    children = fs.readdirSync(full_path);
    console.log("docco: generating for " + full_path + "...");
    file_path = full_path.replace(base_path);
    callback(file_path, _level);
    for (_i = 0, _len = children.length; _i < _len; _i++) {
      c = children[_i];
      p = "" + file_path + "/" + c;
      fp = "" + full_path + "/" + c;
      stat = fs.statSync(fp);
      if (stat.isFile() && type_pattern.test(p) && !file_pattern.test(p)) {
        sources.push(p);
      } else if (stat.isDirectory() && !dir_pattern.test(p)) {
        walk.call(this, fp, callback, _level);
      } else {
        console.log("docco: skipped (" + (skipped++) + ") " + p);
      }
    }
    return skipped;
  };

  if (conf.recursive) {
    sources = [];
    sub_dirs = [];
    base_path = "" + (process.cwd()) + "/" + conf.base_dir;
    base_pattern = new RegExp("^" + conf.base_dir + "/");
    console.log("docco: generating recursively, reseting and getting files...");
    type_pattern = new RegExp("\\.(" + (conf.file_types.join('|')) + ")$", 'i');
    file_pattern = new RegExp("\\/\\.[^\\/]*" + (conf.exclude_files.length ? '|(' : '') + "" + (conf.exclude_files.join('|')) + ")$", 'i');
    dir_pattern = new RegExp("\\/\\.[^\\/]*" + (conf.exclude_dirs.length ? '|' : '') + "" + (conf.exclude_dirs.join('|')) + "$", 'i');
    console.log("patterns: " + type_pattern + ", " + file_pattern + ", " + dir_pattern);
    walk(conf.base_dir, function(path, level) {
      if ((conf.dir_floor < level && level < conf.dir_ceil)) {
        return sub_dirs.push(path);
      }
    });
  }

  run_script();

}).call(this);
