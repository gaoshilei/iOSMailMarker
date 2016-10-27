#import "MailMarker.h"
%hook MailboxPickerController
-(void)viewDidAppear:(BOOL)animated
{
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Whitelist" style:UIBarButtonItemStylePlain target:self action:@selector(iOSREShowWhitelist)];
%orig;
}
%new
- (void)iOSREShowWhitelist
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
