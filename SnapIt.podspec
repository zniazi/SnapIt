#
# Be sure to run `pod lib lint SnapIt.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "SnapIt"
  s.version          = "0.1.2"
  s.summary          = "A Core Data Lite alternative built using Ruby like syntax."
  s.description      = <<-DESC
                       * A Core Data Lite alternative for persistent storage of your objects. Use intuitive commands like "where" and "save" to fetch models or persist data. The syntax is based off of Active Record from Ruby on Rails.
                       DESC
  s.homepage         = "https://github.com/zniazi/SnapIt"
  # s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = 'MIT'
  s.author           = { "Zak Niazi" => "zniazi1029@gmail.com" }
  s.source           = { :git => "https://github.com/zniazi/SnapIt.git", :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/zakniazi2'

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/*.{h,m}'
  s.resource_bundles = {
    'SnapIt' => ['Pod/Assets/*.png']
  }

  s.frameworks = 'libsqlite3'

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
