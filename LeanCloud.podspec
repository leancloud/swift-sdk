Pod::Spec.new do |s|
  s.name         = 'LeanCloud'
  s.version      = '1.1.0-beta'
  s.license      = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
  s.summary      = 'LeanCloud Swift SDK'
  s.homepage     = 'https://leancloud.cn/'
  s.authors      = 'LeanCloud'
  s.source       = { :git => 'https://github.com/leancloud/swift-sdk.git', :tag => s.version }

  s.subspec 'Storage' do |storage|
    storage.dependency 'Alamofire', '~> 3.4'

    storage.ios.deployment_target     = '8.0'
    storage.osx.deployment_target     = '10.9'
    storage.tvos.deployment_target    = '9.0'
    storage.watchos.deployment_target = '2.0'

    storage.source_files = 'Sources/Storage/**/*.swift'
  end
end
