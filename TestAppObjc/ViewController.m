//
// Copyright 2021 Adobe. All rights reserved.
// This file is licensed to you under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License. You may obtain a copy
// of the License at http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under
// the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
// OF ANY KIND, either express or implied. See the License for the specific language
// governing permissions and limitations under the License.
//

#import "ViewController.h"
@import AEPEdgeConsent;

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextView *txtFieldConsent;
@property (weak, nonatomic) IBOutlet UILabel *extensionLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [_extensionLabel setText:[NSString stringWithFormat:@"AEPEdgeConsent : %@", [AEPMobileEdgeConsent extensionVersion]]];
    
}

- (IBAction)changeDefault:(id)sender {
    NSMutableDictionary *config = [[NSMutableDictionary alloc] init];
    [config setValue:@{@"consents" : @{ @"collect": @{@"val": @"p"}}} forKey:@"consent.default"];
}

- (IBAction)collectConsentNO:(id)sender {
    [AEPMobileEdgeConsent updateWithConsents:@{@"consents": @{ @"collect": @{@"val": @"n"}}}];
}

- (IBAction)collectConsentYES:(id)sender {
    [AEPMobileEdgeConsent updateWithConsents:@{@"consents": @{ @"collect": @{@"val": @"y"}}}];
}

- (IBAction)getConsent:(id)sender {
    [AEPMobileEdgeConsent getConsents:^(NSDictionary *consent, NSError *error){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.txtFieldConsent setText:[NSString stringWithFormat:@"%@",consent]];
        });        
    }];
}


@end
