NSURLConnection 是iOS 2.0开始
异步加载--是iOS 5.0才有的，在5.0之前是通过代理来实现网络开发
---在开发简单的网络请求还是挺方便的，直接使用异步方法
---但是在开发复杂的网络请求，步骤非常繁琐

方式一.直接使用`NSURLConnection`的`sendAsynchronousRequest`方法发起异步请求：

代码如下：
`
   NSString *urlStr = @"http://localhost/001--等一分钟.mp4";
    NSString * url = [urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];`
`
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    ``
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {`
        `
//这一步是把数据写入磁盘，data首先是保存在内存中然后再一起写入磁盘
        [data writeToFile:@"/Users/xxxxx/Desktop/保存数据/123.wmv" atomically:YES];
    }]`



这种方式下载视频有两个问题
1.没有下载进度，会影响用户体验
2.内存偏高，有一个最大的峰值
![一次性写入磁盘会出现一次峰值.png](http://upload-images.jianshu.io/upload_images/1728672-fa57f99af36bfa2d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
我测试的时候的峰值非常恐怖，达到了1.96G

解决思路：
1.通过代理方式来解决
   进度：首先在响应方法中获得文件总大小！
              其次每次接收数据，计算数据的总比例： 每次接收的数据拼接／文件总大小
2.保存文件：
    a.保存完，写入磁盘
    b.边下载边保存


1.使用NSURLConnectionDelegate来解决上面的“没有下载进度”的问题:代码如下：
 注意： 这个`NSURLConnectionDownloadDelegate`代理方法千万别乱用，专用于杂志的下载提供接口！能够监听下载进度，但是无法拿到下载的内容；目前国内杂志的app还是比较少，国外比较流行


/** 要下载文件总大小 */
`@property(nonatomic ,assign)long long  expectedContentLength;
`
/** 当前下载的大小 */
`@property(nonatomic ,assign)long long currentLength;
`
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
`
    NSString *urlStr = @"http://localhost/001--消息发送机制.mp4";
    NSString * url = [urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    NSLog(@"开始");
    NSURLConnection *connection = [[NSURLConnection alloc]initWithRequest:request delegate:self ];
    //启动连接
    [connection start];`
    
}
//1.接收服务器响应-状态行&响应头
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
   /**
     响应头返回的数据一般有：建议的下载视频名称:textEncodingName
     下载视频总大小:expectedContentLength
     */
  `  self.expectedContentLength = response.expectedContentLength;`
 `  self.currentLength = 0;`
}
//接收到服务器的数据，此方法可能会执行很多次
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    
    //当前下载视频的大小
`
    self.currentLength = data.length;`

  `  float progress = (float)self.currentLength / self.expectedContentLength;`

}

//数据接收完成时调用此代理
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSLog(@"完成");
}
`
流程是什么样的？如下图


![请求及数据发送过程.png](http://upload-images.jianshu.io/upload_images/1728672-29940948940b1e52.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
1.  调用 ` [connection start];`方法发起请求连接
2. 调用代理方法`connection: didReceiveResponse:`得到响应头(包含文件的大小和文件名称（suggestedFilename）)和状态行：
![响应头.png](http://upload-images.jianshu.io/upload_images/1728672-2d2787376f2becb0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
3. 调用`connection:didReceiveData:`方法来接收数据，因为数据在网络中传输是以二进制数据的形式进行传输的，这里的data是发送的很多一段的二进制数据，下载完后拼接在一起，然后写入磁盘，所有这个代理方法会被多次调用；用 当前接收的数据大小/总的数据大小 = 进度，
那么进度的问题解决了，接下来是解决写入磁盘时出现峰值的问题


我在这使用了NSOutputStream输出流以文件的方式追加到输出流中，很简单只需三步即可完成：
1.创建文件流&打开文件流
   //创建输出流， 以文件追加的方式写入流中
   ` self.outStream = [[NSOutputStream alloc]initToFileAtPath:self.targetFilePath append:YES ];`
  `  [self.outStream open];`
2.写入文件流
   ` [self.outStream write:data.bytes maxLength:data.length];`
3.关闭文件流
   ` [self.outStream close];`

![使用输入流写入数据.png](http://upload-images.jianshu.io/upload_images/1728672-64576a7572b4ada6.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


到这又出现新的问题：默认NSURLConnection是在主线程工作，指定了代理的工作队列之后，
[connection setDelegateQueue:[[NSOperationQueue alloc]init]];
整个下载仍然是在主线程！！！！UI事件会卡住文件下载

 注意：在看到  NSURLConnection中的描述“ For the connection to work correctly, the calling thread’s run loop must be operating in the default run loop mode.”，这句话的意思是： 为了保证连接的正常工作,调用线程的RunLoop 必须运行在默认的运行循环模式下!!--- 这也是iOS9之后丢弃NSURLConnection的原因

那么接下来如何解决呢？ 
使用GCD来创建` dispatch_async(dispatch_get_global_queue(0, 0), ^{}`，把请求设置放block中:
·
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSString *urlStr = @"http://localhost/001--消息发送机制.mp4";
        NSString * url = [urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
        NSLog(@"开始");
        NSURLConnection *connection = [[NSURLConnection alloc]initWithRequest:request delegate:self ];
        
        [connection setDelegateQueue:[[NSOperationQueue alloc]init]];
        //启动连接
        [connection start];
    });·

但是这有个问题会出现，代理NSURLConnectionDelegate的方法不会走了！！这是为什么呢，因为这个线程    dispatch_async(dispatch_get_global_queue(0, 0), ^{})出了括号（线程的作用域）后就销毁了。
那么我们如何解决这个问题呢？
其实很简单---手动启动runloop运行循环就可以解决了

/** 下载线程的运行循环 */
`@property(assign,nonatomic)CFRunLoopRef downloadRunloop;`

在 `dispatch_async(dispatch_get_global_queue(0, 0), ^{}）`的block中启动拿到runloop
` self.downloadRunloop = CFRunLoopGetCurrent();`
启动runloop
 `CFRunLoopRun();`
在`connectionDidFinishLoading`代理方法中，停止下载线程所在的runloop
   ` CFRunLoopStop(self.downloadRunloop);`

这样就解决了卡主线程的问题了










    
