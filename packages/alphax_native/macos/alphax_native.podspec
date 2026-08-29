Pod::Spec.new do |s|
  s.name             = 'alphax_native'
  s.version          = '1.0.0-rc.4'
  s.summary          = 'AlphaX native URLSession transport.'
  s.description      = <<-DESC
AlphaX Apple URLSession transport adapter for macOS.
                       DESC
  s.homepage         = 'https://github.com/auvana-ventures/alphax'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Auvana Ventures' => 'engineering@auvana.ventures' }
  s.source           = { :path => '.' }
  # Classes/AlphaXNativePlugin.swift is a symlink to the shared iOS source.
  s.source_files     = 'Classes/**/*'
  s.dependency       'FlutterMacOS'
  s.platform         = :osx, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
