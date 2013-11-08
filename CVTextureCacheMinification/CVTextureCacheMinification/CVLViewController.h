//
//  CVLViewController.h
//  CVTextureCacheMinification
//
//  Created by Vladislav Gubarev on 07/11/13.
//  Copyright (c) 2013 CVisionLab. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CVLCanvasView.h"

@interface CVLViewController : UIViewController

@property (weak, nonatomic) IBOutlet CVLCanvasView *canvas;
- (IBAction)onModeSwitched:(UISegmentedControl *)sender;

@end
