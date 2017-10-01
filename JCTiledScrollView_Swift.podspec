Pod::Spec.new do |s|
  s.name             = "JCTiledScrollView_Swift"
  s.version          = "0.0.3"
  s.summary          = "Using UIScrollView CATiledLayer to display large images and PDFs at multiple zoom scales"
  s.description      = "Jesse Collis's JCTiledScrollView rewritten in Swift 2 by Yichi Zhang, updated by me to Swift 4. A set of classes that wrap UIScrollView and CATiledLayer. It aims to simplify displaying large images and PDFs at multiple zoom scales."
  s.homepage         = "https://github.com/edmonston/JCTiledScrollView_Swift"
  s.license          = 'MIT'
  s.author           = { "Peter Edmonston" => "pedmonston@gmail.com" }
  s.source           = { :git => "https://github.com/edmonston/JCTiledScrollView_Swift.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/heypete'
  s.requires_arc = true
  s.source_files = 'JCTiledScrollView_Swift_Source/**/*'
  s.ios.deployment_target = '9.0'
  s.pod_target_xcconfig = { 'SWIFT_VERSION' => '4.0' }
end
