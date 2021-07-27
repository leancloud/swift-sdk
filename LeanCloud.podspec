Pod::Spec.new do |s|
  s.name         = 'LeanCloud'
  s.version      = '17.9.1'
  s.license      = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
  s.summary      = 'LeanCloud Swift SDK'
  s.homepage     = 'https://leancloud.cn/'
  s.authors      = 'LeanCloud'
  s.source       = { :git => 'https://github.com/leancloud/swift-sdk.git', :tag => s.version }
  
  s.swift_version = '5.0'
  s.default_subspec  = 'RTM'

  s.ios.deployment_target     = '10.0'
  s.osx.deployment_target     = '10.12'
  s.tvos.deployment_target    = '10.0'
  s.watchos.deployment_target = '3.0'

  s.subspec 'Foundation' do |ss|
    ss.dependency 'Alamofire', '~> 5.4'

    ss.source_files = 'Sources/Foundation/**/*.{swift}'
  end

  s.subspec 'RTM' do |ss|
    ss.dependency 'SwiftProtobuf', '~> 1.17'
    ss.dependency 'GRDB.swift', '~> 5.8'

    ss.dependency 'LeanCloud/Foundation', "#{s.version}"

    ss.source_files = 'Sources/RTM/**/*.{swift}'
  end
  
  s.subspec 'RTM-no-local-storage' do |ss|
    ss.dependency 'SwiftProtobuf', '~> 1.17'

    ss.dependency 'LeanCloud/Foundation', "#{s.version}"

    ss.source_files = 'Sources/RTM/**/*.{swift}'
  end
end
