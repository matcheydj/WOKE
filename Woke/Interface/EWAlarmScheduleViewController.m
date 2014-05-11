//
//  EWAlarmScheduleViewController.m
//  EarlyWorm
//
//  Created by Lei on 10/18/13.
//  Copyright (c) 2013 Shens. All rights reserved.
//

#import "EWAlarmScheduleViewController.h"
#import "EWTaskStore.h"
#import "EWTaskItem.h"
#import "EWAlarmManager.h"
#import "EWAlarmItem.h"
#import "EWAlarmEditCell.h"
#import "EWPersonStore.h"
#import "UIViewController+Blur.h"

//Util
#import "NSDate+Extend.h"
#import "MBProgressHUD.h"

//backend
#import "EWDataStore.h"
#import "StackMob.h"


static NSString *cellIdentifier = @"scheduleAlarmCell";

@implementation EWAlarmScheduleViewController{
    NSInteger selected;
}

- (void)viewDidLoad{
    //tableview
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.contentInset = UIEdgeInsetsMake(45, 0, 200, 0);
    [self.view addSubview:_tableView];
    
    //header view
//    UIButton *backBtn = [[UIButton alloc] initWithFrame:CGRectMake(20, 30, 18, 30)];
//    [backBtn setImage:[UIImage imageNamed:@"back_btn"] forState:UIControlStateNormal];
//    [backBtn addTarget:self action:@selector(OnDone) forControlEvents:UIControlEventTouchUpInside];
//    [self.view addSubview:backBtn];
    
    UIBarButtonItem *doneBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(OnDone)];
    UIBarButtonItem *cancelBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(OnCancel)];
    UIBarButtonItem *center = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    [self.navigationBar setItems:@[doneBtn, center, cancelBtn] animated:YES];
    [self.view sendSubviewToBack:_tableView];
    
    UINib *cellNib = [UINib nibWithNibName:@"EWAlarmEditCell" bundle:nil];
    [_tableView registerNib:cellNib forCellReuseIdentifier:cellIdentifier];
    
    //data
    [self initData];
}

- (BOOL)prefersStatusBarHidden{
    return YES;
}

- (void)initData{
    //data source
    alarms = [EWAlarmManager myAlarms];
    tasks = [EWTaskStore myTasks];
    
    selected = 99;
}

#pragma mark - View life cycle
- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
    [self setEdgesForExtendedLayout:UIRectEdgeAll];
    
    //schedule alarm and tasks
    //pop up alarmScheduleView
    if (alarms.count != 7 || tasks.count != 7) {
        NSLog(@"%s: Need to check the data", __func__);
        
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        
        
        dispatch_async([EWDataStore sharedInstance].dispatch_queue, ^{
            alarms = [[EWAlarmManager sharedInstance] scheduleNewAlarms];//initial alarm
            tasks = [[EWTaskStore sharedInstance] scheduleTasks];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
                
                //view
                [_tableView reloadData];
            });
        });
        
    }

}

//refrash data after edited
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [_tableView reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)save{
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    for (unsigned i=0; i<[_tableView numberOfRowsInSection:0]; i++) {
        EWAlarmEditCell *cell = (EWAlarmEditCell *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForItem:i inSection:0]];
        if (!cell) {
            continue;
        }
        //state
        if (cell.alarmToggle.selected != cell.alarm.state) {
            NSLog(@"Change alarm state for %@ to %@", cell.alarm.time.weekday, cell.alarmToggle.selected?@"ON":@"OFF");
            cell.alarm.state = cell.alarmToggle.selected?YES:NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:kAlarmStateChangedNotification object:self userInfo:@{@"alarm": cell.alarm}];
        }
        //music
        if (![cell.myMusic isEqualToString:cell.alarm.tone] && cell.myMusic != nil) {
            NSLog(@"Music changed to %@", cell.myMusic);
            cell.alarm.tone = cell.myMusic;
            [[NSNotificationCenter defaultCenter] postNotificationName:kAlarmToneChangedNotification object:self userInfo:@{@"alarm": cell.alarm}];
        }
        //time
        if (![cell.myTime isEqual:cell.task.time]) {
            NSLog(@"Time updated to %@", [cell.myTime date2detailDateString]);
            cell.alarm.time = cell.myTime;
            //save alarm time to user defaults
            [[EWAlarmManager sharedInstance] setSavedAlarmTime:cell.alarm];
            [[NSNotificationCenter defaultCenter] postNotificationName:kAlarmTimeChangedNotification object:self userInfo:@{@"alarm": cell.alarm}];
        }
        //statement
        if (cell.statement.text.length && ![cell.statement.text isEqualToString:cell.task.statement]) {
            cell.task.statement = cell.statement.text;
            
        }
        //save
        [[EWDataStore currentContext] saveOnSuccess:^{
            //
        } onFailure:^(NSError *error) {
            NSLog(@"Alarms failed to save");
        }];
    }
    
    
    [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
}

#pragma mark - UI events
- (void)OnDone{
    [self.presentingViewController dismissBlurViewControllerWithCompletionHandler:NULL];
    [self save];
}

- (void)OnCancel{
    [self.presentingViewController dismissBlurViewControllerWithCompletionHandler:NULL];
}

- (BOOL)navigationBar:(UINavigationBar *)navigationBar shouldPopItem:(UINavigationItem *)item{
    
    return YES;
}


#pragma mark - tableViewController delegate methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return alarms.count;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    //reusable cell
    EWAlarmEditCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    //data
    if (!cell.task) {
        cell.task = tasks[indexPath.row];//alarm set automatically
    }
    
    //breaking MVC pattern to get ringtonVC work
    cell.presentingViewController = self;
    //return
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath{
    CGFloat alpha = indexPath.row%2?0.05:0.06;
    cell.backgroundColor = [UIColor colorWithWhite:1.0 alpha:alpha];
    
    EWAlarmEditCell *myCell = (EWAlarmEditCell *)cell;
    if (myCell.alarmToggle.selected) {
        //myCell.alarmToggle.backgroundColor = [UIColor colorWithRed:120 green:200 blue:255 alpha:1];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	// If our cell is selected, return double height
	if(selected == indexPath.row    ) {
		return 160.0;
	}
	
	// Cell isn't selected so return single height
	return 80.0;
}

//when click one item in table, push view to detail page
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    [tableView beginUpdates];
    
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (selected == indexPath.row) {
        selected = 99;
    }else{
        selected = indexPath.row;
    }
    
    
    [tableView endUpdates];
}



@end