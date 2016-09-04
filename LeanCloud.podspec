Pod::Spec.new do |s|
  s.name         = 'LeanCloud'
  s.version      = '1.1.0-beta'
  s.license      = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
  s.summary      = 'LeanCloud Swift SDK'
  s.homepage     = 'https://leancloud.cn/'
  s.authors      = 'LeanCloud'
  s.source       = { :git => 'https://github.com/leancloud/swift-sdk.git', :tag => s.version }
  s.source_files = 'Source/**/*.swift'

  s.ios.deployment_target     = '8.0'
  s.osx.deployment_target     = '10.9'
  s.tvos.deployment_target    = '9.0'
  s.watchos.deployment_target = '2.0'

  s.dependency 'Alamofire', '~> 3.4'
end
