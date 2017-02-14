//
//  ViewController.m
//  upyundemo
//
//  Created by andy yao on 12-6-14.
//  Copyright (c) 2012年 upyun.com. All rights reserved.
//

#import "ViewController.h"
#import "UpYun.h"
#import "UPLivePhotoViewController.h"
#import "UpYunFormUploader.h"



@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *image;
@property (weak, nonatomic) IBOutlet UIProgressView *pv;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

- (IBAction)uploadFile:(id)sender {
    
    //设置空间名
    [UPYUNConfig sharedInstance].DEFAULT_BUCKET = @"test654123";
    //设置空间表单密钥
    [UPYUNConfig sharedInstance].DEFAULT_PASSCODE = @"0/8/1gPFWUQWGcfjFn6Vsn3VWDc=";
    
    
    __block UpYun *uy = [[UpYun alloc] init];
    uy.successBlocker = ^(NSURLResponse *response, id responseData) {
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"" message:@"上传成功" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alert show];
        NSLog(@"response body %@", responseData);
    };
    uy.failBlocker = ^(NSError * error) {
        NSString *message = error.description;
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"message" message:message delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alert show];
        NSLog(@"error %@", error);
    };
    uy.progressBlocker = ^(CGFloat percent, int64_t requestDidSendBytes) {
        [_pv setProgress:percent];
    };
    
    
    
//    设置上传方式：分块上传 or 表单上传  默认表单上传，大文件需要分块上传
//    uy.uploadMethod = UPMutUPload; //分块上传方式 or 表单上传方式
  
    
//    如果 policy 由业务服务端生成, 这里只需要 return policy（提前从业务服务器获取的 policy），否则就不用初始化 policyBlocker
//    uy.policyBlocker = ^()
//    {
//        return @"policy_created_by_app_server";
//    };
    
    
//    如果 sinature 由业务服务端签名, 这里只需要 return signature（提前从业务服务器获取的签名成功的 signature）, 否则就不用初始化 signatureBlocker
//    uy.signatureBlocker = ^(NSString *policy)
//    {
//        return @"signature_signed_by_app_server";
//    };

    
//    根据 文件路径 上传
      NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
      NSString *filePath = [resourcePath stringByAppendingPathComponent:@"image.jpg"];
      [uy uploadFile:filePath saveKey:@"/test2.png"];
    

//    直接上传 UIImage 类型数据
//    UIImage * image = [UIImage imageNamed:@"test2.png"];
//    [uy uploadFile:image saveKey:[self getSaveKeyWith:@"jpg"]];
    

    
//    直接上传 NSDate 类型数据
//    NSData * fileData = [NSData dataWithContentsOfFile:filePath];
//    [uy uploadFile:fileData saveKey:[self getSaveKeyWith:@"png"]];

    
    
    
//    参数更详细的接口：可以设置 form 表单的 filename 及
//    UIImage *image = [UIImage imageNamed:@"Default"];
//    [uy uploadFile:image
//           saveKey:[NSString stringWithFormat:@"/{year}/{mon}/c0974f7a-627a-44d6-9a70-dc977beb3447{.suffix}"]
//          fileName:@"aa.png"
//         extParams:nil];
    
    
}

- (NSString * )getSaveKeyWith:(NSString *)suffix {
    //设置存储路径：生成 saveKey
    
    //方式1 本地生产绝对值 saveKey
    return [NSString stringWithFormat:@"/%@.%@", [self getDateString], suffix];
    
    //方式2 由服务器根据格式生成 saveKey
    //return [NSString stringWithFormat:@"/{year}/{mon}/{filename}{.suffix}"];
    
    //更多方式 参阅 http://docs.upyun.com/api/form_api/#_5
}

- (NSString *)getDateString {
    NSDate *curDate = [NSDate date];//获取当前日期
    NSDateFormatter *formater = [[ NSDateFormatter alloc] init];
    [formater setDateFormat:@"yyyy/MM/dd"];//这里去掉 具体时间 保留日期
    NSString * curTime = [formater stringFromDate:curDate];
    curTime = [NSString stringWithFormat:@"%@/%.0f", curTime, [curDate timeIntervalSince1970]];
    return curTime;
}

// 生成随机文件
+ (NSString *)createTempFileWithSize:(NSUInteger)size {
    NSString *fileName = [NSString stringWithFormat:@"/test%08X.txt", arc4random()];
    NSURL *fileUrl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];
    NSData *data = [NSMutableData dataWithLength:size];
    NSError *error = nil;
    
    [data writeToURL:fileUrl options:NSDataWritingAtomic error:&error];
    
    return fileUrl.path;
}

+ (void)removeTempfile:(NSString *)filePath {
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
}

//livePhoto 相关可以参考博客：http://io.upyun.com/2016/03/23/the-real-files-in-alasset-and-phasset/
- (IBAction)livePhotoAction:(UIButton *)sender {
    UPLivePhotoViewController *vc = [[UPLivePhotoViewController alloc]init];
    [self presentViewController:vc animated:YES completion:nil];
}


@end
