## senv.gemspec
#

Gem::Specification::new do |spec|
  spec.name = "senv"
  spec.version = "0.4.2"
  spec.platform = Gem::Platform::RUBY
  spec.summary = "senv"
  spec.description = "description: senv kicks the ass"
  spec.license = "Ruby"

  spec.files =
["LICENSE",
 "README",
 "Rakefile",
 "bin",
 "bin/senv",
 "lib",
 "lib/script.rb",
 "lib/senv",
 "lib/senv.rb",
 "s",
 "s/foo.enc.rb",
 "senv.gemspec",
 "test",
 "test/leak.rb",
 "test/lib",
 "test/lib/testing.rb",
 "test/map_test.rb"]

  spec.executables = ["senv"]
  
  spec.require_path = "lib"

  spec.test_files = nil

  

  spec.extensions.push(*[])

  spec.author = "Ara T. Howard"
  spec.email = "ara.t.howard@gmail.com"
  spec.homepage = "https://github.com/ahoward/senv"
end
