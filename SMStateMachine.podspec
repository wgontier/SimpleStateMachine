Pod::Spec.new do |s|
  s.name         = "SMStateMachine"
  s.version      = "1.1.1"
  s.summary      = "Very simple state machine written in Objective-C." 
  s.homepage     = "https://github.com/est1908/SimpleStateMachine"
  s.license      = 'MIT'
  s.author       = { "Artem Kireev" => "est1908@gmail.com" }
  s.source       = { :git => 'https://github.com/est1908/SimpleStateMachine.git', :tag => '1.1.1' }
  s.platform     = :ios, '8.0'
  s.requires_arc = true
  s.source_files = 'SMStateMachine'  
end
