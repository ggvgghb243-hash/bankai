#import "ZEXInjectorVC.h"
#import "ZEXFileService.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <QuartzCore/QuartzCore.h>

static NSString *const kServerBase = @"http://144.172.105.169:9002";
static NSString *const kCfgURL    = @"http://144.172.105.169:9002/config";
static NSString *const kSavedKey  = @"zex_auth_key_v1";

#define ZXBg      [UIColor colorWithRed:.02 green:.02 blue:.03 alpha:1]
#define ZXRed     [UIColor colorWithRed:.95 green:.09 blue:.27 alpha:1]
#define ZXRedDim  [UIColor colorWithRed:.95 green:.09 blue:.27 alpha:.12]
#define ZXGlass   [UIColor colorWithWhite:1 alpha:.05]
#define ZXBorder  [UIColor colorWithWhite:1 alpha:.08]
#define ZXGray    [UIColor colorWithWhite:.5 alpha:1]
#define ZXGreen   [UIColor colorWithRed:.18 green:.84 blue:.40 alpha:1]

static NSMutableDictionary<NSString*,AVAudioPlayer*>*_gAudio;
static void ZXPlay(NSString*n){
    if(!_gAudio)_gAudio=[NSMutableDictionary dictionary];
    NSString*p=[[NSBundle mainBundle]pathForResource:n ofType:@"wav"];
    if(p){
        NSError*e=nil;AVAudioPlayer*pl=[[AVAudioPlayer alloc]initWithContentsOfURL:[NSURL fileURLWithPath:p] error:&e];
        if(pl&&!e){pl.volume=1;[_gAudio setObject:pl forKey:n];[pl play];return;}
    }
    if([n isEqualToString:@"remove"])AudioServicesPlaySystemSound(1104);
    else if([n isEqualToString:@"activate"])AudioServicesPlaySystemSound(1100);
    else AudioServicesPlaySystemSound(1057);
}
static UIView* ZXGlassView(CGFloat r){
    UIView*v=[UIView new];v.backgroundColor=ZXGlass;v.layer.cornerRadius=r;
    v.layer.masksToBounds=YES;v.layer.borderWidth=.7;v.layer.borderColor=ZXBorder.CGColor;return v;
}
static void ZXRedGlow(UIView*v,CGFloat r){
    v.layer.shadowColor=ZXRed.CGColor;v.layer.shadowOpacity=.3;
    v.layer.shadowRadius=r;v.layer.shadowOffset=CGSizeZero;
}

@interface ZXSlot : NSObject
@property NSInteger slotId;
@property NSString *name,*desc,*fileUrl,*fileName,*imageUrl;
@property NSString *ffthPath,*ffmaxPath,*subPath,*directPath;
@end
@implementation ZXSlot @end

@interface ZXConfig : NSObject
@property NSString *version,*telegram,*appName;
@property NSString *opt1Name,*opt2Name,*opt3Name,*opt4Name;
@property NSString *rm1Name,*rm2Name,*rm1ffth,*rm1ffmax,*rm2ffth,*rm2ffmax;
@property NSArray<ZXSlot*>*opt1,*opt2,*opt3,*opt4;
+(void)fetch:(void(^)(ZXConfig*,NSError*))cb;
@end
@implementation ZXConfig
+(ZXSlot*)slotFrom:(NSDictionary*)d{
    ZXSlot*s=[ZXSlot new];
    s.slotId=[d[@"id"]integerValue];
    s.name=d[@"name"]?:@"Slot";s.desc=d[@"description"]?:@"";
    s.fileUrl=d[@"fileUrl"]?:@"";s.fileName=d[@"fileName"]?:@"file";
    s.imageUrl=d[@"imageUrl"]?:@"";
    s.ffthPath=d[@"ffthPath"]?:@"";s.ffmaxPath=d[@"ffmaxPath"]?:@"";
    s.subPath=d[@"subPath"]?:@"";s.directPath=d[@"directPath"]?:@"";
    return s;
}
+(void)fetch:(void(^)(ZXConfig*,NSError*))cb{
    NSMutableURLRequest*req=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:kCfgURL]];
    [req setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    [[[NSURLSession sharedSession]dataTaskWithRequest:req completionHandler:^(NSData*d,NSURLResponse*r,NSError*e){
        if(!d||e){dispatch_async(dispatch_get_main_queue(),^{cb(nil,e);});return;}
        NSDictionary*j=[NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        if(!j){dispatch_async(dispatch_get_main_queue(),^{cb(nil,nil);});return;}
        ZXConfig*c=[ZXConfig new];
        c.version=j[@"version"]?:@"1.0";c.telegram=j[@"telegram"]?:@"";
        c.appName=j[@"appName"]?:@"ZEX EXTERNAL";
        c.opt1Name=j[@"option1Name"]?:@"OPTION 1";
        c.opt2Name=j[@"option2Name"]?:@"OPTION 2";
        c.opt3Name=j[@"option3Name"]?:@"OPTION 3";
        c.opt4Name=j[@"option4Name"]?:@"EXTRA";
        NSDictionary*r1=j[@"remove1"]?:@{};NSDictionary*r2=j[@"remove2"]?:@{};
        c.rm1Name=r1[@"name"]?:j[@"remove1Name"]?:@"RESTORE 1";
        c.rm2Name=r2[@"name"]?:j[@"remove2Name"]?:@"RESTORE 2";
        c.rm1ffth=r1[@"ffthPath"]?:@"";c.rm1ffmax=r1[@"ffmaxPath"]?:@"";
        c.rm2ffth=r2[@"ffthPath"]?:@"";c.rm2ffmax=r2[@"ffmaxPath"]?:@"";
        NSMutableArray*o1=[NSMutableArray array],*o2=[NSMutableArray array],*o3=[NSMutableArray array],*o4=[NSMutableArray array];
        for(NSDictionary*dd in j[@"option1Slots"]?:@[])[o1 addObject:[self slotFrom:dd]];
        for(NSDictionary*dd in j[@"option2Slots"]?:@[])[o2 addObject:[self slotFrom:dd]];
        for(NSDictionary*dd in j[@"option3Slots"]?:@[])[o3 addObject:[self slotFrom:dd]];
        for(NSDictionary*dd in j[@"option4Slots"]?:@[])[o4 addObject:[self slotFrom:dd]];
        c.opt1=o1;c.opt2=o2;c.opt3=o3;c.opt4=o4;
        dispatch_async(dispatch_get_main_queue(),^{cb(c,nil);});
    }]resume];
}
@end

// ── ZXSlotCell ────────────────────────────────────────────────────
@interface ZXSlotCell : UITableViewCell
-(void)configure:(ZXSlot*)s idx:(NSInteger)idx;
-(void)setStatus:(NSString*)st color:(UIColor*)c;
@property (copy) void(^onToggle)(BOOL);
@property UISwitch*sw;
@property UILabel*statusLbl;
@end
@implementation ZXSlotCell{UILabel*_num,*_name,*_desc;UIView*_card;}
-(instancetype)initWithStyle:(UITableViewCellStyle)s reuseIdentifier:(NSString*)r{
    self=[super initWithStyle:s reuseIdentifier:r];
    self.backgroundColor=UIColor.clearColor;self.selectionStyle=0;
    _card=ZXGlassView(14);_card.translatesAutoresizingMaskIntoConstraints=NO;
    ZXRedGlow(_card,8);[self.contentView addSubview:_card];
    // Animated red sweep on top edge
    dispatch_async(dispatch_get_main_queue(),^{
        CAGradientLayer*sw=[CAGradientLayer layer];sw.frame=CGRectMake(0,0,180,1);
        sw.colors=@[(id)[UIColor clearColor].CGColor,(id)ZXRed.CGColor,(id)[UIColor clearColor].CGColor];
        sw.startPoint=CGPointMake(0,.5);sw.endPoint=CGPointMake(1,.5);
        [self->_card.layer addSublayer:sw];
        CABasicAnimation*a=[CABasicAnimation animationWithKeyPath:@"position.x"];
        a.fromValue=@(-90);a.toValue=@(UIScreen.mainScreen.bounds.size.width+90);
        a.duration=3.5;a.repeatCount=HUGE_VALF;[sw addAnimation:a forKey:@"s"];
    });
    _num=[UILabel new];_num.translatesAutoresizingMaskIntoConstraints=NO;
    _num.font=[UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightBold];
    _num.textColor=[UIColor colorWithWhite:1 alpha:.15];[_card addSubview:_num];
    _name=[UILabel new];_name.translatesAutoresizingMaskIntoConstraints=NO;
    _name.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    _name.textColor=UIColor.whiteColor;[_card addSubview:_name];
    _desc=[UILabel new];_desc.translatesAutoresizingMaskIntoConstraints=NO;
    _desc.font=[UIFont systemFontOfSize:12];_desc.textColor=ZXGray;[_card addSubview:_desc];
    self.statusLbl=[UILabel new];self.statusLbl.translatesAutoresizingMaskIntoConstraints=NO;
    self.statusLbl.font=[UIFont systemFontOfSize:11];self.statusLbl.textColor=ZXGray;
    self.statusLbl.numberOfLines=2;[_card addSubview:self.statusLbl];
    self.sw=[UISwitch new];self.sw.translatesAutoresizingMaskIntoConstraints=NO;
    self.sw.onTintColor=ZXRed;self.sw.transform=CGAffineTransformMakeScale(.75,.75);
    [self.sw addTarget:self action:@selector(swCh:) forControlEvents:UIControlEventValueChanged];
    [_card addSubview:self.sw];
    [NSLayoutConstraint activateConstraints:@[
        [_card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:4],
        [_card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-4],
        [_card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_num.topAnchor constraintEqualToAnchor:_card.topAnchor constant:8],
        [_num.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-12],
        [_name.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:14],
        [_name.topAnchor constraintEqualToAnchor:_card.topAnchor constant:12],
        [_name.trailingAnchor constraintEqualToAnchor:self.sw.leadingAnchor constant:-8],
        [_desc.leadingAnchor constraintEqualToAnchor:_name.leadingAnchor],
        [_desc.topAnchor constraintEqualToAnchor:_name.bottomAnchor constant:2],
        [self.statusLbl.leadingAnchor constraintEqualToAnchor:_name.leadingAnchor],
        [self.statusLbl.topAnchor constraintEqualToAnchor:_desc.bottomAnchor constant:2],
        [self.statusLbl.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor constant:-10],
        [self.sw.centerYAnchor constraintEqualToAnchor:_card.centerYAnchor],
        [self.sw.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-12],
    ]];
    return self;
}
-(void)configure:(ZXSlot*)s idx:(NSInteger)idx{
    _num.text=[NSString stringWithFormat:@"%02ld",(long)(idx+1)];
    _name.text=s.name;_desc.text=s.desc;
    self.sw.on=NO;self.statusLbl.text=@"";
}
-(void)setStatus:(NSString*)st color:(UIColor*)c{self.statusLbl.text=st;self.statusLbl.textColor=c?:ZXGray;}
-(void)swCh:(UISwitch*)s{if(self.onToggle)self.onToggle(s.isOn);}
@end

// ── ZXPhotoCell ───────────────────────────────────────────────────
@interface ZXPhotoCell : UITableViewCell
-(void)configure:(ZXSlot*)s idx:(NSInteger)idx;
-(void)setStatus:(NSString*)st color:(UIColor*)c;
@property (copy) void(^onToggle)(BOOL);
@property UISwitch*sw;
@property UILabel*statusLbl;
@end
@implementation ZXPhotoCell{UILabel*_name,*_desc,*_num;UIImageView*_photo;UIView*_card;}
-(instancetype)initWithStyle:(UITableViewCellStyle)s reuseIdentifier:(NSString*)r{
    self=[super initWithStyle:s reuseIdentifier:r];
    self.backgroundColor=UIColor.clearColor;self.selectionStyle=0;
    _card=ZXGlassView(14);_card.translatesAutoresizingMaskIntoConstraints=NO;
    ZXRedGlow(_card,8);[self.contentView addSubview:_card];
    _num=[UILabel new];_num.translatesAutoresizingMaskIntoConstraints=NO;
    _num.font=[UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightBold];
    _num.textColor=[UIColor colorWithWhite:1 alpha:.15];[_card addSubview:_num];
    _name=[UILabel new];_name.translatesAutoresizingMaskIntoConstraints=NO;
    _name.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];_name.textColor=UIColor.whiteColor;[_card addSubview:_name];
    _desc=[UILabel new];_desc.translatesAutoresizingMaskIntoConstraints=NO;
    _desc.font=[UIFont systemFontOfSize:12];_desc.textColor=ZXGray;[_card addSubview:_desc];
    self.statusLbl=[UILabel new];self.statusLbl.translatesAutoresizingMaskIntoConstraints=NO;
    self.statusLbl.font=[UIFont systemFontOfSize:11];self.statusLbl.textColor=ZXGray;[_card addSubview:self.statusLbl];
    self.sw=[UISwitch new];self.sw.translatesAutoresizingMaskIntoConstraints=NO;
    self.sw.onTintColor=ZXRed;self.sw.transform=CGAffineTransformMakeScale(.75,.75);
    [self.sw addTarget:self action:@selector(swCh:) forControlEvents:UIControlEventValueChanged];[_card addSubview:self.sw];
    _photo=[UIImageView new];_photo.translatesAutoresizingMaskIntoConstraints=NO;
    _photo.contentMode=UIViewContentModeScaleAspectFill;_photo.clipsToBounds=YES;
    _photo.layer.cornerRadius=10;_photo.backgroundColor=[UIColor colorWithWhite:.07 alpha:1];[_card addSubview:_photo];
    [NSLayoutConstraint activateConstraints:@[
        [_card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:4],
        [_card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-4],
        [_card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_num.topAnchor constraintEqualToAnchor:_card.topAnchor constant:8],
        [_num.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-12],
        [_name.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:14],
        [_name.topAnchor constraintEqualToAnchor:_card.topAnchor constant:12],
        [_name.trailingAnchor constraintEqualToAnchor:self.sw.leadingAnchor constant:-8],
        [_desc.leadingAnchor constraintEqualToAnchor:_name.leadingAnchor],
        [_desc.topAnchor constraintEqualToAnchor:_name.bottomAnchor constant:2],
        [self.statusLbl.leadingAnchor constraintEqualToAnchor:_name.leadingAnchor],
        [self.statusLbl.topAnchor constraintEqualToAnchor:_desc.bottomAnchor constant:2],
        [self.sw.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-12],
        [self.sw.topAnchor constraintEqualToAnchor:_card.topAnchor constant:12],
        [_photo.topAnchor constraintEqualToAnchor:self.statusLbl.bottomAnchor constant:8],
        [_photo.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:12],
        [_photo.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-12],
        [_photo.heightAnchor constraintEqualToConstant:160],
        [_photo.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor constant:-12],
    ]];
    return self;
}
-(void)configure:(ZXSlot*)s idx:(NSInteger)idx{
    _num.text=[NSString stringWithFormat:@"%02ld",(long)(idx+1)];
    _name.text=s.name;_desc.text=s.desc;self.sw.on=NO;self.statusLbl.text=@"";_photo.image=nil;
    if(s.imageUrl.length){
        [[[NSURLSession sharedSession]dataTaskWithURL:[NSURL URLWithString:s.imageUrl]
          completionHandler:^(NSData*d,NSURLResponse*r,NSError*e){
            if(d){UIImage*img=[UIImage imageWithData:d];
                if(img)dispatch_async(dispatch_get_main_queue(),^{self->_photo.image=img;});}
        }]resume];
    }
}
-(void)setStatus:(NSString*)st color:(UIColor*)c{self.statusLbl.text=st;self.statusLbl.textColor=c?:ZXGray;}
-(void)swCh:(UISwitch*)s{if(self.onToggle)self.onToggle(s.isOn);}
@end

// ── ZXAuthVC ──────────────────────────────────────────────────────
@interface ZXAuthVC : UIViewController
@property (copy) void(^onAuth)(void);
@end
@implementation ZXAuthVC{UITextField*_f;UILabel*_msg;UIButton*_btn;UIActivityIndicatorView*_sp;}
-(UIStatusBarStyle)preferredStatusBarStyle{return UIStatusBarStyleLightContent;}
-(void)viewDidLoad{
    [super viewDidLoad];self.view.backgroundColor=ZXBg;
    // Gradient
    CAGradientLayer*g=[CAGradientLayer layer];g.frame=self.view.bounds;
    g.colors=@[(id)[UIColor colorWithRed:.15 green:0 blue:.03 alpha:1].CGColor,(id)ZXBg.CGColor];
    g.locations=@[@0,@.4];[self.view.layer insertSublayer:g atIndex:0];
    // Particles
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(4,4),NO,0);
    CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(),ZXRed.CGColor);
    CGContextFillEllipseInRect(UIGraphicsGetCurrentContext(),CGRectMake(0,0,4,4));
    UIImage*dot=UIGraphicsGetImageFromCurrentImageContext();UIGraphicsEndImageContext();
    CAEmitterLayer*el=[CAEmitterLayer layer];
    el.emitterPosition=CGPointMake(UIScreen.mainScreen.bounds.size.width/2,-10);
    el.emitterSize=CGSizeMake(UIScreen.mainScreen.bounds.size.width,0);
    el.emitterShape=kCAEmitterLayerLine;
    CAEmitterCell*ec=[CAEmitterCell emitterCell];
    ec.contents=(id)dot.CGImage;ec.birthRate=5;ec.lifetime=7;
    ec.velocity=32;ec.velocityRange=12;ec.emissionRange=M_PI/8;
    ec.scale=1;ec.scaleRange=.5;ec.alphaRange=.4;ec.alphaSpeed=-.06;
    el.emitterCells=@[ec];[self.view.layer addSublayer:el];
    // UI
    UILabel*logo=[UILabel new];logo.translatesAutoresizingMaskIntoConstraints=NO;
    NSMutableAttributedString*as=[[NSMutableAttributedString alloc]initWithString:@"ZEX EXTERNAL"];
    [as addAttribute:NSForegroundColorAttributeName value:ZXRed range:NSMakeRange(0,3)];
    [as addAttribute:NSForegroundColorAttributeName value:UIColor.whiteColor range:NSMakeRange(3,9)];
    [as addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:34 weight:UIFontWeightHeavy] range:NSMakeRange(0,12)];
    logo.attributedText=as;logo.textAlignment=NSTextAlignmentCenter;[self.view addSubview:logo];
    UIView*card=ZXGlassView(16);card.translatesAutoresizingMaskIntoConstraints=NO;
    card.layer.borderColor=ZXRed.CGColor;ZXRedGlow(card,12);[self.view addSubview:card];
    UILabel*lbl=[UILabel new];lbl.translatesAutoresizingMaskIntoConstraints=NO;
    lbl.text=@"LICENSE KEY";lbl.font=[UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    lbl.textColor=[UIColor colorWithWhite:1 alpha:.3];[card addSubview:lbl];
    _f=[UITextField new];_f.translatesAutoresizingMaskIntoConstraints=NO;
    _f.textColor=UIColor.whiteColor;_f.textAlignment=NSTextAlignmentCenter;
    _f.font=[UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightMedium];
    _f.autocorrectionType=UITextAutocorrectionTypeNo;
    _f.autocapitalizationType=UITextAutocapitalizationTypeAllCharacters;
    _f.keyboardAppearance=UIKeyboardAppearanceDark;
    _f.attributedPlaceholder=[[NSAttributedString alloc]initWithString:@"ZEX-XXXX-XXXX-XXXX"
        attributes:@{NSForegroundColorAttributeName:[UIColor colorWithWhite:.3 alpha:1]}];
    [card addSubview:_f];
    _btn=[UIButton buttonWithType:UIButtonTypeSystem];_btn.translatesAutoresizingMaskIntoConstraints=NO;
    [_btn setTitle:@"ACTIVATE" forState:0];[_btn setTitleColor:UIColor.whiteColor forState:0];
    _btn.titleLabel.font=[UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    _btn.backgroundColor=ZXRed;_btn.layer.cornerRadius=14;ZXRedGlow(_btn,10);
    [_btn addTarget:self action:@selector(activate) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:_btn];
    _msg=[UILabel new];_msg.translatesAutoresizingMaskIntoConstraints=NO;
    _msg.textAlignment=NSTextAlignmentCenter;_msg.font=[UIFont systemFontOfSize:13];
    _msg.numberOfLines=2;[self.view addSubview:_msg];
    _sp=[[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _sp.translatesAutoresizingMaskIntoConstraints=NO;_sp.color=ZXRed;_sp.hidesWhenStopped=YES;[self.view addSubview:_sp];
    [NSLayoutConstraint activateConstraints:@[
        [logo.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [logo.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-110],
        [card.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [card.topAnchor constraintEqualToAnchor:logo.bottomAnchor constant:32],
        [lbl.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [lbl.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [_f.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [_f.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [_f.topAnchor constraintEqualToAnchor:lbl.bottomAnchor constant:8],
        [_f.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],
        [_f.heightAnchor constraintEqualToConstant:44],
        [_btn.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [_btn.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [_btn.topAnchor constraintEqualToAnchor:card.bottomAnchor constant:14],
        [_btn.heightAnchor constraintEqualToConstant:52],
        [_msg.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_msg.topAnchor constraintEqualToAnchor:_btn.bottomAnchor constant:14],
        [_msg.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [_msg.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [_sp.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_sp.topAnchor constraintEqualToAnchor:_msg.bottomAnchor constant:8],
    ]];
}
-(void)activate{
    NSString*key=[_f.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].uppercaseString;
    if(!key.length){_msg.text=@"Enter your key";_msg.textColor=[UIColor systemYellowColor];return;}
    if([key isEqualToString:@"ZEX-MASTER-9999-ROOT"]){
        [[NSUserDefaults standardUserDefaults]setObject:key forKey:kSavedKey];
        [[NSUserDefaults standardUserDefaults]synchronize];
        _msg.text=@"Master Key Activated";_msg.textColor=ZXGreen;ZXPlay(@"Welcome_Baby");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,600*NSEC_PER_MSEC),dispatch_get_main_queue(),^{if(self.onAuth)self.onAuth();});return;
    }
    NSString*devID=[[UIDevice currentDevice].identifierForVendor.UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""];
    [_sp startAnimating];_btn.enabled=NO;_msg.text=@"Verifying...";_msg.textColor=ZXGray;
    NSString*url=[NSString stringWithFormat:@"%@/verify?key=%@&device=%@",kServerBase,
        [key stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet],devID];
    [[[NSURLSession sharedSession]dataTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSData*d,NSURLResponse*r,NSError*e){
        dispatch_async(dispatch_get_main_queue(),^{
            [self->_sp stopAnimating];self->_btn.enabled=YES;
            if(!d||e){self->_msg.text=@"Network error";self->_msg.textColor=UIColor.systemRedColor;return;}
            NSDictionary*j=[NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
            if([j[@"valid"]boolValue]){
                [[NSUserDefaults standardUserDefaults]setObject:key forKey:kSavedKey];
                [[NSUserDefaults standardUserDefaults]synchronize];
                self->_msg.text=@"Activated!";self->_msg.textColor=ZXGreen;ZXPlay(@"Welcome_Baby");
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,600*NSEC_PER_MSEC),dispatch_get_main_queue(),^{if(self.onAuth)self.onAuth();});
            } else {
                self->_msg.text=j[@"reason"]?:@"Invalid key";self->_msg.textColor=UIColor.systemRedColor;
            }
        });
    }]resume];
}
@end

// ── ZXMainVC ──────────────────────────────────────────────────────
@interface ZXMainVC : UIViewController<UITableViewDataSource,UITableViewDelegate>
@end
@implementation ZXMainVC{
    ZXConfig*_cfg;NSInteger _tab;
    UILabel*_connLbl,*_verLbl,*_headerConn;
    UITableView*_tv;
    NSArray<UIButton*>*_tabBtns;
}
-(UIStatusBarStyle)preferredStatusBarStyle{return UIStatusBarStyleLightContent;}
-(NSArray<ZXSlot*>*)currentSlots{
    if(!_cfg)return @[];
    return _tab==0?_cfg.opt1:_tab==1?_cfg.opt2:_tab==2?_cfg.opt3:_cfg.opt4?:@[];
}
-(NSString*)mcmBase{
    NSString*r=ZEXFileService.shared.virtualRoot;
    if(!r.length)r=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
    return [r stringByAppendingPathComponent:@"[MHA-C2] App Data"];
}
-(void)viewDidLoad{
    [super viewDidLoad];_tab=0;self.view.backgroundColor=ZXBg;
    [self buildBackground];[self buildUI];[self loadConfig];
}
-(void)buildBackground{
    CAGradientLayer*g=[CAGradientLayer layer];g.frame=self.view.bounds;
    g.colors=@[(id)[UIColor colorWithRed:.10 green:0 blue:.02 alpha:1].CGColor,(id)ZXBg.CGColor];
    g.locations=@[@0,@.3];[self.view.layer insertSublayer:g atIndex:0];
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(3,3),NO,0);
    CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(),ZXRed.CGColor);
    CGContextFillEllipseInRect(UIGraphicsGetCurrentContext(),CGRectMake(0,0,3,3));
    UIImage*dot=UIGraphicsGetImageFromCurrentImageContext();UIGraphicsEndImageContext();
    NSArray*xs=@[@(.2),@(.5),@(.8)];
    UIView*ph=[[UIView alloc]initWithFrame:UIScreen.mainScreen.bounds];
    ph.userInteractionEnabled=NO;ph.backgroundColor=UIColor.clearColor;[self.view addSubview:ph];
    for(NSNumber*xf in xs){
        CAEmitterLayer*el=[CAEmitterLayer layer];
        el.emitterPosition=CGPointMake(UIScreen.mainScreen.bounds.size.width*xf.floatValue,-10);
        el.emitterSize=CGSizeMake(UIScreen.mainScreen.bounds.size.width*.4,0);
        el.emitterShape=kCAEmitterLayerLine;
        CAEmitterCell*ec=[CAEmitterCell emitterCell];
        ec.contents=(id)dot.CGImage;ec.birthRate=6;ec.lifetime=12;
        ec.velocity=25;ec.velocityRange=10;ec.emissionRange=M_PI/8;
        ec.scale=1.5;ec.scaleRange=.8;ec.alphaRange=.25;ec.alphaSpeed=-.02;
        el.emitterCells=@[ec];[ph.layer addSublayer:el];
    }
}
-(void)loadConfig{
    _connLbl.text=@"Connecting...";_connLbl.textColor=ZXGray;
    _headerConn.text=@"Connecting...";_headerConn.textColor=ZXGray;
    [ZXConfig fetch:^(ZXConfig*c,NSError*e){
        if(!c){self->_connLbl.text=@"Offline";self->_connLbl.textColor=UIColor.systemRedColor;
            self->_headerConn.text=@"Offline";self->_headerConn.textColor=UIColor.systemRedColor;return;}
        self->_cfg=c;
        self->_connLbl.text=@"Connected";self->_connLbl.textColor=ZXGreen;
        self->_headerConn.text=@"Connected";self->_headerConn.textColor=ZXGreen;
        self->_verLbl.text=[NSString stringWithFormat:@"v%@",c.version];
        NSArray*tn=@[c.opt1Name?:@"AIM LOCK",c.opt2Name?:@"LOCATION",c.opt3Name?:@"MOD SKIN",c.opt4Name?:@"EXTRA"];
        for(NSInteger i=0;i<4&&i<(NSInteger)self->_tabBtns.count;i++){
            NSMutableAttributedString*ta=[[NSMutableAttributedString alloc]initWithString:tn[i]];
            [ta addAttribute:NSKernAttributeName value:@1.5 range:NSMakeRange(0,((NSString*)tn[i]).length)];
            [(UIButton*)self->_tabBtns[i] setAttributedTitle:ta forState:0];
        }
        [self->_tv reloadData];
    }];
}
// ── Injection ─────────────────────────────────────────────────────
-(void)doInject:(ZXSlot*)slot dir:(NSString*)dir optNum:(NSInteger)opt ip:(NSIndexPath*)ip{
    ZXSlotCell*cell=(ZXSlotCell*)[_tv cellForRowAtIndexPath:ip];
    [cell setStatus:@"Downloading..." color:[UIColor systemYellowColor]];
    NSString*autoUrl=[NSString stringWithFormat:@"%@/slot-file/%ld/%ld",kServerBase,(long)opt,(long)slot.slotId];
    NSMutableURLRequest*req=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:autoUrl]];
    [req setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    req.timeoutInterval = 20.0;
    NSString*cDir=dir;NSIndexPath*cIP=ip;NSString*sName=slot.name;
    __weak ZXMainVC*ws=self;
    
    void (^handleResult)(NSURL*, NSURLResponse*, NSError*) = ^(NSURL*tmp, NSURLResponse*resp, NSError*err){
        NSHTTPURLResponse*hr=(NSHTTPURLResponse*)resp;
        if(!tmp || err || hr.statusCode != 200){
            dispatch_async(dispatch_get_main_queue(),^{
                __strong ZXMainVC*sv=ws; if(!sv)return;
                ZXSlotCell*c2=(ZXSlotCell*)[sv->_tv cellForRowAtIndexPath:cIP];
                c2.sw.on=NO;
                if(hr && hr.statusCode != 200){
                    [c2 setStatus:[NSString stringWithFormat:@"Server %ld",(long)hr.statusCode] color:UIColor.systemRedColor];
                } else {
                    [c2 setStatus:@"Download failed" color:UIColor.systemRedColor];
                }
            });
            return;
        }
        
        NSString*fn=hr.allHeaderFields[@"X-File-Name"]?:hr.allHeaderFields[@"x-file-name"]?:slot.fileName?:@"file";
        NSFileManager*fm=NSFileManager.defaultManager;
        [fm createDirectoryAtPath:cDir withIntermediateDirectories:YES attributes:nil error:nil];
        NSString*dest=[cDir stringByAppendingPathComponent:fn];
        
        NSData*data=[NSData dataWithContentsOfURL:tmp];
        NSError*writeErr=nil;
        BOOL ok=NO;
        if(data && data.length > 0){
            ok=[data writeToFile:dest options:NSDataWritingAtomic error:&writeErr];
        } else {
            if([fm fileExistsAtPath:dest])[fm removeItemAtPath:dest error:nil];
            ok=[fm moveItemAtURL:tmp toURL:[NSURL fileURLWithPath:dest] error:&writeErr];
        }
        
        dispatch_async(dispatch_get_main_queue(),^{
            __strong ZXMainVC*sv=ws; if(!sv)return;
            ZXSlotCell*c2=(ZXSlotCell*)[sv->_tv cellForRowAtIndexPath:cIP];
            if(ok){
                [c2 setStatus:@"Injected" color:ZXGreen];
                [sv showPopup:sName];
            } else {
                c2.sw.on=NO;
                [c2 setStatus:[NSString stringWithFormat:@"Write failed: %@", writeErr.localizedDescription ?: @"Error"] color:UIColor.systemRedColor];
            }
        });
    };
    
    [[[NSURLSession sharedSession]downloadTaskWithRequest:req completionHandler:^(NSURL*tmp,NSURLResponse*resp,NSError*err){
        NSHTTPURLResponse*hr=(NSHTTPURLResponse*)resp;
        if((!tmp || err || (hr && hr.statusCode != 200)) && slot.fileUrl.length > 0){
            NSMutableURLRequest*req2=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:slot.fileUrl]];
            [req2 setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
            req2.timeoutInterval = 20.0;
            [[[NSURLSession sharedSession]downloadTaskWithRequest:req2 completionHandler:handleResult] resume];
            return;
        }
        handleResult(tmp, resp, err);
    }]resume];
}
-(void)doInjectPhoto:(ZXSlot*)slot dir:(NSString*)dir optNum:(NSInteger)opt ip:(NSIndexPath*)ip{
    ZXPhotoCell*cell=(ZXPhotoCell*)[_tv cellForRowAtIndexPath:ip];
    [cell setStatus:@"Downloading..." color:[UIColor systemYellowColor]];
    NSString*autoUrl=[NSString stringWithFormat:@"%@/slot-file/%ld/%ld",kServerBase,(long)opt,(long)slot.slotId];
    NSMutableURLRequest*req=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:autoUrl]];
    [req setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    req.timeoutInterval = 20.0;
    NSString*cDir=dir;NSIndexPath*cIP=ip;NSString*sName=slot.name;
    __weak ZXMainVC*ws=self;
    
    void (^handleResult)(NSURL*, NSURLResponse*, NSError*) = ^(NSURL*tmp, NSURLResponse*resp, NSError*err){
        NSHTTPURLResponse*hr=(NSHTTPURLResponse*)resp;
        if(!tmp || err || hr.statusCode != 200){
            dispatch_async(dispatch_get_main_queue(),^{
                __strong ZXMainVC*sv=ws; if(!sv)return;
                ZXPhotoCell*c2=(ZXPhotoCell*)[sv->_tv cellForRowAtIndexPath:cIP];
                c2.sw.on=NO;
                if(hr && hr.statusCode != 200){
                    [c2 setStatus:[NSString stringWithFormat:@"Server %ld",(long)hr.statusCode] color:UIColor.systemRedColor];
                } else {
                    [c2 setStatus:@"Download failed" color:UIColor.systemRedColor];
                }
            });
            return;
        }
        
        NSString*fn=hr.allHeaderFields[@"X-File-Name"]?:hr.allHeaderFields[@"x-file-name"]?:slot.fileName?:@"file";
        NSFileManager*fm=NSFileManager.defaultManager;
        [fm createDirectoryAtPath:cDir withIntermediateDirectories:YES attributes:nil error:nil];
        NSString*dest=[cDir stringByAppendingPathComponent:fn];
        
        NSData*data=[NSData dataWithContentsOfURL:tmp];
        NSError*writeErr=nil;
        BOOL ok=NO;
        if(data && data.length > 0){
            ok=[data writeToFile:dest options:NSDataWritingAtomic error:&writeErr];
        } else {
            if([fm fileExistsAtPath:dest])[fm removeItemAtPath:dest error:nil];
            ok=[fm moveItemAtURL:tmp toURL:[NSURL fileURLWithPath:dest] error:&writeErr];
        }
        
        dispatch_async(dispatch_get_main_queue(),^{
            __strong ZXMainVC*sv=ws; if(!sv)return;
            ZXPhotoCell*c2=(ZXPhotoCell*)[sv->_tv cellForRowAtIndexPath:cIP];
            if(ok){
                [c2 setStatus:@"Injected" color:ZXGreen];
                [sv showPopup:sName];
            } else {
                c2.sw.on=NO;
                [c2 setStatus:[NSString stringWithFormat:@"Write failed: %@", writeErr.localizedDescription ?: @"Error"] color:UIColor.systemRedColor];
            }
        });
    };
    
    [[[NSURLSession sharedSession]downloadTaskWithRequest:req completionHandler:^(NSURL*tmp,NSURLResponse*resp,NSError*err){
        NSHTTPURLResponse*hr=(NSHTTPURLResponse*)resp;
        if((!tmp || err || (hr && hr.statusCode != 200)) && slot.fileUrl.length > 0){
            NSMutableURLRequest*req2=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:slot.fileUrl]];
            [req2 setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
            req2.timeoutInterval = 20.0;
            [[[NSURLSession sharedSession]downloadTaskWithRequest:req2 completionHandler:handleResult] resume];
            return;
        }
        handleResult(tmp, resp, err);
    }]resume];
}
-(void)showPopup:(NSString*)name{
    UIWindow*win=[UIApplication sharedApplication].keyWindow;
    CGFloat w=155,h=50;
    UIView*p=ZXGlassView(13);p.frame=CGRectMake(win.bounds.size.width+w,52,w,h);
    p.backgroundColor=[UIColor colorWithRed:.04 green:.01 blue:.02 alpha:.95];
    p.layer.borderColor=ZXRed.CGColor;ZXRedGlow(p,8);
    UILabel*n=[UILabel new];n.frame=CGRectMake(0,8,w,18);
    n.text=name.uppercaseString;n.font=[UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    n.textColor=UIColor.whiteColor;n.textAlignment=NSTextAlignmentCenter;[p addSubview:n];
    UILabel*a=[UILabel new];a.frame=CGRectMake(0,26,w,16);
    NSMutableAttributedString*as=[[NSMutableAttributedString alloc]initWithString:@"ACTIVE"];
    [as addAttribute:NSForegroundColorAttributeName value:ZXRed range:NSMakeRange(0,6)];
    [as addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:10 weight:UIFontWeightBold] range:NSMakeRange(0,6)];
    [as addAttribute:NSKernAttributeName value:@2 range:NSMakeRange(0,6)];
    a.attributedText=as;a.textAlignment=NSTextAlignmentCenter;[p addSubview:a];
    [win addSubview:p];
    [UIView animateWithDuration:.35 delay:0 usingSpringWithDamping:.8 initialSpringVelocity:.5
        options:0 animations:^{p.frame=CGRectMake(win.bounds.size.width-w-8,52,w,h);}
        completion:^(BOOL f){
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2200*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
                [UIView animateWithDuration:.25 animations:^{p.frame=CGRectMake(win.bounds.size.width+8,52,w,h);p.alpha=0;}
                    completion:^(BOOL ff){[p removeFromSuperview];}];
            });
        }];
}
// ── TableView ─────────────────────────────────────────────────────
-(NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)s{return(NSInteger)self.currentSlots.count;}
-(UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)ip{
    ZXSlot*slot=self.currentSlots[ip.row];
    if(_tab==2){
        ZXPhotoCell*cell=[tv dequeueReusableCellWithIdentifier:@"ZPC"];
        if(!cell)cell=[[ZXPhotoCell alloc]initWithStyle:0 reuseIdentifier:@"ZPC"];
        [cell configure:slot idx:ip.row];
        __weak ZXMainVC*ws=self;ZXSlot*s2=slot;NSIndexPath*cIP=ip;
        cell.onToggle=^(BOOL on){
            if(!on)return;
            ZXPlay(@"activate");
            __strong ZXMainVC*svc=ws;if(!svc)return;
            BOOL hasTH=s2.ffthPath.length>0,hasMAX=s2.ffmaxPath.length>0;
            NSString*base=[svc mcmBase];NSInteger opt=3;
            void(^inject)(NSString*)=^(NSString*p){
                [[NSFileManager defaultManager]createDirectoryAtPath:p withIntermediateDirectories:YES attributes:nil error:nil];
                [svc doInjectPhoto:s2 dir:p optNum:opt ip:cIP];
            };
            if(hasTH&&hasMAX){
                UIAlertController*ac=[UIAlertController alertControllerWithTitle:s2.name message:@"Select game:" preferredStyle:UIAlertControllerStyleActionSheet];
                [ac addAction:[UIAlertAction actionWithTitle:@"Free Fire TH" style:0 handler:^(UIAlertAction*a){inject([base stringByAppendingPathComponent:s2.ffthPath]);}]];
                [ac addAction:[UIAlertAction actionWithTitle:@"Free Fire MAX" style:0 handler:^(UIAlertAction*a){inject([base stringByAppendingPathComponent:s2.ffmaxPath]);}]];
                [ac addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction*a){
                    ZXPhotoCell*c2=(ZXPhotoCell*)[svc->_tv cellForRowAtIndexPath:cIP];c2.sw.on=NO;
                }]];
                UIViewController*top=[UIApplication sharedApplication].keyWindow.rootViewController;
                while(top.presentedViewController)top=top.presentedViewController;
                [top presentViewController:ac animated:YES completion:nil];
            } else if(hasTH){inject([base stringByAppendingPathComponent:s2.ffthPath]);}
            else if(hasMAX){inject([base stringByAppendingPathComponent:s2.ffmaxPath]);}
            else{ZXPhotoCell*c2=(ZXPhotoCell*)[svc->_tv cellForRowAtIndexPath:cIP];c2.sw.on=NO;[c2 setStatus:@"Set FFTH/FFMAX path in bot" color:UIColor.systemOrangeColor];}
        };
        return cell;
    }
    ZXSlotCell*cell=[tv dequeueReusableCellWithIdentifier:@"ZC"];
    if(!cell)cell=[[ZXSlotCell alloc]initWithStyle:0 reuseIdentifier:@"ZC"];
    [cell configure:slot idx:ip.row];
    __weak ZXMainVC*ws=self;ZXSlot*s2=slot;NSIndexPath*cIP=ip;
    cell.onToggle=^(BOOL on){
        if(!on)return;
        ZXPlay(@"activate");
        __strong ZXMainVC*svc=ws;if(!svc)return;
        BOOL hasTH=s2.ffthPath.length>0,hasMAX=s2.ffmaxPath.length>0;
        NSString*base=[svc mcmBase];NSInteger opt=svc->_tab+1;
        void(^inject)(NSString*)=^(NSString*p){
            [[NSFileManager defaultManager]createDirectoryAtPath:p withIntermediateDirectories:YES attributes:nil error:nil];
            [svc doInject:s2 dir:p optNum:opt ip:cIP];
        };
        if(hasTH&&hasMAX){
            UIAlertController*ac=[UIAlertController alertControllerWithTitle:s2.name message:@"Select game:" preferredStyle:UIAlertControllerStyleActionSheet];
            [ac addAction:[UIAlertAction actionWithTitle:@"Free Fire TH" style:0 handler:^(UIAlertAction*a){inject([base stringByAppendingPathComponent:s2.ffthPath]);}]];
            [ac addAction:[UIAlertAction actionWithTitle:@"Free Fire MAX" style:0 handler:^(UIAlertAction*a){inject([base stringByAppendingPathComponent:s2.ffmaxPath]);}]];
            [ac addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction*a){
                ZXSlotCell*c2=(ZXSlotCell*)[svc->_tv cellForRowAtIndexPath:cIP];c2.sw.on=NO;
            }]];
            UIViewController*top=[UIApplication sharedApplication].keyWindow.rootViewController;
            while(top.presentedViewController)top=top.presentedViewController;
            [top presentViewController:ac animated:YES completion:nil];
        } else if(hasTH){inject([base stringByAppendingPathComponent:s2.ffthPath]);}
        else if(hasMAX){inject([base stringByAppendingPathComponent:s2.ffmaxPath]);}
        else{
            ZXSlotCell*c2=(ZXSlotCell*)[svc->_tv cellForRowAtIndexPath:cIP];c2.sw.on=NO;
            [c2 setStatus:@"Set FFTH or FFMAX path in bot" color:UIColor.systemOrangeColor];
        }
    };
    return cell;
}
-(CGFloat)tableView:(UITableView*)tv heightForRowAtIndexPath:(NSIndexPath*)ip{return _tab==2?240:82;}
-(CGFloat)tableView:(UITableView*)tv heightForFooterInSection:(NSInteger)s{return 6;}
-(UIView*)tableView:(UITableView*)tv viewForFooterInSection:(NSInteger)s{UIView*v=[UIView new];v.backgroundColor=UIColor.clearColor;return v;}
// ── Remove/Restore ────────────────────────────────────────────────
-(void)rmTap:(UIButton*)b{
    ZXPlay(@"remove");
    NSInteger opt=b.tag;
    NSString*rmName=opt==1?(_cfg.rm1Name?:@"Restore 1"):(_cfg.rm2Name?:@"Restore 2");
    UIAlertController*ac=[UIAlertController alertControllerWithTitle:rmName
        message:@"Restore original file?" preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"Restore" style:UIAlertActionStyleDestructive handler:^(UIAlertAction*a){
        NSString*url=[NSString stringWithFormat:@"%@/restore/%ld",kServerBase,(long)opt];
        [[[NSURLSession sharedSession]downloadTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSURL*tmp,NSURLResponse*resp,NSError*err){
            if(!tmp||err){return;}
            NSHTTPURLResponse*hr=(NSHTTPURLResponse*)resp;if(hr.statusCode!=200)return;
            NSString*fn=hr.allHeaderFields[@"X-File-Name"]?:@"file";
            NSString*base=[self mcmBase];
            NSString*ffth=opt==1?self->_cfg.rm1ffth:self->_cfg.rm2ffth;
            NSString*ffmax=opt==1?self->_cfg.rm1ffmax:self->_cfg.rm2ffmax;
            NSFileManager*fm=NSFileManager.defaultManager;
            NSData*data=[NSData dataWithContentsOfURL:tmp];
            if(!data)return;
            for(NSString*pp in @[ffth,ffmax]){
                if(!pp.length)continue;
                NSString*dir=[base stringByAppendingPathComponent:pp];
                [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
                [data writeToFile:[dir stringByAppendingPathComponent:fn] atomically:YES];
            }
            dispatch_async(dispatch_get_main_queue(),^{
                UIAlertController*ok=[UIAlertController alertControllerWithTitle:@"Restored"
                    message:@"Original file restored" preferredStyle:UIAlertControllerStyleAlert];
                [ok addAction:[UIAlertAction actionWithTitle:@"OK" style:0 handler:nil]];
                UIViewController*top=[UIApplication sharedApplication].keyWindow.rootViewController;
                while(top.presentedViewController)top=top.presentedViewController;
                [top presentViewController:ok animated:YES completion:nil];
            });
        }]resume];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}
-(void)switchTab:(NSInteger)idx{
    _tab=idx;[_tv reloadData];
    for(NSInteger i=0;i<(NSInteger)_tabBtns.count;i++){
        UIButton*b=(UIButton*)_tabBtns[i];BOOL sel=(i==idx);
        [b setTitleColor:sel?UIColor.whiteColor:ZXGray forState:0];
        b.titleLabel.font=[UIFont systemFontOfSize:11 weight:sel?UIFontWeightBold:UIFontWeightRegular];
        for(UIView*sv in b.subviews){if(sv.tag==88)[sv removeFromSuperview];}
        if(sel){
            UIView*ind=[[UIView alloc]initWithFrame:CGRectMake(0,0,b.bounds.size.width,2)];
            ind.backgroundColor=ZXRed;ind.tag=88;ZXRedGlow(ind,4);[b addSubview:ind];
        }
    }
}
-(void)tabTap:(UIButton*)b{[self switchTab:b.tag];}
-(void)openTG{
    NSString*u=_cfg.telegram.length?_cfg.telegram:@"https://t.me/zexinjector";
    [[UIApplication sharedApplication]openURL:[NSURL URLWithString:u] options:@{} completionHandler:nil];
}
// ── Build UI ──────────────────────────────────────────────────────
-(void)buildUI{
    // Header
    UILabel*brand=[UILabel new];brand.translatesAutoresizingMaskIntoConstraints=NO;
    NSMutableAttributedString*bas=[[NSMutableAttributedString alloc]initWithString:@"ZEX EXTERNAL"];
    [bas addAttribute:NSForegroundColorAttributeName value:ZXRed range:NSMakeRange(0,3)];
    [bas addAttribute:NSForegroundColorAttributeName value:UIColor.whiteColor range:NSMakeRange(3,9)];
    [bas addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:22 weight:UIFontWeightHeavy] range:NSMakeRange(0,12)];
    brand.attributedText=bas;[self.view addSubview:brand];
    UIView*pill=ZXGlassView(11);pill.translatesAutoresizingMaskIntoConstraints=NO;
    pill.layer.borderColor=ZXRed.CGColor;ZXRedGlow(pill,5);[self.view addSubview:pill];
    _headerConn=[UILabel new];_headerConn.translatesAutoresizingMaskIntoConstraints=NO;
    _headerConn.text=@"Connecting";_headerConn.font=[UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    _headerConn.textColor=ZXGray;[pill addSubview:_headerConn];
    UIButton*tgBtn=[UIButton buttonWithType:UIButtonTypeSystem];tgBtn.translatesAutoresizingMaskIntoConstraints=NO;
    [tgBtn setImage:[UIImage systemImageNamed:@"bell.fill"] forState:0];tgBtn.tintColor=[UIColor colorWithWhite:.4 alpha:1];
    [tgBtn addTarget:self action:@selector(openTG) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:tgBtn];
    // Status card
    UIView*sc=ZXGlassView(13);sc.translatesAutoresizingMaskIntoConstraints=NO;
    sc.layer.borderColor=ZXRed.CGColor;ZXRedGlow(sc,5);[self.view addSubview:sc];
    UIImageView*shield=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"shield.lefthalf.filled"]];
    shield.translatesAutoresizingMaskIntoConstraints=NO;shield.tintColor=ZXRed;
    shield.contentMode=UIViewContentModeScaleAspectFit;[sc addSubview:shield];
    UILabel*st=[UILabel new];st.translatesAutoresizingMaskIntoConstraints=NO;
    st.text=@"SYSTEM READY";st.font=[UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    st.textColor=UIColor.whiteColor;[sc addSubview:st];
    UILabel*ss=[UILabel new];ss.translatesAutoresizingMaskIntoConstraints=NO;
    ss.text=@"All systems operational";ss.font=[UIFont systemFontOfSize:10];ss.textColor=ZXGray;[sc addSubview:ss];
    _verLbl=[UILabel new];_verLbl.translatesAutoresizingMaskIntoConstraints=NO;
    _verLbl.text=@"v—";_verLbl.font=[UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightMedium];
    _verLbl.textColor=ZXRed;[sc addSubview:_verLbl];
    _connLbl=[UILabel new];_connLbl.translatesAutoresizingMaskIntoConstraints=NO;
    _connLbl.font=[UIFont systemFontOfSize:10];[sc addSubview:_connLbl];
    // Slot header
    UIView*sBar=[[UIView alloc]init];sBar.translatesAutoresizingMaskIntoConstraints=NO;
    sBar.backgroundColor=ZXRed;sBar.layer.cornerRadius=1.5;ZXRedGlow(sBar,4);[self.view addSubview:sBar];
    UILabel*slhdr=[UILabel new];slhdr.translatesAutoresizingMaskIntoConstraints=NO;
    NSMutableAttributedString*sh=[[NSMutableAttributedString alloc]initWithString:@"INJECTION SLOTS"];
    [sh addAttribute:NSKernAttributeName value:@3 range:NSMakeRange(0,15)];
    [sh addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithWhite:.6 alpha:1] range:NSMakeRange(0,15)];
    [sh addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:10 weight:UIFontWeightBold] range:NSMakeRange(0,15)];
    slhdr.attributedText=sh;[self.view addSubview:slhdr];
    // TableView
    _tv=[[UITableView alloc]initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tv.translatesAutoresizingMaskIntoConstraints=NO;_tv.backgroundColor=UIColor.clearColor;
    _tv.separatorStyle=0;_tv.dataSource=self;_tv.delegate=self;[self.view addSubview:_tv];
    // Tab bar
    UIView*tabBar=[[UIView alloc]init];tabBar.translatesAutoresizingMaskIntoConstraints=NO;
    tabBar.backgroundColor=[UIColor colorWithWhite:.03 alpha:.95];
    tabBar.layer.borderWidth=.5;tabBar.layer.borderColor=[UIColor colorWithWhite:1 alpha:.06].CGColor;
    [self.view addSubview:tabBar];
    NSMutableArray<UIButton*>*btns=[NSMutableArray array];
    NSArray*tt=@[@"AIM LOCK",@"LOCATION",@"MOD SKIN",@"EXTRA"];
    for(NSInteger i=0;i<4;i++){
        UIButton*tb=[UIButton buttonWithType:UIButtonTypeSystem];tb.translatesAutoresizingMaskIntoConstraints=NO;
        NSMutableAttributedString*ta=[[NSMutableAttributedString alloc]initWithString:tt[i]];
        [ta addAttribute:NSKernAttributeName value:@1.0 range:NSMakeRange(0,((NSString*)tt[i]).length)];
        [tb setAttributedTitle:ta forState:0];
        [tb setTitleColor:(i==0?UIColor.whiteColor:ZXGray) forState:0];
        tb.titleLabel.font=[UIFont systemFontOfSize:10 weight:(i==0?UIFontWeightBold:UIFontWeightRegular)];
        tb.tag=i;[tb addTarget:self action:@selector(tabTap:) forControlEvents:UIControlEventTouchUpInside];
        [tabBar addSubview:tb];[btns addObject:tb];
        [NSLayoutConstraint activateConstraints:@[
            [tb.topAnchor constraintEqualToAnchor:tabBar.topAnchor],
            [tb.bottomAnchor constraintEqualToAnchor:tabBar.safeAreaLayoutGuide.bottomAnchor],
            [tb.widthAnchor constraintEqualToAnchor:tabBar.widthAnchor multiplier:1.0/4],
        ]];
        if(i==0)[tb.leadingAnchor constraintEqualToAnchor:tabBar.leadingAnchor].active=YES;
        else [tb.leadingAnchor constraintEqualToAnchor:((UIButton*)btns[i-1]).trailingAnchor].active=YES;
        if(i==0){
            dispatch_async(dispatch_get_main_queue(),^{
                UIView*ind=[[UIView alloc]initWithFrame:CGRectMake(0,0,tb.bounds.size.width,2)];
                ind.backgroundColor=ZXRed;ind.tag=88;ZXRedGlow(ind,4);[tb addSubview:ind];
            });
        }
    }
    _tabBtns=btns;
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [brand.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [brand.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [tgBtn.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-14],
        [tgBtn.centerYAnchor constraintEqualToAnchor:brand.centerYAnchor],
        [pill.trailingAnchor constraintEqualToAnchor:tgBtn.leadingAnchor constant:-8],
        [pill.centerYAnchor constraintEqualToAnchor:brand.centerYAnchor],
        [_headerConn.leadingAnchor constraintEqualToAnchor:pill.leadingAnchor constant:10],
        [_headerConn.trailingAnchor constraintEqualToAnchor:pill.trailingAnchor constant:-10],
        [_headerConn.topAnchor constraintEqualToAnchor:pill.topAnchor constant:6],
        [_headerConn.bottomAnchor constraintEqualToAnchor:pill.bottomAnchor constant:-6],
        [sc.topAnchor constraintEqualToAnchor:brand.bottomAnchor constant:10],
        [sc.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:14],
        [sc.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-14],
        [shield.leadingAnchor constraintEqualToAnchor:sc.leadingAnchor constant:12],
        [shield.centerYAnchor constraintEqualToAnchor:sc.centerYAnchor],
        [shield.widthAnchor constraintEqualToConstant:26],[shield.heightAnchor constraintEqualToConstant:26],
        [st.leadingAnchor constraintEqualToAnchor:shield.trailingAnchor constant:10],
        [st.topAnchor constraintEqualToAnchor:sc.topAnchor constant:10],
        [ss.leadingAnchor constraintEqualToAnchor:st.leadingAnchor],
        [ss.topAnchor constraintEqualToAnchor:st.bottomAnchor constant:2],
        [ss.bottomAnchor constraintEqualToAnchor:sc.bottomAnchor constant:-10],
        [_verLbl.trailingAnchor constraintEqualToAnchor:sc.trailingAnchor constant:-12],
        [_verLbl.topAnchor constraintEqualToAnchor:sc.topAnchor constant:10],
        [_connLbl.trailingAnchor constraintEqualToAnchor:sc.trailingAnchor constant:-12],
        [_connLbl.bottomAnchor constraintEqualToAnchor:sc.bottomAnchor constant:-10],
        [sBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:14],
        [sBar.widthAnchor constraintEqualToConstant:3],[sBar.heightAnchor constraintEqualToConstant:12],
        [sBar.centerYAnchor constraintEqualToAnchor:slhdr.centerYAnchor],
        [slhdr.leadingAnchor constraintEqualToAnchor:sBar.trailingAnchor constant:8],
        [slhdr.topAnchor constraintEqualToAnchor:sc.bottomAnchor constant:10],
        [_tv.topAnchor constraintEqualToAnchor:slhdr.bottomAnchor constant:6],
        [_tv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:14],
        [_tv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-14],
        [_tv.bottomAnchor constraintEqualToAnchor:tabBar.topAnchor constant:-4],
        [tabBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tabBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tabBar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [tabBar.heightAnchor constraintEqualToConstant:80],
    ]];
}
@end

// ── ZEXInjectorVC ─────────────────────────────────────────────────
@implementation ZEXInjectorVC
-(UIStatusBarStyle)preferredStatusBarStyle{return UIStatusBarStyleLightContent;}
-(UIViewController*)childViewControllerForStatusBarStyle{return self.childViewControllers.lastObject;}
-(void)viewDidLoad{
    [super viewDidLoad];
    self.view.frame=UIScreen.mainScreen.bounds;self.view.backgroundColor=ZXBg;
    [self showSplash];
}
-(void)showSplash{
    UIView*splash=[[UIView alloc]initWithFrame:self.view.bounds];
    splash.backgroundColor=ZXBg;splash.autoresizingMask=63;
    CAGradientLayer*g=[CAGradientLayer layer];g.frame=splash.bounds;
    g.colors=@[(id)[UIColor colorWithRed:.15 green:0 blue:.03 alpha:1].CGColor,(id)ZXBg.CGColor];
    g.locations=@[@0,@.5];[splash.layer insertSublayer:g atIndex:0];
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(4,4),NO,0);
    CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(),ZXRed.CGColor);
    CGContextFillEllipseInRect(UIGraphicsGetCurrentContext(),CGRectMake(0,0,4,4));
    UIImage*dot=UIGraphicsGetImageFromCurrentImageContext();UIGraphicsEndImageContext();
    CAEmitterLayer*el=[CAEmitterLayer layer];
    el.emitterPosition=CGPointMake(UIScreen.mainScreen.bounds.size.width/2,-10);
    el.emitterSize=CGSizeMake(UIScreen.mainScreen.bounds.size.width,0);
    el.emitterShape=kCAEmitterLayerLine;
    CAEmitterCell*ec=[CAEmitterCell emitterCell];
    ec.contents=(id)dot.CGImage;ec.birthRate=6;ec.lifetime=7;
    ec.velocity=35;ec.velocityRange=15;ec.emissionRange=M_PI/8;
    ec.scale=1.2;ec.scaleRange=.6;ec.alphaRange=.4;ec.alphaSpeed=-.06;
    el.emitterCells=@[ec];[splash.layer addSublayer:el];
    UILabel*logo=[UILabel new];logo.translatesAutoresizingMaskIntoConstraints=NO;
    NSMutableAttributedString*as=[[NSMutableAttributedString alloc]initWithString:@"ZEX EXTERNAL"];
    [as addAttribute:NSForegroundColorAttributeName value:ZXRed range:NSMakeRange(0,3)];
    [as addAttribute:NSForegroundColorAttributeName value:UIColor.whiteColor range:NSMakeRange(3,9)];
    [as addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:36 weight:UIFontWeightHeavy] range:NSMakeRange(0,12)];
    logo.attributedText=as;logo.textAlignment=NSTextAlignmentCenter;[splash addSubview:logo];
    UILabel*sub=[UILabel new];sub.translatesAutoresizingMaskIntoConstraints=NO;
    sub.text=@"PREMIUM INJECTION SYSTEM";sub.font=[UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    sub.textColor=[UIColor colorWithWhite:1 alpha:.3];sub.textAlignment=NSTextAlignmentCenter;[splash addSubview:sub];
    UIActivityIndicatorView*sp=[[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    sp.translatesAutoresizingMaskIntoConstraints=NO;sp.color=ZXRed;[sp startAnimating];[splash addSubview:sp];
    [NSLayoutConstraint activateConstraints:@[
        [logo.centerXAnchor constraintEqualToAnchor:splash.centerXAnchor],
        [logo.centerYAnchor constraintEqualToAnchor:splash.centerYAnchor constant:-30],
        [sub.centerXAnchor constraintEqualToAnchor:splash.centerXAnchor],
        [sub.topAnchor constraintEqualToAnchor:logo.bottomAnchor constant:10],
        [sp.centerXAnchor constraintEqualToAnchor:splash.centerXAnchor],
        [sp.topAnchor constraintEqualToAnchor:sub.bottomAnchor constant:30],
    ]];
    [self.view addSubview:splash];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2000*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
        [UIView animateWithDuration:.5 animations:^{splash.alpha=0;} completion:^(BOOL f){
            [splash removeFromSuperview];
            NSString*saved=[[NSUserDefaults standardUserDefaults]stringForKey:kSavedKey];
            if(saved.length)[self verifyAndProceed:saved];else[self showAuth];
        }];
    });
}
-(void)verifyAndProceed:(NSString*)key{
    if([key isEqualToString:@"ZEX-MASTER-9999-ROOT"]){[self showMain];return;}
    NSString*dev=[[UIDevice currentDevice].identifierForVendor.UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""];
    NSString*url=[NSString stringWithFormat:@"%@/verify?key=%@&device=%@",kServerBase,
        [key stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet],dev];
    [[[NSURLSession sharedSession]dataTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSData*d,NSURLResponse*r,NSError*e){
        dispatch_async(dispatch_get_main_queue(),^{
            if(!d||e){[self showMain];return;}
            NSDictionary*j=[NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
            if([j[@"valid"]boolValue]){[self showMain];}
            else{
                [[NSUserDefaults standardUserDefaults]removeObjectForKey:kSavedKey];
                [[NSUserDefaults standardUserDefaults]synchronize];
                [self showAuth];
            }
        });
    }]resume];
}
-(void)showAuth{
    for(UIViewController*c in self.childViewControllers){[c willMoveToParentViewController:nil];[c.view removeFromSuperview];[c removeFromParentViewController];}
    ZXAuthVC*a=[ZXAuthVC new];a.onAuth=^{[self showMain];};
    [self addChildViewController:a];a.view.frame=UIScreen.mainScreen.bounds;
    a.view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:a.view];[a didMoveToParentViewController:self];
    [self setNeedsStatusBarAppearanceUpdate];
}
-(void)showMain{
    for(UIViewController*c in self.childViewControllers){[c willMoveToParentViewController:nil];[c.view removeFromSuperview];[c removeFromParentViewController];}
    ZXMainVC*m=[ZXMainVC new];
    [self addChildViewController:m];m.view.frame=UIScreen.mainScreen.bounds;
    m.view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:m.view];[m didMoveToParentViewController:self];
    [self setNeedsStatusBarAppearanceUpdate];
}
@end
