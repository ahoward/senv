NAME
====
  senv - the secure 12-factor environment variable tool your mother warned you to use

SYNOPSIS
========
  senv ./app/entrypoint/

DESCRIPTION
===========

Motivation
----------
Many tools exist to load a file full of environment variables.  all of them
expose these variables to arbitrary code anytime you:

* run `npm install`, `bundle install`, `pip install`
* accidentally commit .env files to git/version control
* loose your laptop
* a trillion other sloppy ways of leaking unencrypted files full of sensitive
  information from your developer machine to the world wide web

This problem is neither theoritical nor FUD based:

* https://www.helpnetsecurity.com/2020/04/17/typosquatting-rubygems/
* https://codeburst.io/how-secure-is-your-environment-file-in-node-js-7c4d2ed0d15a 
* https://www.twilio.com/blog/2017/08/find-projects-infected-by-malicious-npm-packages.html
* https://blog.sonatype.com/sonatype-spots-malicious-npm-packages
* *and a million other reasons not to store unencrypted environment variables*
* https://lmgtfy.app/#gsc.tab=0&gsc.q=malicious%20packages%20env

Solutions to this problem exist, I authored the original solution for the ruby
programming language:

* https://github.com/ahoward/sekrets

This solution was eventually adapted and merged into 'Ruby on Rails':

* https://github.com/rails/rails/issues/25095#issuecomment-269054302
* https://guides.rubyonrails.org/4_1_release_notes.html

Solutions exist for es6, javascript, go, and many languages.  Each operates
differently:

* https://github.com/kunalpanchal/secure-env
* https://github.com/envkey/envkeygo

However, all of these solutions, including mine, operate at the wrong level,
which is to say at the language or framework level.  This misses, entirely,
the point of configuring applications via the environment; by requiring tight
integration, such as the addition of libraries and tooling into projects to
manage, load, and set environment variables, we reduce significantly the
simplicity of a pure 12-factor app that does only.


```
  const DATABASE_URL = process.env.DATABASE_URL;

```

It's easy to make this mistake and, so long as your project remains a
monolith, it works just fine.  But, as many of us know, a real, modern, web
project is unlikely to do so.  Micro-services will be introduced.  The young
girl will split the Django app into a backend API and a Next.js frontend, both
deployed to different GCP targets, and both requiring access to ALL
application configuration.   Of course, everyone will cowboy this, adding a
hidden mine-field burried deep in our 



EXAMPLES
========

URI
===
  http://github.com/ahoward/senv

INSTALL
=======
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
