//
//  ViewController2.m
//  upyundemo
//
//  Created by andy yao on 12-6-14.
//  Copyright (c) 2012年 upyun.com. All rights reserved.
//

#import "ViewController2.h"
#import "UpYun.h"
#import "UPLivePhotoViewController.h"
#import "UpYunFormUploader.h"



@interface ViewController2 ()
@property (weak, nonatomic) IBOutlet UIImageView *image;
@property (weak, nonatomic) IBOutlet UIProgressView *pv;
@end

@implementation ViewController2
- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    UIButton *uploadBtn = [[UIButton alloc] initWithFrame:CGRectMake(100, 100, 100, 44)];
    uploadBtn.backgroundColor = [UIColor lightGrayColor];
    [uploadBtn setTitle:@"upload"
               forState:UIControlStateNormal];
    [uploadBtn addTarget:self
                  action:@selector(uploadBtntap:)
        forControlEvents:UIControlEventTouchUpInside];
    
    
    
    [self.view addSubview:uploadBtn];
}

- (void)uploadBtntap:(id)sender {
    [self testUpload1];
}

//本地签名
- (void)testUpload1 {
    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *filePath = [resourcePath stringByAppendingPathComponent:@"picture.jpg"];
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    UpYunFormUploader *up = [[UpYunFormUploader alloc] init];
    [up uploadWithBucketName:@"test86400"
                    operator:@"test86400"
                    password:@"test86400"
                    fileData:fileData
                    fileName:nil
                     saveKey:@"ios_sdk_new/111picture.jpg"
             otherParameters:nil
                     success:^(NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {
                         NSLog(@"上传成功 responseBody：%@", responseBody);
                         NSLog(@"file url：https://test86400.b0.upaiyun.com/%@", [responseBody objectForKey:@"url"]);
                     }
     
                     failure:^(NSError *error,
                               NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {
                         NSLog(@"上传失败 error：%@", error);
                         NSLog(@"上传失败 responseBody：%@", responseBody);
                         NSLog(@"上传失败 message：%@", [responseBody objectForKey:@"message"]);
                     }
     
                    progress:^(int64_t completedBytesCount,
                               int64_t totalBytesCount) {
                        NSLog(@"upload progress: %lld / %lld", completedBytesCount, totalBytesCount);
                    }];

}


//服务器端签名
- (void)testUpload2 {
    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *filePath = [resourcePath stringByAppendingPathComponent:@"picture.jpg"];
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    UpYunFormUploader *up = [[UpYunFormUploader alloc] init];
    
    
    //从 app 服务器获取的上传策略 policy
    NSString *policy = @"ewogICJjb250ZW50LW1kNSIgOiAiNDRiN2E4ZjMyN2Q3OTk1NjIzY2Q5MmJhZDYzYTc2MmMiLAogICJzYXZlLWtleSIgOiAiaW9zX3Nka19uZXdcLzExMXBpY3R1cmUuanBnIiwKICAiYnVja2V0IiA6ICJ0ZXN0ODY0MDAiLAogICJleHBpcmF0aW9uIiA6ICIxNDg3MDY3NjUyIiwKICAiZGF0ZSIgOiAiVHVlLCAxNCBGZWIgMjAxNyAwOTo1MDo1MSBHTVQiCn0=";
    
    //从 app 服务器获取的上传策略签名 signature
    NSString *signature = @"nbkIJVuqQvOckxFzdY5GkQ6dk5A=";
    
    [up uploadWithOperator:@"test86400"
                    policy:policy
                 signature:signature
                  fileData:fileData
                  fileName:nil
                   success:^(NSHTTPURLResponse *response,
                             NSDictionary *responseBody) {
                       NSLog(@"上传成功 responseBody：%@", responseBody);
                       NSLog(@"file url：https://test86400.b0.upaiyun.com/%@", [responseBody objectForKey:@"url"]);
                       
                   }
                   failure:^(NSError *error,
                             NSHTTPURLResponse *response,
                             NSDictionary *responseBody) {
                       NSLog(@"上传失败 error：%@", error);
                       NSLog(@"上传失败 responseBody：%@", responseBody);
                       NSLog(@"上传失败 message：%@", [responseBody objectForKey:@"message"]);
                       
                   }
                  progress:^(int64_t completedBytesCount,
                             int64_t totalBytesCount) {
                      NSLog(@"upload progress: %lld / %lld", completedBytesCount, totalBytesCount);
                      
                  }];
    
}



@end
