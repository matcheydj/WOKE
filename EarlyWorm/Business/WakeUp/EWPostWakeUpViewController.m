//
//  EWPostWakeUpViewController.m
//  EarlyWorm
//
//  Created by letv on 14-2-17.
//  Copyright (c) 2014年 Shens. All rights reserved.
//

#import "EWPostWakeUpViewController.h"

#import "EWPerson.h"
#import "EWPersonStore.h"
#import "EWServer.h"

#import <QuartzCore/QuartzCore.h>

@interface EWPostWakeUpViewController ()
{
    IBOutlet UIImageView * backGroundImage;
    
    IBOutlet UIButton * wakeThemBtn;
    IBOutlet UIButton * doneBtn;
    
    IBOutlet UILabel * timeLabel;
    IBOutlet UILabel * unitLabel;
    
    IBOutlet UILabel * markALabel;
    IBOutlet UILabel * markBLabel;
    
    IBOutlet UIImageView * barImageView;
    
    UICollectionView * friendsCollectionView;
    
    NSInteger time;
}

@property(nonatomic,strong)NSMutableSet * selectedPersonSet;

//init views and data
-(void)initViews;
-(void)initData;

//click action
-(IBAction)wakeAllAction:(id)sender;
-(IBAction)doneAction:(id)sender;

@end

@implementation EWPostWakeUpViewController

@synthesize personArray;
@synthesize taskItem;
@synthesize selectedPersonSet;

-(void)dealloc
{
    personArray = nil;
    taskItem = nil;
    personArray = nil;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        personArray = [[NSArray alloc] init];
        selectedPersonSet = [[NSMutableSet alloc]initWithCapacity:0];
        time = 0;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [self initViews];
    [self initData];
}

#pragma mark -
#pragma mark - init views and data

-(void)initViews
{
    NSLog(@"%s",__func__);
    
    UICollectionViewFlowLayout *flowLayout=[[UICollectionViewFlowLayout alloc] init];
    [flowLayout setScrollDirection:UICollectionViewScrollDirectionVertical];
    
    if (iPhone5)
    {
   
        friendsCollectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(34, 330, 253, 171) collectionViewLayout:flowLayout];
        [self.view addSubview:friendsCollectionView];
    }
    else
    {
        friendsCollectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(34, 242, 253, 171) collectionViewLayout:flowLayout];
        [self.view addSubview:friendsCollectionView];
        
        wakeThemBtn.frame = CGRectMake(20, 427, 127, 39);
        doneBtn.frame = CGRectMake(173, 427, 127, 39);
        
        markALabel.hidden = YES;
        
        markBLabel.frame = CGRectMake(0, 205, 320, 36);
        barImageView.frame = CGRectMake(0, 413, 320, 67);
    }
    
    friendsCollectionView.dataSource = self;
    friendsCollectionView.delegate = self;
    friendsCollectionView.backgroundColor = [UIColor clearColor];
    friendsCollectionView.showsVerticalScrollIndicator = NO;
    friendsCollectionView.showsHorizontalScrollIndicator = NO;
    [friendsCollectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:COLLECTION_VIEW_IDENTIFIER];
    
    wakeThemBtn.layer.cornerRadius = 5;
    wakeThemBtn.layer.borderWidth = 1.0f;
    wakeThemBtn.layer.borderColor = [UIColor whiteColor].CGColor;
    
    doneBtn.layer.cornerRadius = 5;
    doneBtn.layer.borderWidth = 1.0f;
    doneBtn.layer.borderColor = [UIColor whiteColor].CGColor;
    
    barImageView.layer.shadowColor = [UIColor blackColor].CGColor;
    barImageView.layer.shadowOffset = CGSizeMake(0, -3);
    barImageView.layer.shadowOpacity = 1.0f;
    
    
    UIView * timerView = [[UIView alloc] initWithFrame:CGRectMake(100, 95, 110, 110)];
    timerView.layer.cornerRadius = 55;
    timerView.layer.borderColor = [UIColor whiteColor].CGColor;
    timerView.layer.borderWidth = 1.5f;
    timerView.alpha = 0.4f;
    timerView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:timerView];
}

-(void)initData
{
    NSLog(@"%s",__func__);

    /*此处应将再上一个controller完成赋值，目前只是举个例子*/
    personArray = [[EWPersonStore sharedInstance] everyone];
    
    //获取唤醒时间及单位
    
    /*此处写入两段时间的差值.例如：time = time1 - time2;*/
    // coding ...
    
    timeLabel.text = [self getTime];
    unitLabel.text = [self getUnit];
}

#pragma mark -
#pragma mark - get buzzing time & unit -

-(NSString *)getTime
{
    NSLog(@"%s",__func__);
    NSString * timeStr;
    if (time < 60 && time >= 0)
    {
        timeStr = [NSString stringWithFormat:@"%d",time];
        return timeStr;
    }
    else if (time >= 60 && time < 3600)
    {
        if (time%60 == 0)
        {
            timeStr = [NSString stringWithFormat:@"%d",time/60];
            return timeStr;
        }
        else
        {
            if (time/60.0 > 10.0)
            {
                timeStr = [NSString stringWithFormat:@"%d",time/60];
                return timeStr;
            }
            timeStr = [NSString stringWithFormat:@"%.1f",time/60.0];
            return timeStr;
        }
    }
    else
    {
        if (time%3600 == 0)
        {
            timeStr = [NSString stringWithFormat:@"%d",time/3600];
            return timeStr;
        }
        else
        {
            if (time/3600.0 > 10.0)
            {
                timeStr = [NSString stringWithFormat:@"%d",time/3600];
                return timeStr;
            }
            timeStr = [NSString stringWithFormat:@"%.1f",time/3600.0];
            return timeStr;
        }
    }
    
    return nil;
}
-(NSString *)getUnit
{
    NSLog(@"%s",__func__);
    
    if (time < 60 && time >= 0)
    {
        if (time == 0 || time == 1)
        {
            return @"second";
        }
        return @"seconds";
    }
    else if( time >= 60 && time < 3600)
    {
        if (time == 60)
        {
            return @"minute";
        }
        return @"minutes";
    }
    else
    {
        if (time == 3600)
        {
            return @"hour";
        }
        return @"hours";
    }
    
    return nil;
}


#pragma mark -
#pragma mark - IBAction -

-(IBAction)wakeAllAction:(id)sender
{
    NSLog(@"%s",__func__);
    
    if ([selectedPersonSet count] != 0)
    {
        /*
        for (int i = 0; i < [selectedPersonSet count]; i ++)
        {
            NSArray * selectedPersonArray = [selectedPersonSet allObjects];
            EWPerson * person = [selectedPersonArray objectAtIndex:i];
            
            //buzz
            
        }*/
        
        for (EWPerson *person in selectedPersonSet) {
            [EWServer buzz:person];
        }
        
        [self dismissViewControllerAnimated:YES completion:^{
            
        }];
    }
    else
    {
        NSLog(@"no person selected");
        
        UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:@"提醒" message:@"请选择要被唤醒的朋友" delegate:self cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
        [alertView show];
    }
}


-(IBAction)doneAction:(id)sender
{
    NSLog(@"%s",__func__);
    
    [self dismissViewControllerAnimated:YES completion:^{
       
    }];
}


#pragma mark -
#pragma mark - collection view delegate & dataSource -

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [personArray count];
}

// The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    
    UICollectionViewCell * cell = [collectionView  dequeueReusableCellWithReuseIdentifier:COLLECTION_VIEW_IDENTIFIER forIndexPath:indexPath];
    
    UIImageView * headImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0,COLLECTION_CELL_WIDTH, COLLECTION_CELL_HEIGHT)];
        headImageView.layer.masksToBounds = YES;
    headImageView.layer.cornerRadius = 27;
    headImageView.layer.borderColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.5].CGColor;
    headImageView.layer.borderWidth = 1.0f;
    
    [cell.contentView addSubview:headImageView];
    
    
    cell.contentView.backgroundColor = [UIColor clearColor];
    
    EWPerson * person = [personArray objectAtIndex:indexPath.row];
    headImageView.image = person.profilePic;
    
    //选中
    if ([selectedPersonSet containsObject:person] == YES){
        UIImageView *maskView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0,COLLECTION_CELL_WIDTH, COLLECTION_CELL_HEIGHT)];
        maskView.layer.masksToBounds = YES;
        maskView.layer.cornerRadius = 27;
        maskView.image = [UIImage imageNamed:@"checkmark"];;
        [cell.contentView addSubview:maskView];
        
    }
    
    return cell;
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    
    EWPerson * person = [personArray objectAtIndex:indexPath.row];
    if ([selectedPersonSet containsObject:person] == YES)
    {
        //取消被选中状态
        if ([selectedPersonSet count] != 0)
        {
            [selectedPersonSet removeObject:person];
        }
    }
    else
    {
        //选中
        [selectedPersonSet addObject:person];
    }
    
    [self reloadData];
    
    NSLog(@"%d",[selectedPersonSet count]);
    
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return CGSizeMake(COLLECTION_CELL_WIDTH,COLLECTION_CELL_HEIGHT);
}

//reload data

-(void)reloadData
{
    NSLog(@"%s",__func__);
    
    [friendsCollectionView reloadData];
}

#pragma mark -
#pragma mark - memorying warning -

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end