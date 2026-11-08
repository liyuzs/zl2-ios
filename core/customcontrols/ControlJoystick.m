#import "ControlJoystick.h"
#import "CustomControlsUtils.h"
#import "../input/ControllerInput.h"
#import "../UIKit+hook.h"
#import "../utils.h"
#include "../glfw_keycodes.h"

// Left thumbstick directions
#define DIRECTION_EAST 0
#define DIRECTION_NORTH_EAST 1
#define DIRECTION_NORTH 2
#define DIRECTION_NORTH_WEST 3
//#define DIRECTION_WEST 4
#define DIRECTION_SOUTH_WEST 5
//#define DIRECTION_SOUTH 6
#define DIRECTION_SOUTH_EAST 7

extern BOOL leftShiftHeld;

extern CGFloat lastXValue; // lastHorizontalValue
extern CGFloat lastYValue; // lastVerticalValue

// From CustomControlsUtils
NSMutableDictionary* createButton(NSString* name, int* keycodes, NSString* dynamicX, NSString* dynamicY, CGFloat width, CGFloat height);

@interface ControlJoystick()
@property(nonatomic) UIView *background, *thumb;
@property(nonatomic) UIButton *fwdLockView;
@property(nonatomic) CGPoint mCenter;
/// 当前按下的方向键（用于算出该松开哪些）
/// 布局里配了 directionKeycodes 时才有意义，旧布局走写死的 WASD 路径
@property(nonatomic) NSMutableSet<NSNumber *> *activeDirectionKeys;
@end

@implementation ControlJoystick

+ (id)buttonWithProperties:(NSMutableDictionary *)propArray {
    ControlJoystick *instance = [super buttonWithProperties:propArray];
    instance.clipsToBounds = NO;
    instance.background = [UIView new];
    instance.thumb = [UIView new];
    instance.thumb.backgroundColor = UIColor.blackColor;
    // 方向键状态集合（配了 directionKeycodes 时用）
    instance.activeDirectionKeys = [NSMutableSet set];
    [instance addSubview:instance.background];
    [instance addSubview:instance.thumb];

    if (!isControlModifiable && [propArray[@"forwardLock"] boolValue]) {
        instance.fwdLockView = [UIButton buttonWithType:UIButtonTypeCustom];
        instance.fwdLockView.hidden = YES;
        instance.fwdLockView.imageEdgeInsets = UIEdgeInsetsMake(4, 4, 4, 4);
        instance.fwdLockView.tintColor = UIColor.whiteColor;
        instance.fwdLockView.userInteractionEnabled = NO;
        [instance addSubview:instance.fwdLockView];
    }

    return instance;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (isControlModifiable || touches.count != 1) return;
    if (touches.anyObject.view == self) {
        self.thumb.center = [touches.anyObject locationInView:self];
    }
    if (isGrabbing && self.fwdLockView) {
        self.fwdLockView.center = CGPointMake(self.mCenter.x, -self.mCenter.y);
    }
    // pass this touch through the move handler
    [self touchesMoved:touches withEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (isControlModifiable || touches.count != 1) return;
    UITouch *touch = touches.anyObject;

    //CGPoint prev = [touches.anyObject previousLocationInView:self];
    //CGPoint loc = [touches.anyObject locationInView:self];

    CGPoint center = [touches.anyObject locationInView:self];
    //self.thumb.center;
    //center.x += loc.x - prev.x;
    //center.y += loc.y - prev.y;

    CGFloat dirX = center.x - self.mCenter.x;
    CGFloat dirY = center.y - self.mCenter.y;
    CGFloat radius = sqrt(dirX*dirX + dirY*dirY);
    CGFloat maxRadius = MIN(self.mCenter.x, self.mCenter.y) - self.thumb.frame.size.width/2;
    if (radius > maxRadius) {
        center.x = dirX*maxRadius/radius + self.mCenter.x;
        center.y = dirY*maxRadius/radius + self.mCenter.y;
    }
    self.thumb.center = center;

    CGFloat deadzone = 0.35;
    if (!isGrabbing || radius >= maxRadius*deadzone) {
        [self callbackMoveX:((center.x / self.frame.size.width)*2-1) Y:((-center.y / self.frame.size.height)*2+1)];
    }

#ifdef DEBUG_JOYSTICK
    [UIView performWithoutAnimation:^{
        [self setTitle:[NSString stringWithFormat:@"rad=%f\nCX=%f\nCY=%f", radius, self.mCenter.x / radius, self.mCenter.y / radius] forState:UIControlStateNormal];
        [self layoutIfNeeded];
    }];
#endif
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (isControlModifiable) return;

    lastXValue = lastYValue = 0;
    if (isGrabbing && self.fwdLockView && CGRectContainsPoint(self.fwdLockView.frame, [touches.anyObject locationInView:self])) {
        self.fwdLockView.center = self.thumb.center;
    } else {
        self.thumb.center = self.mCenter;
        [self callbackMoveX:0 Y:0];
    }
}

- (void)callbackMoveX:(CGFloat)xValue Y:(CGFloat)yValue {
#ifdef DEBUG_JOYSTICK
    static UILabel *debugLabel;
    if (debugLabel == nil) {
        debugLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 200)];
        debugLabel.lineBreakMode = NSLineBreakByWordWrapping;
        debugLabel.numberOfLines = 0;
        debugLabel.userInteractionEnabled = NO;
        [UIWindow.mainWindow addSubview:debugLabel];
    }
#endif

    if (!isGrabbing) {
        // Update virtual mouse position
        lastXValue = xValue;
        lastYValue = yValue;
        return;
    }

    static char lastDirection = -2;
    char direction = -1;
    if (xValue != 0 && yValue != 0) {
        CGFloat degree = atan2f(yValue, xValue) * (180.0 / M_PI);
        if (degree < 0) {
            degree += 360;
        }
        direction = (int)((degree+22.5)/45.0) % 8;
#ifdef DEBUG_JOYSTICK
        debugLabel.text = [NSString stringWithFormat:@"x=%f\ny=%f\natan=%f\ndeg=%f\ndirection=%d, last=%d\npressW=%d A=%d S=%d D=%d", atan2f(yValue, xValue), xValue, yValue, degree, direction, lastDirection,
            direction >= DIRECTION_NORTH_EAST &&
            direction <= DIRECTION_NORTH_WEST,
            direction >= DIRECTION_NORTH_WEST &&
            direction <= DIRECTION_SOUTH_WEST,
            direction >= DIRECTION_SOUTH_WEST &&
            direction <= DIRECTION_SOUTH_EAST,
            direction == DIRECTION_SOUTH_EAST ||
            direction == DIRECTION_EAST ||
            direction == DIRECTION_NORTH_EAST];
#endif
    }
    if (lastDirection == direction) {
        return;
    }

    // Update direction key states
    //
    // ZL2-iOS: 原来这里把 W/A/S/D 写死，忽略了布局文件里的 directionEvents。
    // 现在从 self.properties[@"directionKeycodes"] 读：
    //   8 个方向 × 4 个键位 = 32 个整数
    //   索引 = direction * 4 + slot
    // 没配的方向键位是 0，跳过不发送。
    //
    // 兜底：布局里没这个字段（旧布局）时，保持原来的 WASD 行为。
    int mod = leftShiftHeld ? GLFW_MOD_SHIFT : 0;
    NSArray *dirKeys = self.properties[@"directionKeycodes"];

    if (dirKeys != nil && dirKeys.count >= 32) {
        // 新路径：按配置发送
        // 先收集「本帧应该按下的键」，再把「上一帧按下但本帧不该按的」松开
        NSMutableSet *shouldBeDown = [NSMutableSet set];
        if (direction >= 0) {
            int base = direction * 4;
            for (int slot = 0; slot < 4; slot++) {
                int kc = [dirKeys[base + slot] intValue];
                if (kc > 0) [shouldBeDown addObject:@(kc)];
            }
        }

        // 松开不再需要的
        for (NSNumber *n in self.activeDirectionKeys) {
            if (![shouldBeDown containsObject:n]) {
                CallbackBridge_nativeSendKey([n intValue], 0, 0, mod);
            }
        }
        // 按下新需要的
        for (NSNumber *n in shouldBeDown) {
            if (![self.activeDirectionKeys containsObject:n]) {
                CallbackBridge_nativeSendKey([n intValue], 0, 1, mod);
            }
        }
        self.activeDirectionKeys = shouldBeDown;
    } else {
        // 旧路径：写死的 WASD
        CallbackBridge_nativeSendKey(GLFW_KEY_W, 0,
            direction >= DIRECTION_NORTH_EAST &&
            direction <= DIRECTION_NORTH_WEST,
            mod);
        CallbackBridge_nativeSendKey(GLFW_KEY_A, 0,
            direction >= DIRECTION_NORTH_WEST &&
            direction <= DIRECTION_SOUTH_WEST,
            mod);
        CallbackBridge_nativeSendKey(GLFW_KEY_S, 0,
            direction >= DIRECTION_SOUTH_WEST &&
            direction <= DIRECTION_SOUTH_EAST,
            mod);
        CallbackBridge_nativeSendKey(GLFW_KEY_D, 0,
            direction == DIRECTION_SOUTH_EAST ||
            direction == DIRECTION_EAST ||
            direction == DIRECTION_NORTH_EAST,
            mod);
    }

    self.fwdLockView.hidden = direction != DIRECTION_NORTH;
    lastDirection = direction;
}

- (void)setFrame:(CGRect)frame {
    // Keep the frame square
    if (self.frame.size.width != frame.size.width) {
        frame.size.height = frame.size.width;
    } else if (self.frame.size.height != frame.size.height) {
        frame.size.width = frame.size.height;
    }
    
    [super setFrame:frame];
    self.mCenter = CGPointMake(frame.size.width/2, frame.size.height/2);
    CGFloat minSize = MIN(frame.size.width, frame.size.height);

    self.fwdLockView.frame = CGRectMake(0, 0, minSize/4, minSize/4);
    [self.fwdLockView setImage:[UIImage systemImageNamed:@"lock"] forState:UIControlStateNormal];
    self.fwdLockView.layer.cornerRadius = self.fwdLockView.frame.size.width/2;

    self.thumb.frame = CGRectMake(0, 0, minSize/4, minSize/4);
    self.thumb.center = self.mCenter;
    self.thumb.layer.cornerRadius = self.thumb.frame.size.width/2;

    CGFloat bgSize = minSize - self.thumb.frame.size.width + self.background.layer.borderWidth/2;
    self.background.frame = CGRectMake(0, 0, bgSize, bgSize);
    self.background.layer.cornerRadius = bgSize/2;
    self.background.center = self.mCenter;
}

- (void)update {
    NSAssert(self.superview != nil, @"should not be nil");

    self.displayInGame = [self.properties[@"displayInGame"] boolValue];
    self.displayInMenu = [self.properties[@"displayInMenu"] boolValue];

    // net/kdt/pojavlaunch/customcontrols/ControlData.update()
    [self preProcessProperties];

    NSString *propDynamicX = (NSString *) self.properties[@"dynamicX"];
    NSString *propDynamicY = (NSString *) self.properties[@"dynamicY"];

    CGFloat propW = [self.properties[@"width"] floatValue];
    CGFloat propH = [self.properties[@"height"] floatValue];
    float propStrokeWidth = [self.properties[@"strokeWidth"] floatValue];
    int propBackgroundColor = [self.properties[@"bgColor"] intValue];
    int propStrokeColor = [self.properties[@"strokeColor"] intValue];

    self.background.backgroundColor = self.fwdLockView.backgroundColor = convertARGB2UIColor(propBackgroundColor);
    self.background.layer.borderColor = [convertARGB2UIColor(propStrokeColor) CGColor];
    self.background.layer.borderWidth = propStrokeWidth + 1;

    // Calculate dynamic position
    CGFloat propX = [self calculateDynamicPos:propDynamicX];
    CGFloat propY = [self calculateDynamicPos:propDynamicY];

    // Update other properties
    self.frame = CGRectMake(propX, propY, propW, propH);
    self.alpha = [self.properties[@"opacity"] floatValue];
    self.alpha = MAX(self.alpha, isControlModifiable ? 0.1 : 0.01);
    self.layer.cornerRadius = MIN(self.frame.size.width, self.frame.size.height) / 2.0;
}

@end
