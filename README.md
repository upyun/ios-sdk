# UPYUN iOS SDK
[![Build Status](https://travis-ci.org/upyun/ios-sdk.svg?branch=master)](https://travis-ci.org/upyun/ios-sdk)
![Platform](http://img.shields.io/cocoapods/p/UPYUN.svg)
[![Software License](https://img.shields.io/badge/license-MIT-brightgreen.svg)](License.md)


UPYUN iOS SDK 集成了表单上传``` UpYunFormUploader ```  和分块上传  ``` UpYunBlockUpLoader```   两部分，分别实现了以下文档接口：    
- [又拍云存储 FORM API 表单上传接口](http://docs.upyun.com/api/form_api/)        
- [又拍云存储 REST API 断点续传接口](http://docs.upyun.com/api/rest_api/#_3)



```表单上传```  适用于上传图片、短视频等小文件， ```分块上传```  适用于大文件上传和断点续传。（特别地，断点续传上传的图片不支持预处理）


## 运行环境
iOS 7.0 及以上版本, ARC 模式, 基于系统网络库 NSURLSession 发送 HTTP 请求。
 
## 安装使用说明：
 下载 SDK，然后将 `UpYunSDK` 文件夹拖到工程中。（最新版本 2.0.0 暂时无法用 CocoaPods 安装。）
 
 

 UpYunSDK 文件目录： 

 
 ```			
 
├── class  
│   ├── UpLoader
│   │   ├── UpYunBlockUpLoader.h    //分块上传接口
│   │   ├── UpYunBlockUpLoader.m
│   │   ├── UpYunFormUploader.h     //表单上传接口
│   │   ├── UpYunFormUploader.m
│   │   └── UpYunUploader.h
│   └── Utils
│
│  
└── class_deprecated // 旧版本 SDK


 
 ```			
 
 
 使用时候，请引入相应的头文件  	 
 
 ```  				
 
 //表单上传，适用于上传图片、短视频等小文件。   
 #import "UpYunFormUploader.h" 
 
 //分块上传，适合大文件上传。
 #import "UpYunBlockUpLoader.h"
 
 
 ```			
 


## 接口与参数说明： 


###表单上传

表单上传接口共有两个，分别适用于__本地签名__和__服务器签名__两种上传方式。
使用时候，请引入相应的头文件 ```#import "UpYunFormUploader.h"```。 具体使用方式参考 demo 页面文件 "ViewController2.m".



```					


/*表单上传接口
 参数  bucketName:           上传空间名
 参数  operator:             空间操作员
 参数  password:             空间操作员秘密
 参数  formAPIKey:           表单密钥
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



###分块上传

分块上传接口只有一个，需要__本地签名__进行上传。
使用时候，请引入相应的头文件 ```#import "UpYunBlockUpLoader.h"```。 具体使用方式参考 demo 页面文件 "ViewController2.m".


```  				

/*表单上传接口
 参数  bucketName:           上传空间名
 参数  operator:             空间操作员
 参数  operatorPassword:     空间操作员秘密
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

``` 				

 
 
    
 
 
 



