# UPYUN iOS SDK
[![Build Status](https://travis-ci.org/upyun/ios-sdk.svg?branch=master)](https://travis-ci.org/upyun/ios-sdk)
![Platform](http://img.shields.io/cocoapods/p/UPYUN.svg)
[![Software License](https://img.shields.io/badge/license-MIT-brightgreen.svg)](License.md)



## 1 SDK 功能简介

UPYUN iOS SDK 集成了表单上传``` UpYunFormUploader ```  和断点续传  ``` UpYunBlockUpLoader```   两部分，分别实现了以下文档接口：    
- [又拍云存储 FORM API 表单上传接口](http://docs.upyun.com/api/form_api/)        
- [又拍云存储 REST API 断点续传接口](http://docs.upyun.com/api/rest_api/#_3)



```表单上传```  适用于上传图片、短视频等小文件。（另外通过 otherParameters 可实现方便的```图片视频预处理```功能）			
```断点续传```  适用于大文件上传和断点续传。（特别地，断点续传上传的图片不支持预处理）


## 2 运行环境
iOS 8.0 及以上版本, ARC 模式, 基于系统网络库 NSURLSession 发送 HTTP 请求。
 
## 3 安装使用说明：
 下载 SDK，然后将 `UpYunSDK` 文件夹拖到工程中。（最新版本 2.0.0 暂时无法用 CocoaPods 安装。）
 
 

 UpYunSDK 文件目录： 

 
 ```			
/UpYunSDK 
├── class  
│   ├── UpLoader
│   │   ├── UpYunBlockUpLoader.h    //断点续传接口
│   │   ├── UpYunBlockUpLoader.m
│   │   ├── UpYunFormUploader.h     //表单上传接口
│   │   ├── UpYunFormUploader.m
│   │   └── UpYunUploader.h
│   └── Utils
│
│  
└── class_deprecated // 旧版本 SDK


 
 ```			
 
 
 使用时候，请引入相应的头文件。  	 
 
 ```  				
 
 //表单上传，适用于上传图片、短视频等小文件。   
 #import "UpYunFormUploader.h" 
 
 //断点续传，适合大文件上传。
 #import "UpYunBlockUpLoader.h"
 
 
 ```			
 


## 4 接口与参数说明： 


### 4.1表单上传

表单上传接口共有两个，分别适用于__本地签名__和__服务器签名__两种上传方式。
使用时请引入头文件 ```#import "UpYunFormUploader.h"```。 具体使用方式请参考 demo 页面文件 "ViewController2.m".



```					


/*表单上传接口
 参数  bucketName:           上传空间名
 参数  operator:             空间操作员
 参数  password:             空间操作员密码
 参数  fileData:             上传文件数据
 参数  fileName:             上传文件名
 参数  saveKey:              上传文件的保存路径, 例如：“/2015/0901/file1.jpg”。可用占位符，参考：http://docs.upyun.com/api/form_api/#save-key
 参数  otherParameters:      可选的其它参数可以为nil. 参考文档：表单-API-参数http://docs.upyun.com/api/form_api/#_2
 参数  successBlock:         上传成功回调
 参数  failureBlock:         上传失败回调
 参数  progressBlock:        上传进度回调
 */

- (void)uploadWithBucketName:(NSString *)bucketName
                    operator:(NSString *)operatorName
                    password:(NSString *)operatorPassword
                    fileData:(NSData *)fileData
                    fileName:(NSString *)fileName
                     saveKey:(NSString *)saveKey
             otherParameters:(NSDictionary *)otherParameters
                     success:(UpLoaderSuccessBlock)successBlock
                     failure:(UpLoaderFailureBlock)failureBlock
                    progress:(UpLoaderProgressBlock)progressBlock;


/*表单上传接口，上传策略和签名可以是从服务器获取
 参数  operator:        空间操作员
 参数  policy:          上传策略
 参数  signature:       上传策略签名
 参数  fileData:        上传的数据
 参数  fileName:        上传文件名
 参数  success:         上传成功回调
 参数  failure:         上传失败回调
 参数  progress:        上传进度回调
 */
- (void)uploadWithOperator:(NSString *)operatorName
                    policy:(NSString *)policy
                 signature:(NSString *)signature
                  fileData:(NSData *)fileData
                  fileName:(NSString *)fileName
                   success:(UpLoaderSuccessBlock)successBlock
                   failure:(UpLoaderFailureBlock)failureBlock
                  progress:(UpLoaderProgressBlock)progressBlock;

//取消上传
- (void)cancel;

```					

注意：表单上传接口接口中 otherParameters 提供更丰富的上传参数定义，比如图片和音视频预处理参数 ```apps``` ,具体请参考文档[表单-API-参数](http://docs.upyun.com/api/form_api/#_2)


### 4.2断点续传

断点续传接口只有一个，需要__本地签名__进行上传。
使用时请引入相应的头文件 ```#import "UpYunBlockUpLoader.h"```。 具体使用方式请参考 demo 页面文件 "ViewController2.m".


```  				

/*断点续传接口
 参数  bucketName:           上传空间名
 参数  operator:             空间操作员
 参数  operatorPassword:     空间操作员密码
 参数  filePath:             上传文件本地路径
 参数  savePath:             上传文件的保存路径, 例如：“/2015/0901/file1.jpg”
 参数  successBlock:         上传成功回调
 参数  failureBlock:         上传失败回调
 参数  progressBlock:        上传进度回调
 */

- (void)uploadWithBucketName:(NSString *)bucketName
                    operator:(NSString *)operatorName
                    password:(NSString *)operatorPassword
                    filePath:(NSString *)filePath
                    savePath:(NSString *)savePath
                     success:(UpLoaderSuccessBlock)successBlock
                     failure:(UpLoaderFailureBlock)failureBlock
                    progress:(UpLoaderProgressBlock)progressBlock;
//取消上传
- (void)cancel;


/*删除本地缓存
 使用场景1: 失败的上传任务将记录在本地以实现续传，为避免将错误状态持久化在本地，而产生无法恢复的上传，可调用此方法恢复。
 使用场景2: 可在开发过程中使用此方法进行调试。
 使用场景3: 推荐将此方法放到 app 的“清除缓存”的功能功能中。
 使用场景4: 当上传出现失败，可以提供多个选项供用户操作，比如：接着续传或者重新上传，如果需要重新上传就需要调用此方法。
*/
+ (void)clearCache;

``` 				

 
## 5 DEMO工程与使用示例： 

下载运行 demo 工程即可以直接进行上传文件的测试。主要功能代码在 ```ViewController2.m``` 文件中。

```  

- (void)uploadBtntap:(id)sender {
    
  [self testFormUploader1];  //本地签名的表单上传
  [self testFormUploader2];  //服务器端签名的表单上传（模拟）
  [self testBlockUpLoader1]; //断点续传
  [self testFormUploaderAndAsyncTask]; //表单上传加异步多媒体处理－－视频截图

}

```  





 
    
    
 
 
 



