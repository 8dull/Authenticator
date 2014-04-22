//
//  OTPTokenEntryViewController.m
//  Authenticator
//
//  Copyright (c) 2013 Matt Rubin
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "OTPTokenEntryViewController.h"
#import "OTPSegmentedControlCell.h"
#import "OTPScannerViewController.h"
#import "OTPToken+Generation.h"
#import <Base32/MF_Base32Additions.h>


@interface OTPTokenEntryViewController ()
    <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, OTPTokenSourceDelegate>

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) UIBarButtonItem *doneButtonItem;

@property (nonatomic, strong) OTPSegmentedControlCell *tokenTypeCell;

@property (nonatomic, strong) IBOutlet UILabel *accountNameLabel;
@property (nonatomic, strong) IBOutlet UILabel *secretKeyLabel;

@property (nonatomic, strong) IBOutlet UITextField *accountNameField;
@property (nonatomic, strong) IBOutlet UITextField *secretKeyField;

@property (nonatomic, strong) IBOutlet UIButton *scanBarcodeButton;

@end


@implementation OTPTokenEntryViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor otpBackgroundColor];

    // Set up top bar
    self.title = @"Add Token";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(createToken)];

    self.doneButtonItem = self.navigationItem.rightBarButtonItem;
    self.doneButtonItem.enabled = NO;

    // Set up table view
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 60)];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.tableView.alwaysBounceVertical = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.tableView];

    // Style UI elements
    self.view.tintColor = [UIColor otpForegroundColor];
    self.accountNameLabel.textColor = [UIColor otpForegroundColor];
    self.secretKeyLabel.textColor   = [UIColor otpForegroundColor];
    self.accountNameField.tintColor = [UIColor otpBackgroundColor];
    self.secretKeyField.tintColor   = [UIColor otpBackgroundColor];

    // Only show the scan button if the device is capable of scanning
    self.scanBarcodeButton.hidden = ![OTPScannerViewController deviceCanScan];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.translucent = NO;
}


#pragma mark - Target Actions

- (void)cancel
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)createToken
{
    if (!self.accountNameField.text.length || !self.secretKeyField.text.length) {
        return;
    }

    NSData *secret = [NSData dataWithBase32String:self.secretKeyField.text];

    if (secret.length) {
        OTPTokenType tokenType = (self.tokenTypeCell.segmentedControl.selectedSegmentIndex == 0) ? OTPTokenTypeTimer : OTPTokenTypeCounter;
        OTPToken *token = [OTPToken tokenWithType:tokenType
                                               secret:secret
                                                 name:self.accountNameField.text];

        if (token.password) {
            id <OTPTokenSourceDelegate> delegate = self.delegate;
            [delegate tokenSource:self didCreateToken:token];
            return;
        }
    }

    // If the method hasn't returned by this point, token creation failed
    [SVProgressHUD showErrorWithStatus:@"Invalid Token"];
}

- (IBAction)scanBarcode:(id)sender
{
    OTPScannerViewController *scanner = [[OTPScannerViewController alloc] init];
    scanner.delegate = self;
    [self.navigationController pushViewController:scanner animated:YES];
}


#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return self.tokenTypeCell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 59;
}


#pragma mark - Cells

- (OTPSegmentedControlCell *)tokenTypeCell
{
    if (!_tokenTypeCell) {
        _tokenTypeCell = [OTPSegmentedControlCell cellForTableView:self.tableView];
        [_tokenTypeCell.segmentedControl insertSegmentWithTitle:@"Time Based" atIndex:0 animated:NO];
        [_tokenTypeCell.segmentedControl insertSegmentWithTitle:@"Counter Based" atIndex:1 animated:NO];
        _tokenTypeCell.segmentedControl.selectedSegmentIndex = 0;
    }
    return _tokenTypeCell;
}


#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == self.accountNameField) {
        [self.secretKeyField becomeFirstResponder];
        return NO;
    } else {
        [textField resignFirstResponder];
        [self createToken];
        return NO;
    }
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    // Ensure both fields (will) have text in them
    NSString *newText = [[textField.text mutableCopy] stringByReplacingCharactersInRange:range withString:string];
    if (textField == self.accountNameField) {
        self.doneButtonItem.enabled = newText.length && self.secretKeyField.text.length;
    } else if (textField == self.secretKeyField) {
        self.doneButtonItem.enabled = newText.length && self.accountNameField.text.length;
    }

    return YES;
}


#pragma mark - OTPTokenSourceDelegate

- (void)tokenSource:(id)tokenSource didCreateToken:(OTPToken *)token
{
    id <OTPTokenSourceDelegate> delegate = self.delegate;
    [delegate tokenSource:self didCreateToken:token];
}

@end
