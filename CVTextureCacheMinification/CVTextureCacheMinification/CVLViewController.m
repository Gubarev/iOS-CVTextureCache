//
//  CVLViewController.m
//  CVTextureCacheMinification
//
//  Created by Vladislav Gubarev on 07/11/13.
//  Copyright (c) 2013 CVisionLab. All rights reserved.
//

#import "CVLViewController.h"



@implementation CVLViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



- (BOOL)prefersStatusBarHidden {
    return YES;
}



- (IBAction)onModeSwitched:(UISegmentedControl *)sender {
    [_canvas switchToMode:sender.selectedSegmentIndex];
}

@end
