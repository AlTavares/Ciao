Pod::Spec.new do |s|
 s.name = 'Ciao'
 s.version = '3.0.0'
 s.license = { :type => "MIT", :file => "LICENSE" }
 s.summary = 'Lib to publish and find services using mDNS'
 s.authors = { "Alexandre Mantovani Tavares" => "alexandre@live.in" }
 s.source = { :git => "https://github.com/AlTavares/Ciao.git", :tag => s.version.to_s }
 s.homepage = "https://github.com/AlTavares/Ciao"
 s.platforms = { :ios => "13.0", :osx => "10.15", :tvos => "13.0" }
 s.requires_arc = true
 s.swift_version = '5.10'

 s.default_subspec = "Core"
 s.subspec "Core" do |ss|
     ss.source_files  = "Sources/**/*.swift"
     ss.framework  = "Foundation"
 end

end
