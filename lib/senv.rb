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
    VERSION = '0.4.2'.freeze

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
