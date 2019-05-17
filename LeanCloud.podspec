Pod::Spec.new do |s|
  s.name         = 'LeanCloud'
  s.version      = '16.0.0'
  s.license      = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
  s.summary      = 'LeanCloud Swift SDK'
  s.homepage     = 'https://leancloud.cn/'
  s.authors      = 'LeanCloud'
  s.source       = { :git => 'https://github.com/leancloud/swift-sdk.git', :tag => s.version }
  s.swift_version = '5.0'

  s.ios.deployment_target     = '8.0'
  s.osx.deployment_target     = '10.12'
  s.tvos.deployment_target    = '10.0'
  s.watchos.deployment_target = '3.0'

  s.subspec 'Storage' do |ss|
    ss.dependency 'Alamofire', '~> 4.8.0'

    ss.source_files = 'Sources/Storage/**/*.{swift}'
  end

  s.subspec 'IM' do |ss|
    ss.dependency 'SwiftProtobuf', '~> 1.5.0'
    ss.dependency 'Starscream', '~> 3.1.0'
    ss.dependency 'FMDB', '~> 2.7.0'

    ss.dependency 'LeanCloud/Storage'

    ss.source_files = 'Sources/IM/**/*.{swift}'
  end
end
