#! /usr/bin/env ruby
# encoding: utf-8
if $0 == __FILE__

#
  HELP = <<-____

  NAME
  ========
    senv - secure 12-factor env vars for your apps, in any lang, local and remote

  EXAMPLES
  ========
    # setup a directory to use senv, including making some sample config files
     
      ~> senv .setup /full/path/to/directory

    # setup _this_ directory

      ~> senv .setup

    # encrypt a file
     
      ~> senv /tmp/development.json | senv .write .senv/development.enc.json

    # read a file, encrypted or not
     
      ~> senv .read .senv/development.enc.json
      ~> senv .read .senv/development.json

    # show all the environemnt settings for the production environment

      ~> senv @production

    # run a command under an environment
    
      ~> senv @test ./run/the/tests.js

    # edit a file, encrypted or not, using the $EDITOR like all unix citizens
    
      ~> senv .edit ./senv/production.enc.rb

    # pluck a single value from a config set

      ~> senv .get API_KEY

    # load an entire senv into a shell script

      #! /bin/sh
      export SENV=production
      eval $(senv init -)

    # load senv into yer ruby program
     
      #! /usr/bin/env ruby
      require 'senv'
      Senv.load(:all)

  ENVIRONMENT
  ===========
    the following environment variables affect senv itself

    SENV
      specify which senv should be loaded

    SENV_KEY
      specify the encryption key via the environment

    SENV_PATH
      a colon separated set of paths in which to search for '.senv' directories

    SENV_ROOT
      the location of the .senv directory

    SENV_DEBUG
      you guessed it

  ____

#
  require "pathname"
  script_d = Pathname.new(__FILE__).realpath.dirname.to_s

  unless defined?(Senv)
    require File.expand_path("../lib/senv", script_d)
  end

  unless defined?(Senv::Script)
    require File.expand_path("../lib/senv/script", script_d)
  end

#
  Senv.script do
    before do
      $handle_senv_alias = proc do
        if ARGV.first =~ /^@/
          ENV['SENV'] = ARGV.shift.sub(/^@/, '').strip
        end
      end.call

      $handle_old_fashioned_cries_for_help = proc do
        if ARGV.delete('-h') || ARGV.delete('--help')
          ARGV.unshift('help')
        end
      end.call
    end

  #
    run do
      exec!
    end

  #
    run 'help' do
      show_help!
    end

  #
    run 'exec' do
      exec!
    end

  #
    run 'init' do
      require "shellwords"

      load_senv!

      Senv.environment.to_hash.each do |key, val|
        if val
          STDOUT.puts "export #{ Shellwords.escape(key) }=#{ Shellwords.escape(val) }"
        else
          STDOUT.puts "unset #{ Shellwords.escape(key) }"
        end
      end
    end

  #
    run '.setup' do
      dir = @argv.shift || Dir.pwd
      key = @argv.shift || @options['key'] || SecureRandom.uuid

      key.strip!

      dir = File.expand_path(dir)

      FileUtils.mkdir_p(dir)

      Dir.chdir(dir) do
      #
        if test(?d, '.senv')
          abort "#{ dir }/.senv directory exists"
        end

        FileUtils.mkdir_p('.senv')

        IO.binwrite('.senv/.key', "#{ key }\n")

        Senv.key = key

      #
        Senv.write(
          '.senv/all.rb',
          u.unindent(
            <<-____
              ENV['A'] = 'one'
              ENV['B'] = 'two'
              ENV['C'] = 'three'
            ____
          )
        )

        %w[ development production ].each do |env|
          Senv.write(
            ".senv/#{ env }.rb",
            u.unindent(
              <<-____
                Senv.load(:all)
                ENV['B'] = 'two (via #{ env }.rb)'
              ____
            )
          )

          Senv.write(
            ".senv/#{ env }.enc.rb",
            u.unindent(
              <<-____
                Senv.load(:all)
                ENV['C'] = 'three (via #{ env }.enc.rb)'
              ____
            )
          )
        end

      #
        puts "[SENV] setup #{ dir }/.senv" 

        Dir.glob('.senv/**/**').sort.each do |entry|
          next unless test(?f, entry)
          puts "- #{ entry }"
        end
      end
    end

  #
    run '.inspect' do
      load_senv!

      if @argv.empty?
        puts Senv.environment.inspect
      else
        env = {}
        @argv.each do |name|
          env[name] = Senv.environment[name]
        end
        puts env.inspect
      end
    end

  #
    run '.edit' do
      input = @argv[0]
      output = input
      options = @opts

      data =
        if test(?s, input)
          Senv.read(input, options)
        else
          ''
        end

      ext = File.basename(input).split('.').last
      editor = @options['editor'] || ENV['EDITOR'] || 'vim'

      u.tmpfile(:ext => ext) do |tmp|
        tmp.write(data)
        tmp.close

        if(system "#{ editor } #{ tmp.path }")
          data = IO.binread(tmp.path)
          Senv.write(output, data, options)
        end
      end
    end

  #
    run '.read' do
      input = @argv[0] || '-'
      output = @argv[1] || '-'
      options = @options

      data =
        if input == '-'
          Senv.read('/dev/stdin', options)
        else
          Senv.read(input, options)
        end

      if output == '-'
        Senv.write('/dev/stdout', data, options)
      else
        Senv.write(output, data, options)
      end
    end

    run '.write' do
      output = @argv[0] || '-'
      input = @argv[1] || '-'
      options = @options

      data =
        if input == '-'
          Senv.read('/dev/stdin')
        else
          Senv.read(input)
        end

      if output == '-'
        Senv.write('/dev/stdout', data, options)
      else
        Senv.write(output, data, options)
      end
    end

    run '.get' do
      load_senv!

      @argv.each do |name|
        puts ENV[name]
      end
    end

  #
    def show_help!
      help = ERB.new(u.unindent(HELP)).result(::TOPLEVEL_BINDING)
      STDOUT.puts(help)
    end

    def load_senv!
      if @options['debug']
        ENV['SENV_DEBUG'] = 'true'
      end

      if @options['key']
        ENV['SENV_KEY'] = @options['key']
      end

      begin
        Senv.load(:force => @options['force'])
      rescue Senv::Error => e
        abort(e.message)
      end
    end

    def exec!
      load_senv!

      if @argv.empty?
        STDOUT.puts Senv.environment.to_hash.to_yaml
      else
        exec(*@argv)
      end
    end
  end

end


BEGIN {

### <lib src='lib/senv.rb'>

#
  require 'erb'
  require 'yaml'
  require 'json'
  require 'rbconfig'
  require 'pp'
  require 'time'
  require 'fileutils'
  require 'pathname'
  require 'thread'
  require 'openssl'
  require 'tmpdir'
  require 'securerandom'

#
  module Senv
  #
    VERSION = '0.4.3'.freeze

    def Senv.version
      VERSION
    end

  #
    LICENSE = 'MIT'.freeze

    def Senv.license
      LICENSE
    end

  #
    SUMMARY = ''

  #
    DEFAULT = 'development'.freeze

    def Senv.default
      DEFAULT
    end

  #
    class Error < StandardError
    end

    def Senv.error!(*args, &block)
      raise Error.new(*args, &block)
    end

  #
    def Senv.env
      ENV['SENV']
    end

    def Senv.env=(env)
      if env
        ENV['SENV'] = env.to_s.strip
      else
        ENV.delete('SENV')
      end
    end

  #
    def Senv.load(*args)
      Senv.thread_safe do
      #
        env, options = Senv.parse_load_args(*args)

      #
        force = !!(options['force'] || options[:force])

      #
        a_parent_process_has_already_loaded_the_senv = (
          ENV['SENV'] == env &&
          ENV['SENV_LOADED'] &&
          ENV['SENV_ENVIRONMENT']
        )

        if(a_parent_process_has_already_loaded_the_senv && !force)
          Senv.env = env
          Senv.loaded = JSON.parse(ENV['SENV_LOADED'])
          Senv.environment = JSON.parse(ENV['SENV_ENVIRONMENT'])
          return env
        end

      #
        unless Senv.loading
          loading = Senv.loading

          begin
            Senv.loading = env

            Senv.loaded.clear
            Senv.environment.clear

            Senv.load_config_paths_for(env)

            Senv.env = env

            ENV['SENV'] = Senv.env
            ENV['SENV_LOADED'] = JSON.generate(Senv.loaded)
            ENV['SENV_ENVIRONMENT'] = JSON.generate(Senv.environment)

            return env
          ensure
            Senv.loading = loading
          end
        else
          a_config_file_imports_another_senv = (
            Senv.loading != env
          )

          if a_config_file_imports_another_senv
            Senv.load_config_paths_for(env)
            return env
          end

          a_config_file_imports_itself_recursively = (
            Senv.loading == env
          )

          if a_config_file_imports_itself_recursively
            :cowardly_refuse_to_infinitely_recurse
            return nil
          end
        end
      end
    end

    def Senv.load!(*args)
      env, options = Senv.parse_load_args(*args)
      options['force'] = options[:force] = true
      Senv.load(env, options)
    end
   
    def Senv.parse_load_args(*args)
      env = Senv.env || Senv.default
      options = Hash.new

      case args.first
        when String, Symbol
          env = args.shift.to_s
      end

      case args.first
        when Hash
          options = args.shift
      end

      [env, options]
    end

    def Senv.thread_safe(&block)
      THREAD_SAFE.synchronize(&block)
    end
    THREAD_SAFE = ::Monitor.new

    def Senv.load_config_paths_for(env)
      paths = Senv.config_paths_for(env)
      Senv.load_config_paths(*paths)
    end

    def Senv.config_paths_for(env)
      glob = "**/#{ env }.{rb,enc.rb}"

      Senv.directory.glob(glob).sort_by do |path|
        ext = path.basename.extname.split('.')
        [path.basename.to_s.size, ext.size]
      end
    end

    def Senv.load_config_paths(*paths)
      libs    = []
      configs = []

      paths.each do |path|
        exts = path.extname.split('.')[1..-1]

        case
          when exts.include?('rb')
            libs << path
          else
            configs << path
        end
      end

      {
        libs => :load_lib,
        configs => :load_config,
      }.each do |list, loader|
        list.each do |path|
          path = path.to_s

          Senv.debug({'loading' => path})

          if Senv.loaded.has_key?(path)
            Senv.debug({'skipping' => path})
            next
          end

          Senv.loaded[path] = nil

          captured =
            Senv.capturing_environment_changes do
              Senv.send(loader, path)
            end

          changes = captured.changes

          Senv.debug({path => changes})

          Senv.loaded[path] = changes

          captured.apply(Senv.environment)
        end
      end
    end

  #
    def Senv.loading
      @loading
    end

    def Senv.loading=(env)
      @loading = env.to_s.strip 
    end

    def Senv.loaded
      @loaded ||= {}
    end

    def Senv.loaded=(hash)
      @loaded = hash
    end

    def Senv.environment
      @environment ||= {}
    end

    def Senv.environment=(hash)
      @environment = hash
    end

  #
    def Senv.realpath(path)
      Pathname.new(path.to_s).realpath
    end

    def Senv.expand_path(path)
      (realpath(path) rescue File.expand_path(path)).to_s
    end

  #
    def Senv.root
      determine_root! unless @root
      @root
    end

    def Senv.root=(root)
      @root = realpath(root)
    end

    def Senv.determine_root!
      if ENV['SENV_ROOT']
        Senv.root = ENV['SENV_ROOT']
        return @root
      else
        Senv.search_path.each do |dirname|
          if test(?d, dirname)
            Senv.root = dirname
            return @root
          end
        end
      end

      msg = "[SENV] no `.senv` directory found via `#{ Senv.search_path.join(' | ') }`"
      Senv.error!(msg)
    end

    def Senv.directory
      Senv.root.join('.senv')
    end

    def Senv.search_path
      search_path = []

      if ENV['SENV_PATH']
        ENV['SENV_PATH'].split(':').each do |path|
          search_path << Senv.expand_path(path).to_s
        end
      else
        Pathname.pwd.realpath.ascend do |path|
          search_path << path.to_s
        end
      end

      search_path
    end

    def Senv.key_path
      Senv.directory.join('.key')
    end

    def Senv.key
      if ENV['SENV_KEY']
        ENV['SENV_KEY']
      else
        if Senv.key_path.exist?
          Senv.key_path.binread.strip
        else
          msg = "Senv.key not found in : #{ Senv.key_path }"
          Senv.error!(msg)
        end
      end
    end

    def Senv.key=(key)
      ENV['SENV_KEY'] = key.to_s.strip
    end

    def Senv.key_source
      if ENV['SENV_KEY']
        "ENV['SENV_KEY']"
      else
        Senv.key_path rescue '(no key source)'
      end
    end

  #
    ENCRYPTED_PATH_RE = Regexp.union(/\.enc(rypted)$/, /\.enc(rypted)?\./)

    def Senv.is_encrypted?(path)
      path.to_s =~ ENCRYPTED_PATH_RE
    end

  #
    def Senv.binread(path, options = {})
      data = IO.binread(path)

      encrypted =
        if options.has_key?('encrypted')
          options['encrypted']
        else
          Senv.is_encrypted?(path)
        end

      if encrypted
        data = 
          begin
            Blowfish.decrypt(Senv.key, data)
          rescue
            abort "could not decrypt `#{ path }` with key `#{ Senv.key }` from `#{ Senv.key_source }`"
          end
      end

      data
    end

    def Senv.read(path, options = {})
      Senv.binread(path)
    end

    def Senv.binwrite(path, data, options = {})
      encrypted =
        if options.has_key?('encrypted')
          options['encrypted']
        else
          Senv.is_encrypted?(path)
        end

      if encrypted
        data = 
          begin
            Blowfish.encrypt(Senv.key, data)
          rescue
            abort "could not encrypt `#{ data.to_s.split("\n").first }...` with key `#{ Senv.key }` from `#{ Senv.key_source }`"
          end
      end

      FileUtils.mkdir_p(File.dirname(path))

      IO.binwrite(path, data)
    end

    def Senv.write(path, data, options = {})
      Senv.binwrite(path, data, options)
    end

    def Senv.load_lib(path)
    #
      code = Senv.binread(path.to_s)
      binding = ::TOPLEVEL_BINDING
      filename = path.to_s

    #
      Kernel.eval(code, binding, filename)
    end

    def Senv.load_config(path)
    #
      erb = Senv.binread(path)
      expanded = ERB.new(erb).result(::TOPLEVEL_BINDING)
      buf = expanded

    #
      encoded = buf

      config =
        case
          when path =~ /yml|yaml/
            YAML.load(encoded)
          when path =~ /json/
            JSON.parse(encoded)
          else
            abort "unknown config format in #{ path }"
        end

    #
      unless config && config.is_a?(Hash)
        abort "[SENV] failed to load #{ path }"
      end

    #
      config.each do |key, val|
        ENV[key.to_s] = val.to_s
      end

    #
      config
    end

  #
    def Senv.debug(*args, &block)
      if args.empty? && block.nil?
        return Senv.debug?
      end

      return nil unless Senv.debug?

      lines = []

      args.each do |arg|
        case
          when arg.is_a?(String)
            lines << arg.strip
          else
            lines << arg.inspect.strip
        end
      end

      return nil if(lines.empty? && block.nil?)

      if lines
        lines.each do |line|
          STDERR.puts "# [SENV=#{ Senv.env }] : #{ line }"
        end
      end

      if block
        return block.call
      else
        true
      end
    end

    def Senv.debug?
      !!ENV['SENV_DEBUG']
    end

    def Senv.debug=(arg)
      if arg
        ENV['SENV_DEBUG'] = 'true'
      else
        ENV.delete('SENV_DEBUG')
      end
    end

  #
    def Senv.senvs
      @senvs ||= Hash.new
    end

    def Senv.for_senv!(senv)
      senv = senv.to_s

      IO.popen('-', 'w+') do |io|
        child = io.nil?

        if child
          Senv.load(senv)
          puts Senv.environment.to_yaml
          exit
        else
          YAML.load(io.read)
        end
      end
    end

    def Senv.for_senv(senv)
      senv = senv.to_s

      if Senv.senvs.has_key?(senv)
        return Senv.senvs[senv]
      end

      Senv.senvs[senv] = Senv.for_senv!(senv)
    end

    def Senv.get(senv, var)
      Senv.for_senv(senv)[var.to_s]
    end

    def Senv.get!(senv, var)
      Senv.for_senv!(senv)[var.to_s]
    end

  #
    module Blowfish
      def cipher(senv, key, data)
        cipher = OpenSSL::Cipher.new('bf-cbc').send(senv)
        cipher.key = Digest::SHA256.digest(key.to_s).slice(0,16)
        cipher.update(data) << cipher.final
      end

      def encrypt(key, data)
        cipher(:encrypt, key, data)
      end

      def decrypt(key, text)
        cipher(:decrypt, key, text)
      end

      def cycle(key, data)
        decrypt(key, encrypt(key, data))
      end
        
      def recrypt(old_key, new_key, data)
        encrypt(new_key, decrypt(old_key, data))
      end

      extend(self)
    end

  #
    def Senv.capturing_environment_changes(&block)
      EnvChangeTracker.track(&block)
    end

    class EnvChangeTracker < ::BasicObject
      def initialize(env)
        @env = env

        @changes = {
          :deleted => [],
          :updated => [],
          :created => [],
        }

        @change_for = proc do |key, val|
          if @env.has_key?(key)
            case
              when val.nil?
                {:type => :deleted, :info => [key, val]}
              when val.to_s != @env[key].to_s
                {:type => :updated, :info => [key, val]}
              else
                nil
            end
          else
            {:type => :created, :info => [key, val]}
          end
        end

        @track_change = proc do |key, val|
          change = @change_for[key, val]

          if change
            @changes[change[:type]].push(change[:info])
          end
        end
      end

      def changes
        @changes
      end

      def method_missing(method, *args, &block)
        @env.send(method, *args, &block)
      end

      def []=(key, val)
        @track_change[key, val]
        @env[key] = val
      end

      def replace(hash)
        hash.each do |key, val|
          @track_change[key, val]
        end
        @env.replace(hash)
      end

      def store(key, val)
        @track_change[key, val]
        @env.store(key, val)
      end

      def delete(key)
        @track_change[key, nil]
        @env.delete(key)
      end

      def apply(env)
        @changes[:created].each do |k, v|
          env[k] = v
        end
        @changes[:updated].each do |k, v|
          env[k] = v
        end
        @changes[:deleted].each do |k, v|
          env.delete(k)
        end
        @changes
      end

      THREAD_SAFE = ::Monitor.new

      def EnvChangeTracker.track(&block)
        THREAD_SAFE.synchronize do
          env = EnvChangeTracker.new(::ENV)

          ::Object.send(:remove_const, :ENV)
          ::Object.send(:const_set, :ENV, env)

          begin
            block.call
            env
          ensure
            ::Object.send(:remove_const, :ENV)
            ::Object.send(:const_set, :ENV, env)
          end
        end
      end
    end

  #
    class ::Pathname
      unless ::Pathname.pwd.respond_to?(:glob)
        def glob(glob, &block)
          paths = []

          Dir.glob("#{ self }/#{ glob }") do |entry|
            path = Pathname.new(entry)

            if block
              block.call(path)
            else
              paths.push(path)
            end
          end

          block ? nil : paths
        end
      end
    end
  end


### </lib src='lib/senv.rb'>

### <lib src='lib/senv/script.rb'>

#! /usr/bin/env ruby
#
  require 'json'
  require 'yaml'
  require 'base64'
  require 'securerandom'
  require 'fileutils'
  require 'pathname'
  require 'set'
  require 'openssl'
  require 'uri'
  require 'cgi'
  require 'shellwords'
  require 'tmpdir'
  require 'tempfile'
  require 'pp'
  require 'open3'

#
  module Senv
    class Script
      attr_accessor :source
      attr_accessor :root
      attr_accessor :env
      attr_accessor :argv
      attr_accessor :stdout
      attr_accessor :stdin
      attr_accessor :stderr
      attr_accessor :help

      def run!(env = ENV, argv = ARGV)
        before!
        init!(env, argv)
        parse_command_line!
        set_mode!
        run_mode!
        after!
      end

      def init!(env, argv)
        @klass = self.class
        @env = env.to_hash.dup
        @argv = argv.map{|arg| arg.dup}
        @stdout = $stdout.dup
        @stdin = $stdin.dup
        @stderr = $stderr.dup
        @help = @klass.help || Util.unindent(DEFAULT_HELP)
      end

      def self.before(&block)
        @before ||= []
        @before << block if block
        @before
      end

      def before!
        self.class.before.each{|block| block.call}
      end

      def self.after(&block)
        @after ||= []
        @after << block if block
        @after
      end

      def after!
        self.class.after.each{|block| block.call}
      end

      DEFAULT_HELP = <<-__
        NAME
          #TODO

        SYNOPSIS
          #TODO
           
        DESCRIPTION
          #TODO
           
        EXAMPLES
          #TODO
      __

      def parse_command_line!
        @options = Hash.new
        @opts = Hash.new

        argv = []
        head = []
        tail = []

        %w[ :: -- ].each do |stop|
          if((i = @argv.index(stop)))
            head = @argv.slice(0 ... i)
            tail = @argv.slice((i + 1) ... @argv.size) 
            @argv = head
            break
          end
        end

        @argv.each do |arg|
          case
            when arg =~ %r`^\s*:([^:\s]+)[=](.+)`
              key = $1
              val = $2
              @options[key] = val
            when arg =~ %r`^\s*(:+)(.+)`
              switch = $1
              key = $2
              val = switch.size.odd?
              @options[key] = val
            else
              argv.push(arg)
          end
        end

        argv += tail

        @argv.replace(argv)

        @options.each do |key, val|
          @opts[key.to_s.to_sym] = val
        end

        [@options, @opts]
      end

      def set_mode!
        case
          when respond_to?("run_#{ @argv[0] }")
            @mode = @argv.shift
          else
            @mode = nil
        end
      end

      def run_mode!
        if @mode
          return send("run_#{ @mode }")
        else
          if respond_to?(:run)
            return send(:run)
          end

          if @argv.empty?
            run_help
          else
            abort("#{ $0 } help")
          end
        end
      end

      def run_help
        STDOUT.puts(@help)
      end

      def help!
        run_help
        abort
      end

    #
      module Util
        def unindent(arg)
          string = arg.to_s.dup
          margin = nil
          string.each_line do |line|
            next if line =~ %r/^\s*$/
            margin = line[%r/^\s*/] and break
          end
          string.gsub!(%r/^#{ margin }/, "") if margin
          margin ? string : nil
        end

        def esc(*args)
          args.flatten.compact.map{|arg| Shellwords.escape(arg)}.join(' ')
        end

        def uuid
          SecureRandom.uuid
        end

        def tmpname(*args)
          opts = extract_options!(*args)

          base = opts.fetch(:base){ uuid }.to_s.strip
          ext = opts.fetch(:ext){ 'tmp' }.to_s.strip.sub(/^[.]+/, '')
          basename = opts.fetch(:basename){ "#{ base }.#{ ext }" }

          File.join(Dir.tmpdir, basename)
        end

        def tmpfile(*args, &block)
          opts = extract_options!(args)

          path = tmpname(opts)


          tmp = open(path, 'w+')
          tmp.binmode
          tmp.sync = true

          unless args.empty?
            src = args.join
            tmp.write(src)
            tmp.flush
            tmp.rewind
          end

          if block
            begin
              block.call(tmp)
            ensure
              FileUtils.rm_rf(path)
            end
          else
            at_exit{ Kernel.system("rm -rf #{ esc(path) }") }
            return tmp
          end
        end

        def extract_options!(args)
          unless args.is_a?(Array)
            args = [args]
          end

          opts = args.last.is_a?(Hash) ? args.pop : {}

          symbolize_keys!(opts)

          return opts
        end

        def extract_options(args)
          opts = extract_options!(args)

          args.push(opts)

          opts
        end

        def symbolize_keys!(hash)
          hash.keys.each do |key|
            if key.is_a?(String)
              val = hash.delete(key)

              if val.is_a?(Hash)
                symbolize_keys!(val)
              end

              hash[key.to_s.gsub('-', '_').to_sym] = val
            end
          end

          return hash
        end

        def symbolize_keys(hash)
          symbolize_keys!(copy(hash))
        end

        def copy(object)
          Marshal.load(Marshal.dump(object))
        end

        def debug!(arg)
          if arg.is_a?(String)
            warn "[DEBUG] #{ arg }"
          else
            warn "[DEBUG] >\n#{ arg.to_yaml rescue arg.pretty_inspect }"
          end
        end

        def debug(arg)
          debug!(arg) if debug?
        end

        def debug?
          ENV['SCRIPT_DEBUG'] || ENV['DEBUG']
        end

        def sys!(*args, &block)
          opts = extract_options!(args)

          cmd = args

          debug(:cmd => cmd)

          open3 = (
            block ||
            opts[:stdin] ||
            opts[:quiet] ||
            opts[:capture]
          )

          if(open3)
            stdin = opts[:stdin]
            stdout = ''
            stderr = ''
            status = nil

            Open3.popen3(*cmd) do |i, o, e, t|
              ot = async_reader_thread_for(o, stdout) 
              et = async_reader_thread_for(e, stderr) 

              i.write(stdin) if stdin
              i.close

              ot.join
              et.join

              status = t.value
            end

            if status.exitstatus == 0
              result = nil

              if opts[:capture]
                result = stdout.to_s.strip
              else
                if block
                  result = block.call(status, stdout, stderr)
                else
                  result = [status, stdout, stderr]
                end
              end

              return(result)
            else
              if opts[:capture]
                abort("#{ [cmd].join(' ') } #=> #{ status.exitstatus }")
              else
                false
              end
            end
          else
            env = opts[:env] || {}
            argv = [env, *cmd]
            system(*argv) || abort("#{ [cmd].join(' ') } #=> #{ $?.exitstatus }")
            return true
          end
        end

        def sys(*args, &block)
          begin
            sys!(*args, &block)
          rescue Object
            false
          end
        end

        def async_reader_thread_for(io, accum)
          Thread.new(io, accum) do |i, a|
            Thread.current.abort_on_exception = true

            while true
              buf = i.read(8192)

              if buf
                a << buf
              else
                break
              end
            end
          end
        end

        def realpath(path)
          Pathname.new(path.to_s).expand_path.realpath.to_s
        end

        def filelist(*args, &block)
          accum = (block || proc{ Set.new }).call
          raise ArgumentError.new('accum.class != Set') unless accum.is_a?(Set)

          _ = args.last.is_a?(Hash) ? args.pop : {}

          entries = args.flatten.compact.map{|arg| realpath("#{ arg }")}.uniq.sort

          entries.each do |entry|
            case
              when test(?f, entry)
                file = realpath(entry)
                accum << file

              when test(?d, entry)
                glob = File.join(entry, '**/**')

                Dir.glob(glob) do |_entry|
                  case
                    when test(?f, _entry)
                      filelist(_entry){ accum }
                    when test(?d, entry)
                      filelist(_entry){ accum }
                  end
                end
            end
          end

          accum.to_a
        end

        def slug_for(*args, &block)
          Slug.for(*args, &block)
        end

        extend Util
      end

      def self.utils(&block)
        block ? Util.module_eval(&block) : Util
      end

      def utils
        Util
      end

      def u
        Util
      end

    #
      class Slug < ::String
        Join = '-'

        def Slug.for(*args)
          options = args.last.is_a?(Hash) ? args.pop : {}

          join = (options[:join] || options['join'] || Join).to_s

          string = args.flatten.compact.join(' ')

          tokens = string.scan(%r`[^\s#{ join }]+`)

          tokens.map! do |token|
            token.gsub(%r`[^\p{L}/.]`, '').downcase
          end

          tokens.map! do |token|
            token.gsub(%r`[/.]`, join * 2)
          end

          tokens.join(join)
        end
      end

    #
      def noop
        ENV['SCRIPT_NOOP'] || ENV['NOOP']
      end

      alias_method :noop?, :noop

    #
      def self.help(*args)
        @help ||= nil

        unless args.empty?
          @help = utils.unindent(args.join)
        end

        @help
      end

      def self.run(*args, &block)
        modes =
          if args.empty?
            [nil]
          else
            args
          end

        modes.each do |mode|
          method_name =
            if mode
              "run_#{ mode }"
            else
              "run"
            end

          define_method(method_name, &block)
        end
      end

    #
      def Script.klass_for(&block)
        Class.new(Script) do |klass|
          def klass.name; "Script::Klass__#{ SecureRandom.uuid.to_s.gsub('-', '_') }"; end
          klass.class_eval(&block)
        end
      end

      def self.run!(*args, &block)
        STDOUT.sync = true
        STDERR.sync = true

        %w[ PIPE INT ].each{|signal| Signal.trap(signal, "EXIT")}

        script = (
          source = 
            if binding.respond_to?(:source_location)
              File.expand_path(binding.source_location.first)
            else
              File.expand_path(eval('__FILE__', block.binding))
            end

          root = File.dirname(source)

          klass = Script.klass_for(&block)

          instance = klass.new

          instance.source = source
          instance.root = root

          instance
        )

        script.run!(*args)
      end
    end
  end

#
  def Senv.script(*args, &block)
    Senv::Script.run!(*args, &block)
  end


### </lib src='lib/senv/script.rb'>


 
}
