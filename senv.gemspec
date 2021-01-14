## senv.gemspec
#

Gem::Specification::new do |spec|
  spec.name = "senv"
  spec.version = "0.4.2"
  spec.platform = Gem::Platform::RUBY
  spec.summary = "senv"
  spec.description = "description: senv kicks the ass"
  spec.license = "MIT"

  spec.files =
["LICENSE",
 "README",
 "Rakefile",
 "a.rb",
 "bin",
 "bin/senv",
 "dist",
 "dist/senv-0.4.2-linux-x86.tgz",
 "dist/senv-0.4.2-linux-x86_64.tgz",
 "dist/senv-0.4.2-osx.tgz",
 "dist/senv.rb",
 "dist/senv.sh",
 "lib",
 "lib/senv",
 "lib/senv.rb",
 "lib/senv/script.rb",
 "senv.gemspec"]

  spec.executables = ["senv"]
  
  spec.require_path = "lib"

  spec.test_files = nil

  

  spec.extensions.push(*[])

  spec.author = "Ara T. Howard"
  spec.email = "ara.t.howard@gmail.com"
  spec.homepage = "https://github.com/ahoward/senv"
end
