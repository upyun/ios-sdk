Pod::Spec.new do |s|
s.name = 'UPYUN'
s.version = '2.0.2'
s.license = { :type => 'MIT', :text => <<-LICENSE
                   Copyright (c) 2016年 UPYUN. All rights reserved.
                 LICENSE
               }
s.summary = 'UPYUN Upload SDK For iOS.'
s.homepage = 'https://github.com/upyun/ios-sdk'
s.authors = { 'UPYUN' => 'iOSTeam@upyun.com' }
s.source = { :git => 'https://github.com/upyun/ios-sdk.git', :tag => s.version.to_s }
s.requires_arc = true
s.ios.deployment_target = '7.0'

	s.subspec 'class' do |ss|
	ss.source_files = ['UpYunSDK/class/**/*.{h,m}']
	end

	s.subspec 'class_deprecated' do |ss|
	ss.source_files = ['UpYunSDK/class_deprecated/*.{h,m}', 'UpYunSDK/class_deprecated/**/*.{h,m}']
	end


end