
#import "VCTableView.h"
#import <QuartzCore/QuartzCore.h>
#import "jBox.h"


@interface VCTableView (Private)
-(void)longPressed:(UILongPressGestureRecognizer*)gesture;
-(void)moveEmptyDown:(id)sender;
-(void)moveEmptyUp:(id)sender;

-(UIImage *)imageOfView:(UIView *)aView;
@end

@implementation VCTableView
@synthesize longgr, isTracking = _isTracking;
@synthesize currentPath, initialPath, emptyCell = _emptyCell;

-(id)initWithFrame:(CGRect)frame style:(UITableViewStyle)style
{
    self = [super initWithFrame:frame style:style];
    if(self){
        [super setDataSource:self];
        [super setDelegate:self];
        //self.editing = YES;
    }
    return self;
}

-(void)setDataSource:(id<UITableViewDataSource>)dataSource
{
    _theRealDataSource = dataSource;
}

-(void)setDelegate:(id<UITableViewDelegate>)delegate
{
    _theRealDelegate = delegate;
}

-(UITableViewCell*)emptyCell
{
    if(!_emptyCell){
        _emptyCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        _emptyCell.tag = EMPTY_CELL_TAG;
    }
    return _emptyCell;
}

//
// Function turns on/off the ability to reorder rows
//
-(void)setReordering:(BOOL)allowReorder
{
    if(allowReorder){
        if(!self.longgr){
            //add long press gesture
            longgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressed:)];
            longgr.minimumPressDuration = .25;
            [self addGestureRecognizer:longgr];
        }
    }
    else{
        if(self.longgr){
            
            //remove long press gesture
            [self removeGestureRecognizer:self.longgr];
            [longgr release];
            longgr = nil;
        }
    }
}

-(IBAction)moveEmptyUp:(id)sender
{
    DLog(@"");
    moveDirection = VCTableView_Move_Direction_Up;
    [self beginUpdates];
    
    
    [self deleteRowsAtIndexPaths:[NSArray arrayWithObject:self.currentPath] withRowAnimation:UITableViewRowAnimationNone];

    //
    // Crash happened here twice, haven't been able to reproduce, but
    // seemed like unsigned integer overflow problem, so checking for negative values 
    // and making them zero
    // sorry for this lame hack :[
    
    NSInteger nextPath = (NSInteger)(self.currentPath.row) - 1;
    if(nextPath < 0){
        nextPath = 0;
    }
    
    self.currentPath = [NSIndexPath indexPathForRow:nextPath inSection:self.currentPath.section];
    

    [self insertRowsAtIndexPaths:[NSArray arrayWithObject:self.currentPath] withRowAnimation:UITableViewRowAnimationNone];
    
    [indexPathsMap exchangeObjectAtIndex:self.currentPath.row withObjectAtIndex:self.currentPath.row + 1];

    [self endUpdates];

    moveDirection = VCTableView_Move_Direction_None;
}

-(IBAction)moveEmptyDown:(id)sender
{
    DLog(@"");
    moveDirection = VCTableView_Move_Direction_Down;
    [self beginUpdates];

    [self deleteRowsAtIndexPaths:[NSArray arrayWithObject:self.currentPath] withRowAnimation:UITableViewRowAnimationNone];

    self.currentPath = [NSIndexPath indexPathForRow:self.currentPath.row + 1 inSection:self.currentPath.section];
    
    [self insertRowsAtIndexPaths:[NSArray arrayWithObject:self.currentPath] withRowAnimation:UITableViewRowAnimationNone];
    
    [indexPathsMap exchangeObjectAtIndex:self.currentPath.row withObjectAtIndex:self.currentPath.row - 1];

    //[self reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:self.currentPath.row inSection:self.currentPath.section]] withRowAnimation:UITableViewRowAnimationNone];
    [self endUpdates];

    moveDirection = VCTableView_Move_Direction_None;
}


-(void)longPressed:(UILongPressGestureRecognizer*)longgr
{
    static CGFloat touchInCell_y; //will hold y coordinate of intial touch. this coordinate is relative to the cell
    
    CGPoint touchPt = [self.longgr locationInView:self];
    NSIndexPath *hitPath = [self indexPathForRowAtPoint:touchPt];
    DLog(@"hit path: %@", hitPath);
    DLog(@"current path: %@", self.currentPath);
    if(self.longgr.state == UIGestureRecognizerStateBegan){
        if(hitPath){
            _isTracking = YES;
            //find cell for touch
            UITableViewCell *cell = [self cellForRowAtIndexPath:hitPath];
            
            if(!self.initialPath){
                self.currentPath = hitPath;
                self.initialPath = hitPath;
            }
            
            //make image of cell
            UIImage *cellImage = [self imageOfView:cell];
            cellImageView = [[UIImageView alloc] initWithImage:cellImage];
            CGRect frame = cell.frame;
            cellImageView.frame = frame;
            [self addSubview:cellImageView];
            
            //load empty cell behind image - reloading data looks better than reloading the single cell. might want to change
            //this if reloading is resource intensive
            [self reloadData];
            
            //find touch relative to cell
            touchInCell_y = touchPt.y - frame.origin.y;
            previousTouchPt = touchPt;
            
            //create array that will map changing index paths of table view to presistent index paths of data source
            NSInteger numRows = [_theRealDataSource tableView:self numberOfRowsInSection:hitPath.section];
            indexPathsMap = [[NSMutableArray alloc] initWithCapacity:numRows];
            for(NSInteger i = 0; i<numRows; i++){
                [indexPathsMap addObject:[NSIndexPath indexPathForRow:i inSection:hitPath.section]];
            }
        }
        else{
            //ignore gestures if touch was not in a cell
            ignoreGesture = YES;
        }
    }
    else if(self.longgr.state == UIGestureRecognizerStateChanged){
        if(!ignoreGesture){
            cellImageView.frame = CGRectMake(cellImageView.frame.origin.x, touchPt.y - touchInCell_y, cellImageView.frame.size.width, cellImageView.frame.size.height);
            
            //switch cells
            if(!hitPath) return;
            
            if(self.currentPath.row > hitPath.row && ((touchPt.y - previousTouchPt.y) < 0)){
                [self moveEmptyUp:self];
            }
            else if(self.currentPath.row < hitPath.row && (touchPt.y - previousTouchPt.y > 0)){
                [self moveEmptyDown:self];
            }
            previousTouchPt = touchPt;
        }
    }
    else{
        if(!ignoreGesture){
            if(self.longgr.state == UIGestureRecognizerStateEnded){
                //move imageview to final location
                cellImageView.frame = CGRectMake(cellImageView.frame.origin.x, touchPt.y, cellImageView.frame.size.width, cellImageView.frame.size.height);
                
                //switch cells
                //DLog(@"hitPath row %d", hitPath.row);
                if(hitPath && self.currentPath.row < hitPath.row){
                    [self moveEmptyDown:self];
                }
                else if(hitPath && self.currentPath.row > hitPath.row){
                    DLog(@"current row %d is greater than hitPath row %d", self.currentPath.row, hitPath.row);
                    [self moveEmptyUp:self];
                }
                
                [indexPathsMap release];
                indexPathsMap = nil;
                
                //inform datasource of swap
                if([self.dataSource respondsToSelector:@selector(tableView:moveRowAtIndexPath:toIndexPath:)]){
                    [self.dataSource tableView:self moveRowAtIndexPath:self.initialPath toIndexPath:self.currentPath];
                }
                
                //remove imageview
                [cellImageView removeFromSuperview];
                [cellImageView release];
                cellImageView = nil;
                
                self.currentPath = nil;
                self.initialPath = nil;
                touchInCell_y = 0.0;
                _isTracking = NO;
                
                [self reloadData];
            }
        }
        
        ignoreGesture = NO;
    }
}

-(UIImage *)imageOfView:(UIView *)aView
{
    CGSize viewSize = aView.frame.size;
    
    UIGraphicsBeginImageContext(viewSize);
    [aView.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    return image;    
}


-(void)dealloc
{
    if(indexPathsMap){
        [indexPathsMap release];
        indexPathsMap = nil;
    }
    
    [cellImageView release];
    cellImageView = nil;
    
    [self removeGestureRecognizer:longgr];
    
    [longgr release];
    longgr = nil;
    
    [currentPath release];
    currentPath = nil;
    
    [initialPath release];
    initialPath = nil;
    
    [super dealloc];
}

#pragma mark Table View Data Source Callbacks

//
// NOTE: All of these methods are passed on to the actual data source EXCEPT
// when the table view is requesting the EMPTY CELL.
//

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSInteger ret;
    if([_theRealDataSource respondsToSelector:@selector(numberOfSectionsInTableView:)]){
        ret = [_theRealDataSource numberOfSectionsInTableView:self];
    }
    else{
        ret = 0;
    }
    return ret;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    NSArray *ret;
    if([_theRealDataSource respondsToSelector:@selector(sectionIndexTitlesForTableView:)]){
        ret = [_theRealDataSource sectionIndexTitlesForTableView:self];
    }
    else{
        ret = nil;
    }
    return ret;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    BOOL ret;
    if([_theRealDataSource respondsToSelector:@selector(tableView:canEditRowAtIndexPath:)]){
        ret = [_theRealDataSource tableView:self canEditRowAtIndexPath:indexPath];
    }
    else{
        ret = NO;
    }
    return ret;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    BOOL ret;
    if([_theRealDataSource respondsToSelector:@selector(tableView:canMoveRowAtIndexPath:)]){
        ret = [_theRealDataSource tableView:self canMoveRowAtIndexPath:indexPath];
    }
    else{
        ret = NO;
    }
    return ret;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(!_theRealDataSource) return nil;
    
    if(self.currentPath){
        if(self.currentPath.row == indexPath.row){
            NSLog(@"returning empty cell!!!");
            return self.emptyCell;
        }
    }
    return [_theRealDataSource tableView:self cellForRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if([_theRealDataSource respondsToSelector:@selector(tableView:commitEditingStyle:forRowAtIndexPath:)]){
        [_theRealDataSource tableView:self commitEditingStyle:editingStyle forRowAtIndexPath:indexPath];
    }
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
    if([_theRealDataSource respondsToSelector:@selector(tableView:moveRowAtIndexPath:toIndexPath:)]){
        [_theRealDataSource tableView:self moveRowAtIndexPath:fromIndexPath toIndexPath:toIndexPath];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if(!_theRealDataSource) return 0;
    return [_theRealDataSource tableView:self numberOfRowsInSection:section];
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    NSInteger ret;
    if([_theRealDataSource respondsToSelector:@selector(tableView:sectionForSectionIndexTitle:atIndex:)]){
        ret = [_theRealDataSource tableView:self sectionForSectionIndexTitle:title atIndex:index];
    }
    else{
        ret = 0;
    }
    return ret;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    NSString *ret;
    if([_theRealDataSource respondsToSelector:@selector(tableView:titleForFooterInSection:)]){
        ret = [_theRealDataSource tableView:self titleForFooterInSection:section];
    }
    else{
        ret = nil;
    }
    return ret;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *ret;
    if([_theRealDataSource respondsToSelector:@selector(tableView:titleForHeaderInSection:)]){
        ret = [_theRealDataSource tableView:self titleForHeaderInSection:section];
    }
    else{
        ret = nil;
    }
    return ret;
}

#pragma mark some delegate methods!

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if([_theRealDelegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]){
        [_theRealDelegate tableView:self didSelectRowAtIndexPath:indexPath];
    }
}

-(CGFloat)tableView:tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat height = self.rowHeight;
    if(indexPathsMap && indexPath.row < [indexPathsMap count]){
        if([_theRealDelegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)]){
            height = [_theRealDelegate tableView:self heightForRowAtIndexPath:[indexPathsMap objectAtIndex:indexPath.row]];
        }
    }
    else{
        if([_theRealDelegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)]){
            height = [_theRealDelegate tableView:self heightForRowAtIndexPath:indexPath];
        }
    }
    return height;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if([_theRealDelegate respondsToSelector:@selector(tableView:viewForHeaderInSection:)]){
        return [_theRealDelegate tableView:self viewForHeaderInSection:section];
    }
    else{
        return nil;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if([_theRealDelegate respondsToSelector:@selector(tableView:heightForHeaderInSection:)]){
        return [_theRealDelegate tableView:self heightForHeaderInSection:section];
    }
    else{
        return 0;
    }
}


-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    //NSLog(@"will display cell for index path %@", indexPath);
    if([_theRealDelegate respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)]){
        [_theRealDelegate tableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
}

@end
