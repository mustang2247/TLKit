//
//  TLTabBar.m
//  TLChat
//
//  Created by 李伯坤 on 2017/7/6.
//  Copyright © 2017年 李伯坤. All rights reserved.
//

#import "TLTabBar.h"
#import "TLTabBarItem.h"
#import "TLTabBarPlusItem.h"

@interface TLTabBar ()

@property (nonatomic, weak) UITabBar *systemTabBar;

@property (nonatomic, strong, readonly) NSMutableArray *tabBarItems;

@end

@implementation TLTabBar
@synthesize tabBarItems = _tabBarItems;

- (id)initWithSystemTabBar:(UITabBar *)systemTabBar
{
    if (self = [super initWithFrame:systemTabBar.bounds]) {
        _tabBarItems = [[NSMutableArray alloc] init];
        [self setSystemTabBar:systemTabBar];
    }
    return self;
}

- (void)dealloc
{
    [self.systemTabBar removeObserver:self forKeyPath:@"frame"];
    [self.systemTabBar removeObserver:self forKeyPath:@"barTintColor"];
    [self.systemTabBar removeObserver:self forKeyPath:@"unselectedItemTintColor"];
    [self.systemTabBar removeObserver:self forKeyPath:@"tintColor"];
}

#pragma mark - # Public Methods
- (void)addTabBarItemWithSystemTabBarItem:(UITabBarItem *)systemTabBarItem actionBlock:(BOOL (^)())actionBlock
{
    TLTabBarItem *tabBarItem = [[TLTabBarItem alloc] initWithSystemTabBarItem:systemTabBarItem clickActionBlock:actionBlock];
    [tabBarItem setTintColor:self.systemTabBar.tintColor];
    [tabBarItem addTarget:self action:@selector(tabBarItemTouchDown:) forControlEvents:UIControlEventTouchDown];
    [tabBarItem addTarget:self action:@selector(tabBarItemTouchDownRepeat:) forControlEvents:UIControlEventTouchDownRepeat];
    __weak typeof(self) weakSelf = self;
    [tabBarItem setDidChangedTabBarItem:^{
        [weakSelf.systemTabBar.subviews enumerateObjectsUsingBlock:^(__kindof UIView * obj, NSUInteger idx, BOOL * stop) {
            if ([obj isKindOfClass:[UIControl class]]) {
                [obj removeFromSuperview];
            }
        }];
    }];
    
    // 选中、添加到数组
    if (self.tabBarItems.count == 0) {
        [tabBarItem setSelected:YES];
    }
    [self.tabBarItems addObject:tabBarItem];
    // 更新UI
    [self addSubview:tabBarItem];
    [self p_resetTabBarItemFrames];
}

- (void)addPlusItemWithSystemTabBarItem:(UITabBarItem *)systemTabBarItem actionBlock:(BOOL (^)())actionBlock
{
    TLTabBarPlusItem *plusItem = [[TLTabBarPlusItem alloc] initWithSystemTabBarItem:systemTabBarItem clickActionBlock:actionBlock];
    [plusItem setTintColor:self.systemTabBar.tintColor];
    [plusItem addTarget:self action:@selector(tabBarItemTouchDown:) forControlEvents:UIControlEventTouchDown];
    __weak typeof(self) weakSelf = self;
    [plusItem setDidChangedTabBarItem:^{
        [weakSelf.systemTabBar.subviews enumerateObjectsUsingBlock:^(__kindof UIView * obj, NSUInteger idx, BOOL * stop) {
            if ([obj isKindOfClass:[UIControl class]]) {
                [obj removeFromSuperview];
            }
        }];
    }];
    
    [self.tabBarItems addObject:plusItem];
    // 更新UI
    [self addSubview:plusItem];
    [self p_resetTabBarItemFrames];
}

- (void)setSystemTabBar:(UITabBar *)systemTabBar
{
    _systemTabBar = systemTabBar;
    [self setBackgroundColor:self.systemTabBar.barTintColor];
    [systemTabBar addObserver:self forKeyPath:@"frame" options:NSKeyValueObservingOptionNew context:nil];
    [systemTabBar addObserver:self forKeyPath:@"barTintColor" options:NSKeyValueObservingOptionNew context:nil];
    [systemTabBar addObserver:self forKeyPath:@"unselectedItemTintColor" options:NSKeyValueObservingOptionNew context:nil];
    [systemTabBar addObserver:self forKeyPath:@"tintColor" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)setSelectedIndex:(NSInteger)selectedIndex
{
    _selectedIndex = selectedIndex;
    for (int i = 0; i < self.tabBarItems.count; i++) {
        TLTabBarItem *item = self.tabBarItems[i];
        [item setSelected:i == selectedIndex];
    }
}

#pragma mark - # Event Response
- (void)tabBarItemTouchDown:(TLTabBarItem *)sender
{
    if (sender.isSelected) {
        [self performSelector:@selector(tabBarItemClick:) withObject:sender afterDelay:0.2];
    }
    else {
        [sender setUserInteractionEnabled:NO];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [sender setUserInteractionEnabled:YES];
        });
        [self tabBarItemClick:sender];
    }
}

- (void)tabBarItemClick:(TLTabBarItem *)sender
{
    BOOL canSelect = YES;
    if (sender.clickActionBlock) {
        canSelect = sender.clickActionBlock();
    }
    if (canSelect) {
        if (self.didSelectItemAtIndex) {
            self.didSelectItemAtIndex([self.tabBarItems indexOfObject:sender]);
        }
        for (TLTabBarItem *item in self.tabBarItems) {
            if (item == sender) {
                [item setSelected:YES];
                _selectedIndex = [self.tabBarItems indexOfObject:item];
            }
            else {
                [item setSelected:NO];
            }
        }
    }
}

- (void)tabBarItemTouchDownRepeat:(TLTabBarItem *)sender
{
    [sender setUserInteractionEnabled:NO];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [sender setUserInteractionEnabled:YES];
    });
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tabBarItemClick:) object:sender];
    
    if (!sender.isSelected) {
        [self tabBarItemClick:sender];
    }
    else {
        if (self.didDoubleClickItemAtIndex) {
            self.didDoubleClickItemAtIndex([self.tabBarItems indexOfObject:sender]);
        }
    }
}

#pragma mark - # Private Methods
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    [self setFrame:self.systemTabBar.bounds];
    [self setBackgroundColor:self.systemTabBar.barTintColor];
    for (TLTabBarItem *item in self.tabBarItems) {
        [item setTintColor:self.systemTabBar.tintColor];
        if (self.systemTabBar.unselectedItemTintColor) {
            [item setTitleColor:self.systemTabBar.unselectedItemTintColor forState:UIControlStateNormal];
        }
        else {
            [item setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
        }
    }
    [self p_resetTabBarItemFrames];
}

- (void)p_resetTabBarItemFrames
{
    CGFloat width = self.frame.size.width / self.tabBarItems.count;
    CGFloat x = 0;
    for (TLTabBarItem *tabBarItem in self.tabBarItems) {
        if ([tabBarItem isKindOfClass:[TLTabBarPlusItem class]]) {
            CGFloat offset = self.frame.size.height - 10;
            CGFloat height = self.frame.size.height + offset;
            [tabBarItem setFrame:CGRectMake(x, -offset, width, height)];
        }
        else {
            [tabBarItem setFrame:CGRectMake(x + width * 0.05, 0, width * 0.9, self.frame.size.height)];
        }
        x += width;
    }
}

// 响应区域
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [super hitTest:point withEvent:event];
    if (view) {
        return view;
    }
    for (TLTabBarItem *tabBarItem in self.tabBarItems) {
        if ([tabBarItem isKindOfClass:[TLTabBarPlusItem class]]) {
            CGPoint newPoint = [tabBarItem convertPoint:point fromView:self];
            if (CGRectContainsPoint(tabBarItem.bounds, newPoint)) {
                return tabBarItem;
            }
        }
    }
    return nil;
}

@end
