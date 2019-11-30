//
//  ViewController.m
//  SamplesObjC
//
//  Created by Shin Yamamoto on 2018/12/07.
//  Copyright © 2018 Shin Yamamoto. All rights reserved.
//

#import "ViewController.h"
@import FloatingPanel;

///* --- Importing Swift into Objective-C -- */
//#import "SamplesObjC-Swift.h"
//@class FloatingPanelAdapter;
///* --------------------------------------- */
//
@interface ViewController()<FloatingPanelControllerDelegate>
//@property FloatingPanelAdapter *fpAdapter;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    FloatingPanelController *fpc = [[FloatingPanelController alloc] init];
    [fpc setContentViewController:nil];
    [fpc trackScrollView:nil];
    [fpc setDelegate:self];
//    [fpc show:true completion:nil];
//    [fpc hide:true completion:nil];
    [fpc addPanelToParent:self belowView:nil animated:true];
//    [fpc removePanelFromParent:true completion:nil];
    [fpc moveTo:FloatingPanelStateTip animated:true completion:nil];

    [fpc setLayout: [MyFloatingPanelLayout new]];
    [fpc setBehavior:[MyFloatingPanelBehavior new]];
    [fpc setRemovalInteractionEnabled:NO];
}

- (id<FloatingPanelLayout>)floatingPanel:(FloatingPanelController *)vc layoutFor:(UITraitCollection *)newCollection {
    FloatingPanelDefaultLayout *layout = [FloatingPanelDefaultLayout new];
    return layout;
}

- (id<FloatingPanelBehavior>)floatingPanel:(FloatingPanelController *)vc behaviorFor:(UITraitCollection *)newCollection {
    return [MyFloatingPanelBehavior new];
}
@end

@implementation  MyFloatingPanelLayout
- (FloatingPanelState)initialState {
    return FloatingPanelStateFull;
}
- (NSDictionary<FloatingPanelState, id<FloatingPanelLayoutAnchoring>> *)layoutAnchors {
    return @{
        FloatingPanelStateFull: [[FloatingPanelIntrinsicLayoutAnchor alloc] initWithFractionalVisibleOffset:0.0
                                                                                       referenceGuide:FloatingPanelLayoutReferenceGuideSafeArea],
        FloatingPanelStateTip: [[FloatingPanelLayoutAnchor alloc] initWithAbsoluteInset:16.0
                                                                          referenceGuide:FloatingPanelLayoutReferenceGuideSafeArea
                                                                                    edge:UIRectEdgeBottom],
    };
}
- (enum FloatingPanelPosition)position {
    return FloatingPanelRectEdgeBottom;
}
@end


@implementation MyFloatingPanelBehavior
- (BOOL)shouldProjectMomentum:(FloatingPanelController *)fpc for:(FloatingPanelState)proposedTargetPosition {
    return NO;
}
@end
