NAME
====
senv - secure 12-factor env vars for your apps, in any lang, local and remote

![](https://raw.githubusercontent.com/ahoward/senv/563c4d069da2e03d4ea60d3cd6fad319a3dc0271/images/senv.svg) 

---

![](https://i.giphy.com/media/SvpHrehWvbZiin27sm/giphy.webp)

SYNOPSIS
========
```bash

  ~> senv @production run-you-server-in-the-production-environment.py

  ~> SENV=development senv your-development-server.rb

  ~> export SENV=test
  ~> senv run-my-tests.go

```

DESCRIPTION
===========
*senv* is a command that lets you run other commands under named sets of
environment variables.  named sets are specified via the _@name_ syntax, or by
setting the meta-environment variable SENV.  the named set, which is stored
locally, but encrypted, will be unpacked before running your process, which
can be written in any language, and all the variables for that SENV will be
loaded into the process environment.  *senv* stores it's environment files in
your project's '.senv' directory so, given:

```text

  .senv/
  ├── development.enc.json
  ├── development.json
  ├── production.enc.json
  └── production.json

```

one can run commands such as

```bash

  # load all development environment variables, encrypted and non-encrypted,
  # before running app.py

    ~> senv @development app.py 

  # load the encrypted/non-encrypted SENV named 'production' and run app.js

    ~> export SENV=production
    ~> senv app.js

  # if no command is given, simply show the @named environment

    ~> senv @development

    ~> senv @production | grep DATABASE_URL

```

the '.senv' directory is searched for 'upwards', similarly to how git finds
its '.git' directory, and will normally exist at your project's root.  in it
are text based config files in .json, .yaml, or .rb format, in both encrypted,
and un-encrypted flavors.  senv merges them into one set at load time, using
the encryption key stored in '.senv/.key'

*NOTE:* you will never check in your .senv/.key file.  *ADD IT TO YOUR .gitignore*

*NOTE*: see above^ note.  #important

config files can be either non-encrypted, or encrypted.  encrpted files are
stored with '.enc' in the filename, obviously.

config files can be either non-encrypted, for example 'development.json', or
encrypted, as for the filename 'development.enc.json'.  for both 'json' and
'yaml' formats, the files must be simple dictionaries/hashes containing
key=var pairs, which will be set in the process's environment

so given .senv/development.yaml containing

```yaml

  APP_ENV : development
  USE_SSL : false

```

and .senv/development.enc.yaml containing (albeit as encrypted text)

```yaml

  API_KEY : very-sensitive-info-654321

```

running

```bash

  ~> senv @development

```

will show (or run another command) in this environment

```yaml

  ---
  APP_ENV : development
  USE_SSL : false
  API_KEY : very-sensitive-info-654321

```

of course, senv also supports management of these files

```bash

  # encrypt a config file

  ~> cat /tmp/development.json | senv .write .senv/development.enc.json

  # read a config file

  ~> senv .read .senv/development.enc.json

  # edit a config file using the value of $EDITOR like a good unix gal

  ~> senv .edit .senv/production.enc.rb

```

note that, in addition to simple yaml, and json files, one can also load '.rb'
files, which are parsed with full ruby syntax.  and this can massively
simplify managing complex sets of environment variables for any application.

this does what you'd expect:

```ruby

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

```

and so does this

```ruby

  # file : .senv/all.enc.rb
  ('A' .. 'Z').each do |alpha|
    ENV[alpha] = 'one for every letter in the alphabet'
  end
  

```

one can access the environment as in the examples above, using the senv cli
program to run another command, but the environment can be loaded
programatically as well:

in your shell scripts via

```bash

  # import all senv env vars into this script
  eval $(senv init -)

```

or, in ruby programs via

```ruby

  require 'senv'

  if ENV['APP_ENV'] == 'production'
    Senv.load(:production)
  else
    Senv.load(:development)
  end

```

learn more, and increase your ninja score, by installing senv and running

```bash

  senv .help

```

INSTALL
=======
senv supports 3 methods of installation

Stand Alone Binary Distribution
-------------------------------
* grab the distribution for your platform at https://github.com/ahoward/senv/tree/main/dist
  * if you don't know which flavor of linux you are on run `uname -a` and look at the output
* unpack the distribution
* make sure the ./bin/ directory in the distribution is your $PATH

Stand Alone, Dependency-less, Ruby Script
-----------------------------------------
* grab the distribution here https://github.com/ahoward/senv/blob/main/dist/senv.rb
* drop it in, for example, ./lib/, and 'require "./lib/senv.rb"'
* the distribution is both the lib, and the *command line script*, so that
  *same file* can be saved both as './lib/senv.rb' *and* './bin/senv', a
  clever person might save just as './lib/senv.rb' and make a symlink
  from './lib/senv.rb' to './bin/senv'

RubyGems/Bundler
----------------
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
because you don't have a better way to give it to people.  and you'll do this
for each of the 17 config settings your 12-factor app needs. as will the other
11 developers that touch the code over the next 2 years.   

check it all in.  drive all blames into git.

encrypt what is sensitive, and reduce your problem to merely needing to give
the next girl *one single key* to unpack the whole lot.  btw, for this,
passing around an senv key, i recommend using

https://onetimesecret.com/

Q2:
---
i call b.s., the key _and_ the program that uses it to encrypt are still on
disk.  i'm paranoid and want to solve this problem, along with rewriting the
laws of thermodynamics to eliminate 'time t' from the equations.  i program
scala and haskell.

A2:
---
carlo has #2 solved for you, at least mostly - https://www.goodreads.com/book/show/36442813-the-order-of-time

now, about the key.  there are two main approaches to keeping the key, the
code that uses it, and the config values, separate:

0.  this one really doesn't count as one of the two, but if you are not ultra
    paranoid it is worth mentioning that the difference between having files
    that are encrypted at rest, with a key that needs located, and a process
    that knows how to use that key to unpack a binary file full of garbage is
    *light years* more complex to exploit vs. having unencrypted credentials
    lying around in your repo for any backup, stray command, or git commit to
    reveal to the world.

1.  symlinks are magic.  use a thumb drive.  keep all your keys there.
    symlink them into your project.  unplug the drive when you are not running
    'npm install' or anytime your paranoia compells you to do something.  rest
    well knowing attackes need something you know, the credentials, and
    something you have, the thumb drive.

2.  avoid complexity.  learn your shell.  set one damn envronment varialbe
    when you start working on a project.  bask in the free time and lack of
    complexity.  indeed, managing an single environment variable setting can,
    and does, befuddle many a programmer, but this is a great time to dicuss
    whether those programmers should have access to any sensitive information,
    let alone in unencrypted files lying around on thier personal machines.
    doing it the 'unix way' just isn't that hard:

```bash

    # export the var, do the work
    ~> export SENV_ENV=teh-passwordz-y

    # fancy 
    ~> SENV_KEY=my-key exec $SHELL

    # fancier
    ~> SENV_KEY=my-key tmuxinator

    # ultra fancy and magic, also possibly broken...
    ~> SENV_KEY=teh-key visual-studio-magick-coding-ide-thing

```

all of the above a good solutions, execpt the last one. that won't work.
acutally, it might.  if you are uncomfortable on the command line, and manging
environment variables, senv may not be for you.  however, if that is the case
then managing *unencrypted* files full of api keys is *definitely not for
you*.

in the end.  simple is better, and the power of plaintext endures across
presidents and epidemics.

WHY?
====
so many tools exist to load a file full of environment variables.  all of them
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

solutions to this problem exist, indeed, i authored the original solution for
the ruby programming language:

* https://github.com/ahoward/sekrets

this solution was eventually adapted and merged into 'Ruby on Rails':

* https://github.com/rails/rails/issues/25095#issuecomment-269054302
* https://guides.rubyonrails.org/4_1_release_notes.html

solutions exist for es6, javascript, go, and many languages.  each operates
'cowboy differently':

* https://github.com/kunalpanchal/secure-env
* https://github.com/envkey/envkeygo

however, all of these solutions, including my own, operate at the wrong level,
which is to say at the language or framework level.  this misses, entirely,
the point of configuring applications via the environment in the ordained
12-factor way; by requiring tight integration, such as the addition of
libraries and tooling into projects to manage, load, and set environment
variables, we reduce significantly the simplicity of a pure 12-factor app that
does only.

```javascript

    const DATABASE_URL = process.env.DATABASE_URL

```

it's easy to make this mistake and, so long as your project remains a
monolith, it works just fine.  until it doesn't.

as many of us know, a real, modern, web project is unlikely to remain a single
process in a single framework and language.  micro-services will be
introduced.  background jobs will get introduced.  someone will split the main
web app from the consumer app.  everything will get re-written in node, and
then go.  finally, each developer in every language will solve the problem
their own way, and pass around unencrypted text files full of sensitive
information all day long like someone yelling 'b-crypt' very slowly in bounded
time.  someone will port the application deployment from heroku to gcp, and
re-tool setting 100 confiuration variables instead of the one meta SENV\_KEY
to rule them all.  he'll be a 'dev-ops' guy, kind of an asshole, and he'll
grind deployments down from a 3 minute process to a 3 week fight about vpns.

don't be that guy.

REFMASTER, OF THE UNIVERSE
==========================
  http://github.com/ahoward/senv

TL;DR;
======
it's at the bottom because everyone should RTfM ;-)

```bash
  ↟ senv[]@master $ senv .setup .
  [SENV] setup /home/ahoward/git/ahoward/senv/.senv
  - .senv/all.rb
  - .senv/development.enc.rb
  - .senv/development.rb
  - .senv/production.enc.rb
  - .senv/production.rb

  ↟ senv[]@master $ cat .senv/all.rb
  ENV['A'] = 'one'
  ENV['B'] = 'two'
  ENV['C'] = 'three'

  ↟ senv[]@master $ cat .senv/production.rb
  Senv.load(:all)
  ENV['B'] = 'two (via production.rb)'

  ↟ senv[]@master $ cat .senv/production.enc.rb
  0GWID?䱐xAǼdW)\        1waxE͑!k

  ↟ senv[]@master $ senv .read .senv/production.enc.rb
  Senv.load(:all)
  ENV['C'] = 'three (via production.enc.rb)'

  ↟ senv[]@master $ cat .senv/.key
  770db0fd-fddc-4c8c-a264-37d15766d0a5

  ↟ senv[]@master $ senv @production
  ---
  A: one
  B: two (via production.rb)
  C: three (via production.enc.rb)

  ↟ senv[]@master $ rm .senv/.key

  ↟ senv[]@master $ senv @production
  Senv.key not found in : /home/ahoward/git/ahoward/senv/.senv/.key

  ↟ senv[]@master $ export SENV_KEY=770db0fd-fddc-4c8c-a264-37d15766d0a5

  ↟ senv[]@master $ senv @proudction
  ---
  A: one
  B: two (via production.rb)
  C: three (via production.enc.rb)

  ↟ senv[]@master $ cat a.sh
  #! /bin/sh
  echo $C

  ↟ senv[]@master $ senv ./a.sh
  three (via production.enc.rb)

```

FINALLY
=======
```vim

  :wqa!

```

