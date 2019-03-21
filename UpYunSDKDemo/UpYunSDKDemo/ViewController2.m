//
//  ViewController2.m
//  upyundemo
//
//  Created by andy yao on 12-6-14.
//  Copyright (c) 2012年 upyun.com. All rights reserved.
//

#import "ViewController2.h"
#import "UpYunFormUploader.h" //图片，小文件，短视频
//串行分块上传，适合追求稳定
#import "UpYunBlockUpLoader.h"
//并行分块上传，适合追求速度
#import "UpYunConcurrentBlockUpLoader.h"

#import "UpYunFileDealManger.h" // 文件处理任务

#import "ViewController.h"


@interface ViewController2 ()
@property (strong, nonatomic) UIButton *uploadBtn;
@property (strong, nonatomic) UIButton *uploadBtn1;


@end

@implementation ViewController2
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.uploadBtn = [[UIButton alloc] initWithFrame:CGRectMake(100, 100, 200, 44)];
    self.uploadBtn.backgroundColor = [UIColor lightGrayColor];
    [self.uploadBtn setTitle:@"upload"
               forState:UIControlStateNormal];
    [self.uploadBtn addTarget:self
                  action:@selector(uploadBtntap:)
        forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:self.uploadBtn];
    
    
    self.uploadBtn1 = [[UIButton alloc] initWithFrame:CGRectMake(100, 300, 200, 44)];
    self.uploadBtn1.backgroundColor = [UIColor lightGrayColor];
    [self.uploadBtn1 setTitle:@"旧版本"
                    forState:UIControlStateNormal];
    [self.uploadBtn1 addTarget:self
                       action:@selector(uploadBtn1Tap:)
             forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:self.uploadBtn1];
}

- (void)uploadBtntap:(id)sender {



//    [self testFormUploader1];             //本地签名的表单上传
//    [self testFormUploader2];             //服务器端签名的表单上传（模拟）
//    [self testBlockUpLoader1];            //串行断点续传
//    [self testBlockUpLoader2];            //串行断点续传 后异步处理
    [self testBlockUpLoader3];              // 并行分块断点续传
//    [self testBlockUpLoader4];              // 并行分块断点续传 后异步处理

//    [self testFormUploaderAndAsyncTask];  //表单上传加异步多媒体处理－－视频截图
//    [self testFormUploaderAndSyncTask];   //表单上传加同步图片处理－－图片水印
//    [self testFileDeal];                  // 文件异步处理请求
    
}

- (void)testFileDeal {
    UpYunFileDealManger *up = [[UpYunFileDealManger alloc] init];
    
    
    NSMutableArray *tasks = [NSMutableArray array];
    
    NSDictionary *taksOne =@{@"type": @"thumbnail", @"avopts": @"/o/true/n/1/ss/00:00:05",
                             @"notify_url": @"http://124.160.114.202:18989/echo",
                                                       @"save_as": @"ios_sdk_new_video_1.jpg"};
    NSDictionary *taksTwo =@{@"type": @"thumbnail", @"avopts": @"/o/true/n/1/ss/00:00:11",
                             @"notify_url": @"http://124.160.114.202:18989/echo",
                             @"save_as": @"ios_sdk_new_video_2.jpg"};
    
    [tasks addObject:taksOne];
    
    [tasks addObject:taksTwo];
    
    [up dealTaskWithBucketName:@"test86400" operator:@"operator123" password:@"password123" notify_url:@"http://124.160.114.202:18989/echo" source:@"/123.mp4" tasks:tasks success:^(NSHTTPURLResponse *response, NSDictionary *responseBody) {
        
        NSLog(@"response--%@", response);
        NSLog(@"上传成功 responseBody：%@", responseBody);
        
    } failure:^(NSError *error, NSHTTPURLResponse *response, NSDictionary *responseBody) {
         NSLog(@"失败---");
        NSLog(@"上传失败 error：%@", error);
        NSLog(@"上传失败 code=%ld, responseHeader：%@", (long)response.statusCode, response.allHeaderFields);
        NSLog(@"上传失败 message：%@", responseBody);
    }];
}


//本地签名的表单上传。
- (void)testFormUploader1 {
    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *filePath = [resourcePath stringByAppendingPathComponent:@"video.mp4"];
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    UpYunFormUploader *up = [[UpYunFormUploader alloc] init];
    
    NSString *bucketName = @"test86400";
    [up uploadWithBucketName:bucketName
                    operator:@"operator123"
                    password:@"password123"
                    fileData:fileData
                    fileName:nil
                     saveKey:@"ios_sdk_new/video.mp4"
             otherParameters:nil
                     success:^(NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {
                         NSLog(@"上传成功 responseBody：%@", responseBody);
                         
                         NSLog(@"可将您的域名与返回的 url 路径拼接成完整文件 URL，再进行访问测试。注意生产环境请用正式域名，新开空间可用 test.upcdn.net 进行测试。https 访问需要空间开启 https 支持");
                         NSLog(@"用默认提供的旧测试域名，拼接后文件地址（新空间无法访问）：http://%@.b0.upaiyun.com/%@", bucketName, [responseBody objectForKey:@"url"]);
                         NSLog(@"用默认提供的新测试域名，拼接后文件地址（旧空间无法访问）：http://%@.test.upcdn.net/%@", bucketName, [responseBody objectForKey:@"url"]);

                         //主线程刷新ui
                     }
                     failure:^(NSError *error,
                               NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {
                         NSLog(@"上传失败 error：%@", error);
                         NSLog(@"上传失败 code=%ld, responseHeader：%@", (long)response.statusCode, response.allHeaderFields);
                         NSLog(@"上传失败 message：%@", responseBody);
                         //主线程刷新ui
                         dispatch_async(dispatch_get_main_queue(), ^(){
                             NSString *message = [responseBody objectForKey:@"message"];
                             if (!message) {
                                 message = [NSString stringWithFormat:@"%@", error.localizedDescription];
                             }
                             UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"上传失败!"
                                                                                            message:message
                                                                                     preferredStyle:UIAlertControllerStyleAlert];
                             UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                                                     style:UIAlertActionStyleDefault
                                                                                   handler:nil];
                             [alert addAction:defaultAction];
                             [self presentViewController:alert animated:YES completion:nil];
                         });
                     }
     
                    progress:^(int64_t completedBytesCount,
                               int64_t totalBytesCount) {
                        NSString *progress = [NSString stringWithFormat:@"%lld / %lld", completedBytesCount, totalBytesCount];
                        NSString *progress_rate = [NSString stringWithFormat:@"upload %.1f %%", 100 * (float)completedBytesCount / totalBytesCount];
                        NSLog(@"upload progress: %@", progress);
                       
                        //主线程刷新ui
                        dispatch_async(dispatch_get_main_queue(), ^(){
                            [self.uploadBtn setTitle:progress_rate forState:UIControlStateNormal];
                        });
                    }];

}

//服务器端签名的表单上传（模拟）
- (void)testFormUploader2 {
    //从 app 服务器获取的上传策略 policy
    NSString *policy = @"eyJleHBpcmF0aW9uIjoxNDg5Mzc4NjExLCJyZXR1cm4tdXJsIjoiaHR0cGJpbi5vcmdcL3Bvc3QiLCJidWNrZXQiOiJmb3JtdGVzdCIsInNhdmUta2V5IjoiXC91cGxvYWRzXC97eWVhcn17bW9ufXtkYXl9XC97cmFuZG9tMzJ9ey5zdWZmaXh9In0=";
    
    //从 app 服务器获取的上传策略签名 signature
    NSString *signature = @"BIC22iXgu5fBUXgoMGGpdWNpsak=";
    
    
    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *filePath = [resourcePath stringByAppendingPathComponent:@"picture.jpg"];
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    UpYunFormUploader *up = [[UpYunFormUploader alloc] init];
    
    NSString *operatorName = @"one";
    [up uploadWithOperator:operatorName
                    policy:policy
                 signature:signature
                  fileData:fileData
                  fileName:nil
                   success:^(NSHTTPURLResponse *response,
                             NSDictionary *responseBody) {
                       NSLog(@"上传成功 responseBody：%@", responseBody);
                       //主线程刷新ui
                   }
     
                   failure:^(NSError *error,
                             NSHTTPURLResponse *response,
                             NSDictionary *responseBody) {
                       NSLog(@"上传失败 error：%@", error);
                       NSLog(@"上传失败 code=%ld, responseHeader：%@", (long)response.statusCode, response.allHeaderFields);
                       NSLog(@"上传失败 message：%@", responseBody);
                       //主线程刷新ui
                   }
     
                  progress:^(int64_t completedBytesCount,
                             int64_t totalBytesCount) {
                      NSLog(@"upload progress: %lld / %lld", completedBytesCount, totalBytesCount);
                      //主线程刷新ui
                  }];
}

//分块上传

int countStart = 0;
int countEnd = 0;

- (void)testBlockUpLoader1{
    countStart ++;
    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *filePath = [resourcePath stringByAppendingPathComponent:@"video.mp4"];
    
    UpYunBlockUpLoader *up = [[UpYunBlockUpLoader alloc] init];
    NSString *bucketName = @"test86400";
    NSString *savePath = @"ios_upload_task_video.mp4";
    
    [up uploadWithBucketName:bucketName
                    operator:@"operator123"
                    password:@"password123"
                    filePath:filePath
                    savePath:savePath
                     success:^(NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {
                         
                         countEnd ++;

                         //主线程刷新ui
                         
                         NSLog(@"responseBody=%@", responseBody);
                         NSLog(@"%d - %d", countEnd, countStart);

                         NSLog(@"上传且处理任务成功");
                   
                         NSLog(@"可将您的域名与 savePath 路径拼接成完整文件 URL，再进行访问测试。注意生产环境请用正式域名，新开空间可用 test.upcdn.net 进行测试。https 访问需要空间开启 https 支持");
                         NSLog(@"用默认提供的旧测试域名，拼接后文件地址（新空间无法访问）：http://%@.b0.upaiyun.com/%@", bucketName, savePath);
                         NSLog(@"用默认提供的新测试域名，拼接后文件地址（旧空间无法访问）：http://%@.test.upcdn.net/%@", bucketName, savePath);
                     }
     
     
                     failure:^(NSError *error,
                               NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {
                         countEnd ++;

                         NSLog(@"上传失败 error：%@", error);
                         NSLog(@"上传失败 code=%ld, responseHeader：%@", (long)response.statusCode, response.allHeaderFields);
                         NSLog(@"上传失败 message：%@", responseBody);
                         //主线程刷新ui
                         NSLog(@"%d - %d", countEnd, countStart);


                     }
                    progress:^(int64_t completedBytesCount,
                               int64_t totalBytesCount) {
                        NSString *progress = [NSString stringWithFormat:@"%lld / %lld", completedBytesCount, totalBytesCount];
                        NSString *progress_rate = [NSString stringWithFormat:@"upload %.1f %%", 100 * (float)completedBytesCount / totalBytesCount];
                        NSLog(@"upload progress: %@", progress);
                        
                        //主线程刷新ui
                        dispatch_async(dispatch_get_main_queue(), ^(){
                            [self.uploadBtn setTitle:progress_rate forState:UIControlStateNormal];
                        });
                    }];
}

/// 上传之后进行文件处理操作
- (void)testBlockUpLoader2{
    countStart ++;
    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *filePath = [resourcePath stringByAppendingPathComponent:@"video.mp4"];
    
    
    NSMutableArray *tasks = [NSMutableArray array];
    /// task 的相关参数, 见
    NSDictionary *taksOne =@{@"type": @"thumbnail", @"avopts": @"/o/true/n/1/ss/00:00:02",
                             @"save_as": @"ios_sdk_new_video_3.jpg"};
    NSDictionary *taksTwo =@{@"type": @"thumbnail", @"avopts": @"/o/true/n/1/ss/00:00:03",
                             @"save_as": @"ios_sdk_new_video_4.jpg"};
    
    [tasks addObject:taksOne];
    
    [tasks addObject:taksTwo];
    
    NSString *notif_url = @"http://124.160.114.202:18989/echo";
    
    
    UpYunBlockUpLoader *up = [[UpYunBlockUpLoader alloc] init];
    NSString *bucketName = @"test86400";
    NSString *savePath = @"ios_upload_task_video.mp4";
    
    [up uploadWithBucketName:bucketName
                    operator:@"operator123"
                    password:@"password123"
                    filePath:filePath
                    savePath:savePath
                  notify_url:notif_url
                       tasks:tasks
                     success:^(NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {
                         
                         countEnd ++;
                         NSLog(@"上传且处理任务成功");
                         NSLog(@"可将您的域名与 savePath 路径拼接成完整文件 URL，再进行访问测试。注意生产环境请用正式域名，新开空间可用 test.upcdn.net 进行测试。https 访问需要空间开启 https 支持");
                         NSLog(@"用默认提供的旧测试域名，拼接后文件地址（新空间无法访问）：http://%@.b0.upaiyun.com/%@", bucketName, savePath);
                         NSLog(@"用默认提供的新测试域名，拼接后文件地址（旧空间无法访问）：http://%@.test.upcdn.net/%@", bucketName, savePath);
                         
                         
                         //主线程刷新ui
                         
                         NSLog(@"responseBody=%@", responseBody);
                         NSLog(@"%d - %d", countEnd, countStart);
                         
                     }
                     failure:^(NSError *error,
                               NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {
                         countEnd ++;
                         
                         NSLog(@"上传失败 error：%@", error);
                         NSLog(@"上传失败 code=%ld, responseHeader：%@", (long)response.statusCode, response.allHeaderFields);
                         NSLog(@"上传失败 message：%@", responseBody);
                         //主线程刷新ui
                         NSLog(@"%d - %d", countEnd, countStart);
                         
                         
                     }
                    progress:^(int64_t completedBytesCount,
                               int64_t totalBytesCount) {
                        NSString *progress = [NSString stringWithFormat:@"%lld / %lld", completedBytesCount, totalBytesCount];
                        NSString *progress_rate = [NSString stringWithFormat:@"upload %.1f %%", 100 * (float)completedBytesCount / totalBytesCount];
                        NSLog(@"upload progress: %@", progress);
                        
                        //主线程刷新ui
                        dispatch_async(dispatch_get_main_queue(), ^(){
                            [self.uploadBtn setTitle:progress_rate forState:UIControlStateNormal];
                        });
                    }];
}

/// 并发断点续传
- (void)testBlockUpLoader3 {

    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *filePath = [resourcePath stringByAppendingPathComponent:@"video.mp4"];

    UpYunConcurrentBlockUpLoader *up = [[UpYunConcurrentBlockUpLoader alloc] init];
    NSString *bucketName = @"test86400";
    /// 用来测试过期时间--
    NSString *savePath = @"ios_upload_time_task_video.mp4";
//    NSString *savePath = @"ios_upload_block_9_task_video.mp4";

    [up uploadWithBucketName:bucketName
                    operator:@"operator123"
                    password:@"password123"
                    filePath:filePath
                    savePath:savePath
                     success:^(NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {
                         NSLog(@"responseBody=%@", responseBody);

                         NSLog(@"上传且处理任务成功");

                         NSLog(@"可将您的域名与 savePath 路径拼接成完整文件 URL，再进行访问测试。注意生产环境请用正式域名，新开空间可用 test.upcdn.net 进行测试。https 访问需要空间开启 https 支持");
                         NSLog(@"用默认提供的旧测试域名，拼接后文件地址（新空间无法访问）：http://%@.b0.upaiyun.com/%@", bucketName, savePath);
                         NSLog(@"用默认提供的新测试域名，拼接后文件地址（旧空间无法访问）：http://%@.test.upcdn.net/%@", bucketName, savePath);
                     }


                     failure:^(NSError *error,
                               NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {

                         NSLog(@"上传失败 error：%@", error);
                         NSLog(@"上传失败 code=%ld, responseHeader：%@", (long)response.statusCode, response.allHeaderFields);
                         NSLog(@"上传失败 message：%@", responseBody);
                         //主线程刷新ui
                     }
                    progress:^(int64_t completedBytesCount,
                               int64_t totalBytesCount) {
                        NSString *progress = [NSString stringWithFormat:@"%lld / %lld", completedBytesCount, totalBytesCount];
                        NSString *progress_rate = [NSString stringWithFormat:@"upload %.1f %%", 100 * (float)completedBytesCount / totalBytesCount];
                        NSLog(@"upload progress: %@", progress);

//                        //主线程刷新ui
                        dispatch_async(dispatch_get_main_queue(), ^(){
                            [self.uploadBtn setTitle:progress_rate forState:UIControlStateNormal];
                        });
                    }];
}

/// 并发断点续传 后处理文件
- (void)testBlockUpLoader4 {

    NSMutableArray *tasks = [NSMutableArray array];
    /// task 的相关参数, 见
    NSDictionary *taksOne =@{@"type": @"thumbnail", @"avopts": @"/o/true/n/1/ss/00:00:02",
                             @"save_as": @"ios_sdk_new_video_3.jpg"};
    NSDictionary *taksTwo =@{@"type": @"thumbnail", @"avopts": @"/o/true/n/1/ss/00:00:03",
                             @"save_as": @"ios_sdk_new_video_4.jpg"};

    [tasks addObject:taksOne];

    [tasks addObject:taksTwo];

    NSString *notif_url = @"http://124.160.114.202:18989/echo";

    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *filePath = [resourcePath stringByAppendingPathComponent:@"video.mp4"];

    UpYunConcurrentBlockUpLoader *up = [[UpYunConcurrentBlockUpLoader alloc] init];
    NSString *bucketName = @"test86400";
    /// 用来测试过期时间--
    /// NSString *savePath = @"ios_upload_time_task_video.mp4";
    NSString *savePath = @"ios_upload_block_8_task_video.mp4";

    [up uploadWithBucketName:bucketName
                    operator:@"operator123"
                    password:@"password123"
                    filePath:filePath
                    savePath:savePath
                  notify_url:notif_url
                       tasks:tasks
                     success:^(NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {
                         NSLog(@"responseBody=%@", responseBody);

                         NSLog(@"上传且处理任务成功");

                         NSLog(@"可将您的域名与 savePath 路径拼接成完整文件 URL，再进行访问测试。注意生产环境请用正式域名，新开空间可用 test.upcdn.net 进行测试。https 访问需要空间开启 https 支持");
                         NSLog(@"用默认提供的旧测试域名，拼接后文件地址（新空间无法访问）：http://%@.b0.upaiyun.com/%@", bucketName, savePath);
                         NSLog(@"用默认提供的新测试域名，拼接后文件地址（旧空间无法访问）：http://%@.test.upcdn.net/%@", bucketName, savePath);
                     }


                     failure:^(NSError *error,
                               NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {

                         NSLog(@"上传失败 error：%@", error);
                         NSLog(@"上传失败 code=%ld, responseHeader：%@", (long)response.statusCode, response.allHeaderFields);
                         NSLog(@"上传失败 message：%@", responseBody);
                         //主线程刷新ui
                     }
                    progress:^(int64_t completedBytesCount,
                               int64_t totalBytesCount) {
                        NSString *progress = [NSString stringWithFormat:@"%lld / %lld", completedBytesCount, totalBytesCount];
                        NSString *progress_rate = [NSString stringWithFormat:@"upload %.1f %%", 100 * (float)completedBytesCount / totalBytesCount];
                        NSLog(@"upload progress: %@", progress);

                        //                        //主线程刷新ui
                        dispatch_async(dispatch_get_main_queue(), ^(){
                            [self.uploadBtn setTitle:progress_rate forState:UIControlStateNormal];
                        });
                    }];
}

//表单上传加异步视频处理－－视频截图
- (void)testFormUploaderAndAsyncTask {
    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *filePath = [resourcePath stringByAppendingPathComponent:@"video.mp4"];
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    UpYunFormUploader *up = [[UpYunFormUploader alloc] init];
    
    //异步视频截图处理。更详细参数参考：云处理文档－音视频处理－视频截图 http://docs.upyun.com/cloud/av/#_16
    NSDictionary *asycTask = @{@"name": @"naga",@"type": @"thumbnail",
                               @"save_as": @"ios_sdk_new/test2/video.jpg",
                               @"avopts": @"/o/true/n/1/",
                               @"notify_url": @"http://124.160.114.202:18989/echo"};
    NSArray *apps = @[asycTask];
    
    NSString *bucketName = @"test86400";
    [up uploadWithBucketName:bucketName
                    operator:@"operator123"
                    password:@"password123"
                    fileData:fileData
                    fileName:nil
                     saveKey:@"ios_sdk_new/test2/video.mp4"
             otherParameters:@{@"apps": apps}
                     success:^(NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {
                         NSLog(@"上传成功 responseBody：%@", responseBody);
                         //主线程刷新ui
                     }
                     failure:^(NSError *error,
                               NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {
                         NSLog(@"上传失败 error：%@", error);
                         NSLog(@"上传失败 responseBody：%@", responseBody);
                         NSLog(@"上传失败 message：%@", [responseBody objectForKey:@"message"]);
                         //主线程刷新ui
                         dispatch_async(dispatch_get_main_queue(), ^(){
                             NSString *message = [responseBody objectForKey:@"message"];
                             if (!message) {
                                 message = [NSString stringWithFormat:@"%@", error.localizedDescription];
                             }
                             UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"上传失败!"
                                                                                            message:message
                                                                                     preferredStyle:UIAlertControllerStyleAlert];
                             UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                                                     style:UIAlertActionStyleDefault
                                                                                   handler:nil];
                             [alert addAction:defaultAction];
                             [self presentViewController:alert animated:YES completion:nil];
                         });
                     }
     
                    progress:^(int64_t completedBytesCount,
                               int64_t totalBytesCount) {
                        NSString *progress = [NSString stringWithFormat:@"%lld / %lld", completedBytesCount, totalBytesCount];
                        NSString *progress_rate = [NSString stringWithFormat:@"upload %.1f %%", 100 * (float)completedBytesCount / totalBytesCount];
                        NSLog(@"upload progress: %@", progress);
                        
                        //主线程刷新ui
                        dispatch_async(dispatch_get_main_queue(), ^(){
                            [self.uploadBtn setTitle:progress_rate forState:UIControlStateNormal];
                        });
                    }];
}

//表单上传加同步图片处理－－图片水印
- (void)testFormUploaderAndSyncTask {
    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *filePath = [resourcePath stringByAppendingPathComponent:@"picture.jpg"];
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    UpYunFormUploader *up = [[UpYunFormUploader alloc] init];
    
    NSString *bucketName = @"test86400";
    
    //同步图片水印处理。更详细参数参考：云处理文档－图片处理－上传预处理 http://docs.upyun.com/cloud/image/#function

    NSString *watermark = @"这是水印";
    //需要转换为 base64 编码
    NSData *encodeData = [watermark dataUsingEncoding:NSUTF8StringEncoding];
    NSString *watermark_base64 = [encodeData base64EncodedStringWithOptions:0];
    
    [up uploadWithBucketName:bucketName
                    operator:@"operator123"
                    password:@"password123"
                    fileData:fileData
                    fileName:nil
                     saveKey:@"ios_sdk_new/test2/picture.jpg"
             otherParameters:@{@"x-gmkerl-thumb": [NSString stringWithFormat:@"/watermark/text/%@/color/FFFFFF/align/south", watermark_base64]}
                     success:^(NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {
                         NSLog(@"上传成功 responseBody：%@", responseBody);
                         //主线程刷新ui
                     }
                     failure:^(NSError *error,
                               NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {
                         NSLog(@"上传失败 error：%@", error);
                         NSLog(@"上传失败 responseBody：%@", responseBody);
                         NSLog(@"上传失败 message：%@", [responseBody objectForKey:@"message"]);
                         //主线程刷新ui
                         dispatch_async(dispatch_get_main_queue(), ^(){
                             NSString *message = [responseBody objectForKey:@"message"];
                             if (!message) {
                                 message = [NSString stringWithFormat:@"%@", error.localizedDescription];
                             }
                             UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"上传失败!"
                                                                                            message:message
                                                                                     preferredStyle:UIAlertControllerStyleAlert];
                             UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                                                     style:UIAlertActionStyleDefault
                                                                                   handler:nil];
                             [alert addAction:defaultAction];
                             [self presentViewController:alert animated:YES completion:nil];
                         });
                     }
     
                    progress:^(int64_t completedBytesCount,
                               int64_t totalBytesCount) {
                        NSString *progress = [NSString stringWithFormat:@"%lld / %lld", completedBytesCount, totalBytesCount];
                        NSString *progress_rate = [NSString stringWithFormat:@"upload %.1f %%", 100 * (float)completedBytesCount / totalBytesCount];
                        NSLog(@"upload progress: %@", progress);
                        
                        //主线程刷新ui
                        dispatch_async(dispatch_get_main_queue(), ^(){
                            [self.uploadBtn setTitle:progress_rate forState:UIControlStateNormal];
                        });
                    }];
}

//旧版本 sdk demo
- (void)uploadBtn1Tap:(id)sender {
    ViewController *vc = [[ViewController alloc] initWithNibName:@"ViewController_iPhone" bundle:nil];
    [self presentViewController:vc animated:YES completion:nil];
}


@end
