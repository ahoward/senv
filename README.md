NAME
  senv - the secure 12-factor environment variable tool your mother told you to use

SYNOPSIS
  senv 

DESCRIPTION

EXAMPLES

URI
  http://github.com/ahoward/senv

INSTALL
  senv supports 3 methods of installation

  1. as a standalone binary, with *zero dependencies*
    - grab the distribution for your platform at https://github.com/ahoward/senv/tree/main/dist
    - if you don't know which flavor of linux you are on run `uname -a` and
      look at the output
    - unpack the distribution
    - make sure the ./bin/ directory in the distribution is your $PATH

  2. as standalone ruby file, depending only on ruby (not rubygems/bundler etc)
     - grab the distribution here https://github.com/ahoward/senv/blob/main/dist/senv.rb
     - drop it in, for example, ./lib/, and 'require "./lib/senv.rb"'
     - the distribution is both the lib, and the command line script, so that
       *same file* can be saved both as './lib/senv.rb' *and* './bin/senv', a
       clever person might save just as './lib/senv.rb' and make a symlink
       './bin/senv' -> './lib/senv.rb'

  3. via rubygems/bundler
    - in Gemfile, 'gem "senv"'
    - or via rubygems, 'gem install senv'
