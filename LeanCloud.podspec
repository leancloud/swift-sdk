Pod::Spec.new do |s|
  s.name         = 'LeanCloud'
  s.version      = '12.0.0'
  s.license      = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
  s.summary      = 'LeanCloud Swift SDK'
  s.homepage     = 'https://leancloud.cn/'
  s.authors      = 'LeanCloud'
  s.source       = { :git => 'https://github.com/leancloud/swift-sdk.git', :tag => s.version }

  s.ios.deployment_target     = '10.0'
  s.osx.deployment_target     = '10.12'
  s.tvos.deployment_target    = '10.0'
  s.watchos.deployment_target = '3.0'

  s.subspec 'LocalStorage' do |ss|
    ss.source_files = 'Sources/LocalStorage/**/*.swift'
  end

  s.subspec 'Storage' do |ss|
    ss.dependency 'Alamofire', '~> 4.7'
    ss.dependency 'LeanCloud/LocalStorage'

    ss.source_files = 'Sources/Storage/**/*.swift'
    ss.resources = 'Sources/Storage/AppRouterCache.xcdatamodeld'
  end
end
