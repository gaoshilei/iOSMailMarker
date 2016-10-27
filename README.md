
定位邮件App可执行文件的位置：
iPhone-5S:~ root# ps -e | grep Mail
444 ??         0:34.05 /var/db/stash/_.fP74Fg/Applications/MobileMail.app/MobileMail
2715 ttys000    0:00.01 grep Mail
将可执行文件拷贝到OSX待用：
LeonLei-MBP:~ gaoshilei$ scp -P 6666 root@localhost:/var/db/stash/_.fP74Fg/Applications/MobileMail.app/MobileMail /Users/gaoshilei/Desktop/reverse/binary_for_class-dump 
MobileMail                                       100% 2762KB   2.7MB/s   00:00    
因为MobileMail的位置是/Applications/MobileMail.app/MobileMail属于系统应用，没有加密，所以不需要砸壳，直接class-dump导出头文件：
LeonLei-MBP:~ gaoshilei$ class-dump -S -s -H /Users/gaoshilei/Desktop/reverse/binary_for_class-dump/MobileMail -o /Users/gaoshilei/Desktop/reverse/binary_for_class-dump/class-Header/MobileMail 
命令执行后得到573个.h文件。接下来开始寻找线索，以App的界面为切入点，寻找Mailboxes界面的Controller
iPhone-5S:~ root# ps -e | grep Mail
444 ??         0:34.05 /var/db/stash/_.fP74Fg/Applications/MobileMail.app/MobileMail
2715 ttys000    0:00.01 grep Mail
iPhone-5S:~ root# cycript -p MobileMail               
cy# [[UIApp keyWindow] recursiveDescription].toString()
找到邮件的可执行文件，用cycript注入App，利用recursiveDescription打印当前界面的UI树状结构：
|    |    |    |    |    |    |    |    |    |    |    | <UITableViewLabel: 0x1467fb3e0; frame = (55 12; 26 20.5); text = 'VIP'; userInteractionEnabled = NO; layer = <_UILabelLayer: 0x1467fb5f0>>
其中有一个UILabel的内容是VIP，属于当前页面的第二个cell，我们利用响应者链条找到当前的Controller
cy# [#0x1467fb3e0 nextResponder]
#"<UITableViewCellContentView: 0x1467faa60; frame = (0 0; 286 43.5); gestureRecognizers = <NSArray: 0x1467fb160>; layer = <CALayer: 0x1467fa680>>"
cy# [#0x1467faa60 nextResponder]
#"<MailboxTableCell: 0x1470c1c00; baseClass = UITableViewCell; frame = (0 72; 320 44); text = 'VIP'; autoresize = W; layer = <CALayer: 0x1467fa660>>"
cy# [#0x1470c1c00 nextResponder]
#"<UITableViewWrapperView: 0x14704a600; frame = (0 0; 320 504); gestureRecognizers = <NSArray: 0x1465ef0f0>; layer = <CALayer: 0x1467688e0>; contentOffset: {0, 0}; contentSize: {320, 504}>"
cy# [#0x14704a600 nextResponder]
#"<UITableView: 0x14704c800; frame = (0 0; 320 568); clipsToBounds = YES; autoresize = W+H; gestureRecognizers = <NSArray: 0x146767c60>; layer = <CALayer: 0x146760ed0>; contentOffset: {0, -64}; contentSize: {320, 632}>"
cy# [#0x14704c800 nextResponder]
#"<MailboxPickerController: 0x14674da60>"
很容易找到当前的Controller是MailboxPickerController，我们尝试改变它的leftBarButtonItem
cy# [[#0x14674da60 navigationItem] title]
@"Mailboxes"
cy# [[#0x14674da60 navigationItem] setLeftBarButtonItem:[[#0x14674da60 navigationItem] rightBarButtonItem]]
我把右边的item复制一份到了左边，效果图：
![]()
我的猜想是正确的，可以通过MailboxPickerController添加设置白名单的按钮，接下来就要实现添加白名单的功能了。
要拿到所有邮件才能对邮件进行操作，每个邮件应该是一个对象，每次刷新都会加载新的邮件，尝试找到刷新加载新邮件在哪里，拿到这些新邮件就可以进行标记等操作了。考虑到这里，一般刷新操作都会放在protocol中，刷新完成会加载资源，用Reveal查看Inboxs里面每个邮件所在的控制器位置，这里也可以用cycript打印当前UI结构来查看，不过Reveal更加直观快速。Reveal查看的效果图如下：
![Reveal](http://oeat6c2zg.bkt.clouddn.com/%E9%82%AE%E7%AE%B1%E7%99%BD%E5%90%8D%E5%8D%95%E5%8A%9F%E8%83%BDReveal.png)
MailboxContentViewCell就是当前页面每个邮件标题、发件人和内容的cell，再利用choose命令打印当前页面所有的MailboxContentViewCell
cy# choose(MailboxContentViewCell)
#"<MailboxContentViewCell: 0x14584b400> Reset Password",
#"<MailboxContentViewCell: 0x1458b6000> Your app(iOS) status is In Review",
#"<MailboxContentViewCell: 0x1458c3400> Your app(iOS) status is Prepare for Upload",
#"<MailboxContentViewCell: 0x1458c8a00> Your app(iOS) status is Prepare for Upload",,
#"<MailboxContentViewCell: 0x1458d5400> Your app(iOS) status is Developer Rejected",
#"<MailboxContentViewCell: 0x1458db600> Your app(iOS) status is Waiting For Review",
#"<MailboxContentViewCell: 0x1458dbe00> The status for your app, \xe6\x8e\xa8\xe8\x8d\x90\xe5\x8a\xa9\xe6\x89\x8b (1163571218), is now Ready for Sale.",
#"<MailboxContentViewCell: 0x1458dd400> goslei\xef\xbc\x8c9\xe6\x9c\x88\xe8\xb4\xa2\xe6\x8a\xa5\xe4\xbe\x9b\xe6\x82\xa8\xe6\x9f\xa5\xe9\x98\x85\xef\xbc\x81",
#"<MailboxContentViewCell: 0x1458e1600> Your app(iOS) status is Waiting For Review",
#"<MailboxContentViewCell: 0x1458e7400> Your app(iOS) status is In Review"]
随便选一个，找到它所在的UITableView
cy# [#0x14584b400 nextResponder]
#"<UITableViewWrapperView: 0x145844c00; frame = (0 0; 320 612); gestureRecognizers = <NSArray: 0x1456c53b0>; layer = <CALayer: 0x1468003b0>; contentOffset: {0, 0}; contentSize: {320, 612}>"
cy# [#0x145844c00 nextResponder]
#"<MFMailboxTableView: 0x145841a00; baseClass = UITableView; frame = (0 0; 320 568); clipsToBounds = YES; autoresize = W+H; gestureRecognizers = <NSArray: 0x1456ae300>; layer = <CALayer: 0x1456b6840>; contentOffset: {0, -20}; contentSize: {320, 39884}>"
它所在的UITableView是一个MFMailboxTableView对象，然后看看它的代理是谁
cy# [#0x145841a00 nextResponder]
#"<MailboxContentViewController: 0x14609ce00>"
cy# [#0x145841a00 delegate]
#"<MailboxContentViewController: 0x14609ce00>"
MFMailboxTableView的nextResponder和delegate均是MailboxContentViewController，这个控制器中应该有邮件刷新的完成的相应函数。定位到刚才导出的头文件，发现这个类中实现了以下协议：
@interface MailboxContentViewController : UIViewController <MailboxContentSelectionModelDataSource, MFSearchControllerDelegate, MessageMiniMallObserver, MFAddressBookClient, MFMailboxTableViewDelegate, UIPopoverPresentationControllerDelegate, MFReclaimable, UIViewControllerPreviewingDelegate, UIViewControllerPreviewingDelegate_Private, UITableViewDelegate, UITableViewDataSource, TransferMailboxPickerDelegate, AutoFetchControllerDataSource>
{
比较可疑的几个协议有：
MailboxContentSelectionModelDataSource、MessageMiniMallObserver、MFMailboxTableViewDelegate、TransferMailboxPickerDelegate，一个个排查:
MessageMiniMallObserver.h中有这几个方法：
- (void)miniMallDidLoadMessages:(NSNotification *)arg1;
- (void)miniMallFinishedFetch:(NSNotification *)arg1;
- (void)miniMallGrowingMailboxesChanged:(NSNotification *)arg1;
- (void)miniMallMessageCountDidChange:(NSNotification *)arg1;
- (void)miniMallMessageCountWillChange:(NSNotification *)arg1;
- (void)miniMallStartFetch:(NSNotification *)arg1;
看上去有fetch、change、FinishedFetch等关键词，下面用LLDB附加二进制文件，在这几个函数位置打断点，看看刷新邮件的时候会发生什么。老规矩，之前scp的MobileMail丢进IDA中分析，查看手机中MobileMail的ASLR，然后打断点：
(lldb) br s -a 0x100016994+0x18000
Breakpoint 1: where = MobileMail`___lldb_unnamed_symbol328$$MobileMail + 4, address = 0x000000010002e994
(lldb) br s -a 0x1000391FC+0x18000
Breakpoint 2: where = MobileMail`___lldb_unnamed_symbol1012$$MobileMail + 4, address = 0x00000001000511fc
(lldb) br s -a 0x10003971C+0x18000
Breakpoint 3: where = MobileMail`___lldb_unnamed_symbol1018$$MobileMail + 4, address = 0x000000010005171c
其中0x18000是当前MobileMail的基地址偏移，可通过im li -o -f查看。刷新邮件看看是否触发断点。  
Process 2916 stopped
* thread #1: tid = 0x2cfe8, 0x000000010002e994 MobileMail`___lldb_unnamed_symbol328$$MobileMail + 4, queue = 'com.apple.main-thread', stop reason = breakpoint 1.1
frame #0: 0x000000010002e994 MobileMail`___lldb_unnamed_symbol328$$MobileMail + 4
MobileMail`___lldb_unnamed_symbol328$$MobileMail:
->  0x10002e994 <+4>:  mov    x29, sp
0x10002e998 <+8>:  sub    sp, sp, #48               ; =48 
0x10002e99c <+12>: adrp   x8, 614
0x10002e9a0 <+16>: ldrsw  x8, [x8, #92]
                               (lldb) c
Process 2916 resuming
Process 2916 stopped
* thread #14: tid = 0x304e9, 0x00000001000511fc MobileMail`___lldb_unnamed_symbol1012$$MobileMail + 4, stop reason = breakpoint 2.1
frame #0: 0x00000001000511fc MobileMail`___lldb_unnamed_symbol1012$$MobileMail + 4
MobileMail`___lldb_unnamed_symbol1012$$MobileMail:
->  0x1000511fc <+4>:  mov    x29, sp
0x100051200 <+8>:  sub    sp, sp, #48               ; =48 
0x100051204 <+12>: adrp   x8, 447
0x100051208 <+16>: ldr    x8, [x8, #3200]
断点1首先被触发，接着断点2被触发，断点3未被触发。也就是miniMallMessageCountDidChang:这个方法没有被触发，这个协议看上去是邮件计数用的，这次刷新并没有新邮件所以没有调用，为了验证我的猜想，我给我这个邮箱发一封新邮件，再次刷新看断点。
Process 2916 resuming
Process 2916 stopped
* thread #1: tid = 0x2cfe8, 0x000000010005171c MobileMail`___lldb_unnamed_symbol1018$$MobileMail + 4, queue = 'MessageMiniMall.0x145754f80', stop reason = breakpoint 3.1
frame #0: 0x000000010005171c MobileMail`___lldb_unnamed_symbol1018$$MobileMail + 4
MobileMail`___lldb_unnamed_symbol1018$$MobileMail:
->  0x10005171c <+4>:  stp    d9, d8, [sp, #16]
0x100051720 <+8>:  stp    x28, x27, [sp, #32]
0x100051724 <+12>: stp    x26, x25, [sp, #48]
0x100051728 <+16>: stp    x24, x23, [sp, #64]
                                     (lldb) c
Process 2916 resuming
此时断点3也走了，证明我的猜想是正确的。已经找到邮件刷新完成的函数，下一步要从这个函数中拿到邮件。我选择从miniMallMessageCountDidChange:这个方法入手，disable其他断点只留断点3，重新发一封邮件，刷新触发断点，打印参数x2
(lldb) p/x $x2
(unsigned long) $62 = 0x0000000146c7c1b0
(lldb) po [$x2 class]
NSConcreteNotification
发现x2是一个指针，打印出指针所指向的类为NSConcreteNotification，并且我们在Foundation.framework中（通过grep定位）找到NSConcreteNotification头文件
@interface NSConcreteNotification : NSNotification {
BOOL dyingObject;
NSString *name;
id object;
NSDictionary *userInfo;
}
+ (id)newTempNotificationWithName:(id)arg1 object:(id)arg2 userInfo:(id)arg3;
- (void)dealloc;
- (id)initWithName:(id)arg1 object:(id)arg2 userInfo:(id)arg3;
- (id)name;
- (id)object;
- (void)recycle;
- (id)userInfo;
@end
NSConcreteNotification继承自NSNotification，这跟在MessageMiniMallObserver中看到的方法
- (void)miniMallMessageCountDidChange:(NSNotification *)arg1;  
里面的参数是一致的。NSConcreteNotification中的object是我们最关心的，这个object应该就储存了邮件对象，这里x2是指针，没有办法直接调用方法获得相应的属性，但是程序最终肯定会拿到这个object，我们继续让断点逐行往下走，走到0x100039740这个位置x2赋给了x21，继续走到0x100039760位置x21赋给了x0，在下一行的位置调用了_objc_msgSend，这里实现了函数调用，再往下走一行，发现此时的x0已经变成
(lldb) po $x24
<MessageMiniMall: 0x145754f80>
而x24是x0赋值过来的，所以可以肯定的是在0x100039764把userInfo里面的内容拿出来了。并且有一个对象为
MessageMiniMall，接下来看一下这个类的头文件，发现所有跟邮件相关的操作和信息在这里面都能找到，所以这个类就是邮件的“商场”，注意到这个类种有一个实例方法
- (id)copyAllMessages;
在LLDB验证一下是否有效。
(lldb) po (int)[[$x0 copyAllMessages] count]
423
(lldb) po [$x0 copyAllMessages]
<MFLibraryMessage 0x131258950: library id 325, remote id 1375939230, 2016-04-30 11:05:27 +0000, 'Apple 提供的收据'>
因为邮件太多，一共有423封，这里选取其中一条打印内容，可以看来MFLibraryMessage保存的是邮件的摘要信息。回过头来，在MessageMiniMall中发现了下面这个方法
- (void)markMessagesAsViewed:(id)arg1;
OC语法有个最大的好处就是见名识意，这个方法肯定就是标记邮件为已读了，唯一棘手的就是这个参数应该传什么？我们先放着，解决另一个问题：提取发件人地址，在白名单中的发件人地址不自动标记已读。在MessageMiniMall中并没有发现类似的属性或方法，把目光移向MFLibraryMessage，用grep命令在PrivateFrameworks/Message.framework找到了它，MFLibraryMessage.h中有很多ID之类的属性，但是没有一个摘要信息的方法或属性，不过有一个方法
- (id)copyMessageInfo;
引起了注意，有关键词messageInfo，我们打印出来看看
(lldb) po [[[$x0 copyAllMessages] anyObject] copyMessageInfo]
<MFMessageInfo: 0x13135fe40> uid=89, conversation=-6684413870088214712, messageID=-6684413870088214712, received=1468591509
是一个MFMessageInfo对象，在刚才找到MFLibraryMessage.h的附近发现了这个类的头文件。遍历一遍没有发现任何有价值的线索，回过头看看上一步是不是遗漏了什么，MFLibraryMessage是继承自MFMailMessage，在刚才的位置又找了这个类的头文件，也没有什么线索，但是发现MFMailMessage又继承自MFMessage，继续逆流而上，在刚才的位置已经找不到我们要找的头文件了，继续用grep寻找，发现它位于PrivateFrameworks/MIME.framework中。找找啊找朋友找到一个好朋友
- (id)senders;
打印这个方法调用
(lldb) po  [[[$x0 copyAllMessages] anyObject] senders]
<__NSArrayI 0x1312477f0>(
Apple <no_reply@email.apple.com>
)
这个方法返回的是这封邮件的发件人数组，发件人也找到了，上面遗留的问题应该要得到解决了。在IDA中找到markMessagesAsViewed方法下好断点，等会对邮件标记已读观察断点的情况。阅读邮件然后返回，此时触发了断点。打印参数x2
(lldb) po $x2
{(
<MFLibraryMessage 0x131319150: library id 509, remote id 1375939451, 2016-03-24 08:10:45 +0000, '测试邮件'>
)}
(lldb) po [$x2 class]
__NSSingleObjectSetI
可以看出来- (void)markMessagesAsViewed:(id)arg1中的id是一个由MFLibraryMessage组成的NSSingleObjectSet。至此，已经完成了90%的工作，剩下的就是编写tweak实现邮箱白名单不自动标记的功能了。  
tweak的创建过程很简单就省略了，其中要注意的是邮件的bundleId为com.apple.mobilemail，tweak文件内容：  
#import "MailMarker.h"
%hook MailboxPickerController
-(void)viewWillAppear:(BOOL)animated
{
self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Whitelist" style:UIBarButtonItemStylePlain target:self action:@selector(showWhitelist)];
%orig;
}
%new
- (void)showWhitelist
{
UIAlertController* alertController = [UIAlertController alertControllerWithTitle:@"WhiteList"
message:@"Please Input An Email Address"
preferredStyle:UIAlertControllerStyleAlert];

UIAlertAction* OKAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
handler:^(UIAlertAction * action) {
UITextField *whitelist = alertController.textFields.firstObject;
if (whitelist.text.length > 0) {
[[NSUserDefaults standardUserDefaults] setObject:whitelist.text forKey:@"whitelist"];
}

}];
UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style: UIAlertActionStyleCancel handler:nil];
[alertController addAction:OKAction];
[alertController addAction:cancelAction];
[alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
textField.placeholder = @"goslei1315@gmail.com";
textField.text = [[NSUserDefaults  standardUserDefaults] objectForKey:@"whitelist"];
}];
[self presentViewController:alertController animated:YES completion:nil];
}
%end

%hook MailboxContentViewController
- (void)miniMallMessageCountDidChange:(id)arg1
{
%orig;
NSMutableSet *Messageset = [NSMutableSet setWithCapacity:100];
NSString *whitelist = [[NSUserDefaults standardUserDefaults] objectForKey:@"whitelist"];
MessageMiniMall *mall = [arg1 object];
NSSet *messages = [mall copyAllMessages];
for (MFLibraryMessage *message in messages) {
MFMessageInfo *messageInfo = [message copyMessageInfo];
NSArray *senders = [message senders];
for (NSString *sender in senders){
if(!messageInfo.read&&([sender rangeOfString:whitelist].location==NSNotFound)){
[Messageset addObject:message];
}
}
}
[mall markMessagesAsViewed:Messageset];
}
%end
hook住MailboxPickerController和MailboxContentViewController实现方法即可，
#import "MailMarker.h"的头文件是自己创建的，防止tweak在编译的时候找不到类的方法和属性而报错，头文件的内容：
@interface NSConcreteNotification : NSObject
@end
@interface MFLibraryMessage:NSObject
- (id)senders;
- (id)copyMessageInfo;
@end
@interface MFMessageInfo : NSObject
- (BOOL)read;
@end
@interface MFMailMessage:NSObject
- (id)copyMessageInfo;
@end
@interface MessageMiniMall:NSObject
- (void)markMessagesAsViewed:(id)arg1;
- (id)copyAllMessages;
@end
@interface MailboxPickerController : UIViewController
@property(nonatomic, readonly, strong) UINavigationItem *navigationItem;
@end
@interface MailboxContentViewController : UIViewController
- (void)miniMallMessageCountDidChange:(id)arg1;
@end
然后执行make package install安装到手机上大功告成！
