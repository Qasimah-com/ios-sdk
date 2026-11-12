Pod::Spec.new do |s|
  s.name             = 'QasimhaCheckout'
  s.version          = '0.1.0'
  s.summary          = 'Present the Qasimha hosted checkout from an iOS app and receive the outcome.'
  s.description      = <<-DESC
    QasimhaCheckout opens the payment URL that your server created with a Qasimha server SDK,
    detects the return to your app and reports success, failure or cancellation. It holds no
    secret, stores nothing on the device and has no third-party dependencies. An optional promo
    view shows the instalment plan for an amount.
  DESC
  s.homepage         = 'https://api.qasimha.com'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Qasimha'
  s.source           = { :git => 'git@github.com:qasimha/ios-sdk.git', :tag => "v#{s.version}" }
  s.platform         = :ios, '14.0'
  s.swift_versions   = ['5.9']
  s.source_files     = 'Sources/QasimhaCheckout/**/*.swift'
  s.resource_bundles = { 'QasimhaCheckout' => ['Sources/QasimhaCheckout/PrivacyInfo.xcprivacy'] }
  s.frameworks       = 'UIKit', 'SafariServices', 'AuthenticationServices', 'WebKit'
end
