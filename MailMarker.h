
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

