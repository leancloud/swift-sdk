Pod::Spec.new do |s|
  s.name         = 'LeanCloud'
  s.version      = '11.0.0'
  s.license      = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
  s.summary      = 'LeanCloud Swift SDK'
  s.homepage     = 'https://leancloud.cn/'
  s.authors      = 'LeanCloud'
  s.source       = { :git => 'https://github.com/leancloud/swift-sdk.git', :tag => s.version }

  s.ios.deployment_target     = '8.0'
  s.osx.deployment_target     = '10.10'
  s.tvos.deployment_target    = '9.0'
  s.watchos.deployment_target = '2.0'

  s.subspec 'Storage' do |ss|
    ss.dependency 'Alamofire', '~> 4.5'
    ss.source_files = 'Sources/Storage/**/*.swift'
  end
end
