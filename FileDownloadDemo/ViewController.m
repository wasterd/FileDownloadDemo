//
//  ViewController.m
//  FileDownloadDemo
//
//  Created by ya Liu on 2017/11/8.
//  Copyright © 2017年 wasterd. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()<NSURLConnectionDelegate>


/** 要下载文件总大小 */
@property(nonatomic ,assign)long long  expectedContentLength;

/** 当前下载的大小 */
@property(nonatomic ,assign)long long currentLength;

/** 保存路径 */
@property(nonatomic ,copy)NSString *targetFilePath;

/** 保存文件数据流 */
@property(nonatomic ,strong)NSOutputStream  *outStream;

@property (weak, nonatomic) IBOutlet UIProgressView *downloadProgressView;

/** 下载线程的运行循环 */
@property(assign,nonatomic)CFRunLoopRef downloadRunloop;

@end

@implementation ViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSString *urlStr = @"http://localhost/001--消息发送机制.mp4";
        NSString * url = [urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        //1.创建请求
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
        NSLog(@"开始");
        //2.创建连接
        NSURLConnection *connection = [[NSURLConnection alloc]initWithRequest:request delegate:self ];
        //3.设置队列
        [connection setDelegateQueue:[[NSOperationQueue alloc]init]];
        //4.启动连接
        [connection start];
        
        
        //5. 启动运行循环
        //CoreFoundation 框架 CFRunloop
        /*
         CFRunLoopStop(r)        停止指定的RunLoop
         CFRunLoopGetCurrent()   拿到当前的RunLoop
         CFRunLoopRun();         直接启动当前的运行循环
         */
        //1.拿到当前线程的运行循环
        self.downloadRunloop = CFRunLoopGetCurrent();
        //2.启动运行循环
        CFRunLoopRun();
        
        
    });
    
}


//1.接收服务器响应-状态行&响应头
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSLog(@"响应头:%@",response);
    /**
     响应头返回的数据一般有：建议的下载视频名称:textEncodingName
     下载视频总大小:expectedContentLength
     */
    self.expectedContentLength = response.expectedContentLength;
    self.currentLength = 0;
    //生成目标文件的路径
    self.targetFilePath = [@"/Users/xxx/desktop/123" stringByAppendingPathComponent:response.suggestedFilename];
    
    //删除removeItemAtPath,如果文件存在，就会直接删除，如果文件不存在，就不做任何操作
    //    [[NSFileManager defaultManager] removeItemAtPath:self.targetFilePath error:NULL];
    
    //创建输出流， 以文件追加的方式写入流中
    self.outStream = [[NSOutputStream alloc]initToFileAtPath:self.targetFilePath append:YES ];
    [self.outStream open];
}


//接收到服务器的数据，此方法可能会执行很多次
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    
    //当前下载视频的大小
    self.currentLength += data.length;
    float progress = (float)self.currentLength / self.expectedContentLength;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.downloadProgressView.progress = progress;
    });
    NSLog(@"%f",progress);
    //写入文件流
    [self.outStream write:data.bytes maxLength:data.length];
}

//数据接收完成时调用此代理
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSLog(@"完成");
    //关闭文件流
    [self.outStream close];
    
    //停止下载线程所在的运行循环
    CFRunLoopStop(self.downloadRunloop);
}
//下载失败或错误
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    NSLog(@"失败");
}


@end
