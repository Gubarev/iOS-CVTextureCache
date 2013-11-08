//
//  CVLCanvasView.h
//  CVTextureCacheMinification
//
//  Created by Vladislav Gubarev on 07/11/13.
//  Copyright (c) 2013 CVisionLab. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>



@interface CVLCanvasView : UIView


/// Switch to @a mode (0 - regualer textures, 1 - CV texture cache).
- (void)switchToMode:(NSUInteger)mode;

@end
