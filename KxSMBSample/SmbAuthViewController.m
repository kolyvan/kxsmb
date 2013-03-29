//
//  SmbAuthViewController.m
//  kxsmb project
//  https://github.com/kolyvan/kxsmb/
//
//  Created by Kolyvan on 29.03.13.
//

/*
 Copyright (c) 2013 Konstantin Bukreev All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 - Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/


#import "SmbAuthViewController.h"

@interface SmbAuthViewController ()
@end

@implementation SmbAuthViewController {

    UILabel     *_pathLabel;
    UITextField *_workgroupField;
    UITextField *_usernameField;
    UITextField *_passwordField;
}

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.title =  NSLocalizedString(@"SMB Authorization", nil);
    }
    return self;
}

- (void) loadView
{
    CGRect frame = [[UIScreen mainScreen] applicationFrame];    
    const CGFloat W = frame.size.width;
    const CGFloat H = frame.size.height;
    
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, H)];
    self.view.backgroundColor = [UIColor whiteColor];
    
    /*
    UILabel *titleLabel;
    titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,10,W-20,30)];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.textColor = [UIColor redColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.text = NSLocalizedString(@"Authorization required", nil);
    [self.view addSubview:titleLabel];
    */
    
    _pathLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,10,W-20,30)];
    _pathLabel.backgroundColor = [UIColor clearColor];
    _pathLabel.textColor = [UIColor darkTextColor];
    _pathLabel.font = [UIFont systemFontOfSize:16];
    [self.view addSubview:_pathLabel];
    
    UILabel *workgroupLabel;
    workgroupLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,40,90,30)];
    workgroupLabel.backgroundColor = [UIColor clearColor];
    workgroupLabel.textColor = [UIColor darkTextColor];
    workgroupLabel.font = [UIFont boldSystemFontOfSize:16];
    workgroupLabel.text = NSLocalizedString(@"Workgroup", nil);
    [self.view addSubview:workgroupLabel];
    
    UILabel *usernameLabel;
    usernameLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,90,90,30)];
    usernameLabel.backgroundColor = [UIColor clearColor];
    usernameLabel.textColor = [UIColor darkTextColor];
    usernameLabel.font = [UIFont boldSystemFontOfSize:16];
    usernameLabel.text = NSLocalizedString(@"Username", nil);
    [self.view addSubview:usernameLabel];
    
    UILabel *passwordLabel;
    passwordLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,140,90,30)];
    passwordLabel.backgroundColor = [UIColor clearColor];
    passwordLabel.textColor =  [UIColor darkTextColor];
    passwordLabel.font = [UIFont boldSystemFontOfSize:16];
    passwordLabel.text = NSLocalizedString(@"Password", nil);    
    [self.view addSubview:passwordLabel];
    
    _workgroupField = [[UITextField alloc] initWithFrame:CGRectMake(100, 41, W - 110, 30)];
    _workgroupField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _workgroupField.autocorrectionType = UITextAutocorrectionTypeNo;
    _workgroupField.spellCheckingType = UITextSpellCheckingTypeNo;
    _workgroupField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _workgroupField.clearButtonMode =  UITextFieldViewModeWhileEditing;
    _workgroupField.textColor = [UIColor blueColor];
    _workgroupField.font = [UIFont systemFontOfSize:16];
    _workgroupField.borderStyle = UITextBorderStyleRoundedRect;
    _workgroupField.backgroundColor = [UIColor lightGrayColor];
    _workgroupField.returnKeyType = UIReturnKeyNext;
    
    [_workgroupField addTarget:self
                    action:@selector(textFieldDoneEditing:)
          forControlEvents:UIControlEventEditingDidEndOnExit];
    
    [self.view addSubview:_workgroupField];
    
    _usernameField = [[UITextField alloc] initWithFrame:CGRectMake(100, 91, W - 110, 30)];
    _usernameField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _usernameField.autocorrectionType = UITextAutocorrectionTypeNo;
    _usernameField.spellCheckingType = UITextSpellCheckingTypeNo;
    _usernameField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _usernameField.clearButtonMode =  UITextFieldViewModeWhileEditing;
    _usernameField.textColor = [UIColor blueColor];
    _usernameField.font = [UIFont systemFontOfSize:16];
    _usernameField.borderStyle = UITextBorderStyleRoundedRect;
    _usernameField.backgroundColor = [UIColor lightGrayColor];
    _usernameField.returnKeyType = UIReturnKeyDone;
    
    [_usernameField addTarget:self
                   action:@selector(textFieldDoneEditing:)
         forControlEvents:UIControlEventEditingDidEndOnExit];
    
    [self.view addSubview:_usernameField];
    
    _passwordField = [[UITextField alloc] initWithFrame:CGRectMake(100, 141, W - 110, 30)];
    _passwordField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _passwordField.autocorrectionType = UITextAutocorrectionTypeNo;
    _passwordField.spellCheckingType = UITextSpellCheckingTypeNo;
    _passwordField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _passwordField.clearButtonMode =  UITextFieldViewModeWhileEditing;
    _passwordField.textColor = [UIColor blueColor];
    _passwordField.font = [UIFont systemFontOfSize:16];
    _passwordField.borderStyle = UITextBorderStyleRoundedRect;
    _passwordField.backgroundColor = [UIColor lightGrayColor];
    _passwordField.returnKeyType = UIReturnKeyDone;
    _passwordField.secureTextEntry = YES;    
    
    [_passwordField addTarget:self
                       action:@selector(textFieldDoneEditing:)
             forControlEvents:UIControlEventEditingDidEndOnExit];
    
    [self.view addSubview:_passwordField];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIBarButtonItem *bbi;
    
    bbi = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                        target:self
                                                        action:@selector(doneAction)];
    
    self.navigationItem.rightBarButtonItem = bbi;
    
    bbi = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                        target:self
                                                        action:@selector(cancelAction)];
    
    self.navigationItem.leftBarButtonItem = bbi;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    _pathLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Server: %@", nil), _server];
    _workgroupField.text = _workgroup;
    _usernameField.text = _username;
    _passwordField.text = _password;
    
    [_workgroupField becomeFirstResponder];
}

- (void) textFieldDoneEditing: (id) sender
{
}

- (void) cancelAction
{
    __strong id p = self.delegate;
    if (p && [p respondsToSelector:@selector(couldSmbAuthViewController:done:)])
        [p couldSmbAuthViewController:self done:NO];
}

- (void) doneAction
{
    _workgroup = _workgroupField.text;
    _username = _usernameField.text;
    _password = _passwordField.text;
    
    __strong id p = self.delegate;
    if (p && [p respondsToSelector:@selector(couldSmbAuthViewController:done:)])
        [p couldSmbAuthViewController:self done:YES];
}

@end
