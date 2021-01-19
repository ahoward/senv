NAME
====
senv - 12-factor env vars for your apps, checked *securely* into your repo, for dev and prod, in any language.

SYNOPSIS
========
    ~> senv @development ./node/server

    ~> senv @staging ./go/server

    ~> senv @production ./ruby/server


DESCRIPTION
===========

*senv* is a command line tool that let's you manage named sets of encrypted
environment variables across platforms, frameworks, and languages.  it works
for development and production, on dev boxen, and in docker

*senv* operates over text files stored in a '.senv' directory, typically in
your project's root.  in this directory are meta stuff like your key:

    .senv/.key

and config files in .json, .yaml, or .rb format:

    .senv/development.json
    .senv/development.enc.json
    .senv/production.json
    .senv/production.enc.json

*NOTE:* you will never check in your .senv/.key file.  *ADD IT TO YOUR .gitignore*

config files can be either non-encrypted, or encrypted.  encrpted files are
stored with '.enc' in the filename, obviously.

for json, or yaml (yml) files, one can define static dictionaries of
environment key=val mappings, for example, in a file named

    .senv/development.yaml

one might have:

    APP_ENV : development
    USE_SSL : false

and, in a file that, to the naked eye, is full of encrypted garbage, named

    .senv/development.enc.yaml

something like: 

    API_KEY : very-sensitive-info-654321

now, you can run commands with these variables loaded into the processs'
environment with, for example

    ~> senv @development ./start/my/server-process.js

of course, senv also supports management of these files, for example
encrypting them is as simple as

    ~> cat /tmp/development.json | senv .write .senv/development.enc.json

and reading it back as simply

    ~> senv .read .senv/development.enc.json

it can spawn your $EDITOR directly via

    ~> senv .edit .senv/production.enc.rb

in addition to simple yaml, and json files, one can also load '.rb' files,
which are parsed with ruby syntax.  and this can massively simplify managing
complex sets of environment variables for any application

for example, this does what you'd expect

    # file : .senv/all.enc.rb
    ENV['API_KEY'] = '1234-xyz'


    # file : .senv/development.rb
    Senv.load(:all)
    ENV['DB_URL'] = 'db://dev-url'


    # file : .senv/production.rb
    Senv.load(:all)
    ENV['DB_URL'] = 'db://prod-url'


    ~> senv @production
    ---
    API_KEY : 1234-xyz
    DB_URL : db://prod-url

one can access the environment as in the examples above, using the senv cli
program to run another command, but the environments can also be loaded into
shell scripts via

    # import all senv env vars into this script
    eval $(senv init -)

or, in ruby programs via

    require 'senv'
    Senv.load( ENV['APP_ENV'] || ENV['RAILS_ENV'] || 'development' )

learn more by installing senv and running

    senv .help

INSTALL
=======
senv supports 3 methods of installation

* as a standalone binary, with *zero dependencies*
  * grab the distribution for your platform at https://github.com/ahoward/senv/tree/main/dist
  * if you don't know which flavor of linux you are on run `uname -a` and
  * look at the output
  * unpack the distribution
  * make sure the ./bin/ directory in the distribution is your $PATH

* as standalone ruby file, depending only on ruby (not rubygems/bundler etc)
  * grab the distribution here https://github.com/ahoward/senv/blob/main/dist/senv.rb
  * drop it in, for example, ./lib/, and 'require "./lib/senv.rb"'
  * the distribution is both the lib, and the command line script, so that
    *same file* can be saved both as './lib/senv.rb' *and* './bin/senv', a
    clever person might save just as './lib/senv.rb' and make a symlink
    './bin/senv' -> './lib/senv.rb'

* via rubygems/bundler
  * in Gemfile, gem 'senv'
  * or via rubygems, 'gem install senv'

BIKESHED
========

Q1:
---

isn't this an imaginary problem?  aren't i still pretty professional dropping
all my crap in a .env file and calling it a day?

A1:
---

no.

you will check it in.  you will put it in your backups.  but most of all
you'll pass all the info inside it around in slack, email, text, and whatsapp
because you don't have a better way to give it to people.

check it in.  drive all your blames into git.  have mercy on the developers
that come after to you and make them need *one peice* of information to get the
app running.  ps.  also use docker, but that is for another day...

now, about the key.  there are two main approaches.

1) store all your keys on a thumbdrive, symlink them into your projects
2) just understand how to set *one environment varible*, your SENV\_KEY and do
that by hand when you start work on a project.  aka

    export SENV_KEY=my-key

or get fancy

    SENV_KEY=my-key exec $SHELL

if you have trouble managing a single environment varible in your shell(s) ask
yourself if you should have unencrypted credentials for your employer or
client's application on your hard drive...


WHY?
----

many tools exist to load a file full of environment variables.  all of them
expose these variables to arbitrary code anytime you:

* run `npm install`, `bundle install`, `pip install`
* accidentally commit .env files to git/version control
* loose your laptop
* a trillion other sloppy ways of leaking unencrypted files full of sensitive
  information from your developer machine to the world wide web

this problem is neither theoritical nor FUD based:

* https://www.helpnetsecurity.com/2020/04/17/typosquatting-rubygems/
* https://codeburst.io/how-secure-is-your-environment-file-in-node-js-7c4d2ed0d15a 
* https://www.twilio.com/blog/2017/08/find-projects-infected-by-malicious-npm-packages.html
* https://blog.sonatype.com/sonatype-spots-malicious-npm-packages
* *and a million other reasons not to store unencrypted environment variables*
* https://lmgtfy.app/#gsc.tab=0&gsc.q=malicious%20packages%20env

solutions to this problem exist, i authored the original solution for the ruby
programming language:

* https://github.com/ahoward/sekrets

this solution was eventually adapted and merged into 'Ruby on Rails':

* https://github.com/rails/rails/issues/25095#issuecomment-269054302
* https://guides.rubyonrails.org/4_1_release_notes.html

solutions exist for es6, javascript, go, and many languages.  each operates
differently:

* https://github.com/kunalpanchal/secure-env
* https://github.com/envkey/envkeygo

however, all of these solutions, including some of my work, operate at the
wrong level, which is to say at the language or framework level.  this misses,
entirely, the point of configuring applications via the environment; by
requiring tight integration, such as the addition of libraries and tooling
into projects to manage, load, and set environment variables, we reduce
significantly the simplicity of a pure 12-factor app that does only.


    const DATABASE_URL = process.env.DATABASE_URL;


it's easy to make this mistake and, so long as your project remains a
monolith, it works just fine.  until it doesn't.  as many of us know, a real,
modern, web project is unlikely to remain a single process in a single
framework and language.  micro-services will be introduced.  background jobs
will get introduced.  someone will split the main web app from the consumer
app.  everything will get re-written in node, and then go.  finally, each
developer in every language will solve the problem their own way, and pass
around unencrypted text files full of sensitive information all day long like
someone yelling 'b-crypt' very slowly in bounded time.  someone will port the
application deployment from heroku to gcp, and re-tool setting 100
confiuration variables instead of the one meta SENV\_KEY to rule them all.


EXAMPLES
========
# setup a project with a .senv directory and key
#
  ~> senv .setup .

# store your environment variables in the repo, but _encrypted_
#
  ~> cat development.json | senv .write .senv/development.enc.json 
  ~> cat production.json | senv .write .senv/production.enc.json 

# run your app under various 'sets' of environment variables, but sleep well,
# knowing you can check these into you repo
#
  ~> senv @development ./app/server

  ~> senv @production ./app/server

REF
===
  http://github.com/ahoward/senv
