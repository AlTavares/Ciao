Pod::Spec.new do |s|
 s.name = 'Ciao'
 s.version = '1.0.0'
 s.license = { :type => "MIT", :file => "LICENSE" }
 s.summary = 'Lib to publish and find services using mDNS'
 s.authors = { "Alexandre Mantovani Tavares" => "alexandre@live.in" }
 s.source = { :git => "https://github.com/AlTavares/Ciao.git", :tag => "v"+s.version.to_s }
 s.platforms = { :ios => "8.0", :osx => "10.10", :tvos => "9.0", :watchos => "2.0" }
 s.requires_arc = true

 s.default_subspec = "Core"
 s.subspec "Core" do |ss|
     ss.source_files  = "Sources/**/*.swift"
     ss.framework  = "Foundation"
 end

end
