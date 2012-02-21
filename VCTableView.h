//
// Subclass of UITableView that allows for the reordering of rows without the use of UITableViewCell's reorder controls
//
// The table view must have a data source object that impliments tableView:moveRowAtIndexPath:toIndexPath:
// 
// IMPORTANT: The data source is responsible for providing the "empty" UITableViewCell any time it's requested in tableView:cellForRowAtIndexPath:!! The dataSource can 
// use the currentPath property to find out which cell is supposed to be the "empty" one
//
// The movable image is of the cell in it's selected state.
// NOTE: Have to link with QuartzCore framework for the rendering of the cell as an iamge
//


#import <UIKit/UIKit.h>
typedef enum {
    VCTableView_Move_Direction_None = 0,
    VCTableView_Move_Direction_Down,
    VCTableView_Move_Direction_Up
} VCTableView_Move_Direction;

@interface VCTableView : UITableView <UITableViewDataSource, UITableViewDelegate>
{
    UIImageView *cellImageView; //image view holding image of the cell being moved
    
    UILongPressGestureRecognizer *longgr;
    
    NSIndexPath *currentPath; //index path of cell at most recent gesture event location
    NSIndexPath *initialPath; //index path of cell where long press began. 
    UITableViewCell *_emptyCell;
    BOOL ignoreGesture;
    VCTableView_Move_Direction moveDirection;
    CGPoint previousTouchPt;
    
    NSMutableArray *indexPathsMap;
    
    id <UITableViewDataSource> _theRealDataSource;
    id <UITableViewDelegate> _theRealDelegate;
    
    BOOL _isTracking;
}

//
// The gesture recognizer for the table view. Use this property to set the attributes of the gesture
//
@property (readonly) UILongPressGestureRecognizer *longgr;

//
// Use this property to determine the location of the cell that should currently be empty.
//
@property (nonatomic, retain) NSIndexPath *currentPath;

@property (nonatomic, retain) NSIndexPath *initialPath;

@property (nonatomic, retain) UITableViewCell *emptyCell;
@property (nonatomic, readonly) BOOL isTracking;
//
// Function turns on/off the ability to reorder rows
//
-(void)setReordering:(BOOL)allowReorder;
@end
