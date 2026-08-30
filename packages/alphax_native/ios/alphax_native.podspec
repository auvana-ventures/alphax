Pod::Spec.new do |s|
  s.name             = 'alphax_native'
  s.version          = '1.0.0'
  s.summary          = 'AlphaX native URLSession transport.'
  s.description      = <<-DESC
AlphaX Apple URLSession transport adapter for iOS.
                       DESC
  s.homepage         = 'https://github.com/auvana-ventures/alphax'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Auvana Ventures' => 'engineering@auvana.ventures' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency       'Flutter'
  s.platform         = :ios, '15.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end
