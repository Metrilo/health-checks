Gem::Specification.new do |s|
  s.name = 'health_checks'
  s.version = '0.0.1'
  s.summary = 'Various health check utilities to use in Metrilo services'
  s.authors = ['Yassen Bantchev']
  s.files = Dir['{lib}/**/*.rb']
  s.require_path = 'lib'
  s.add_runtime_dependency 'okcomputer'
end
