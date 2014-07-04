//
//  Created by Jesse Squires
//  http://www.hexedbits.com
//
//
//  Documentation
//  http://cocoadocs.org/docsets/JSQMessagesViewController
//
//
//  GitHub
//  https://github.com/jessesquires/JSQMessagesViewController
//
//
//  License
//  Copyright (c) 2014 Jesse Squires
//  Released under an MIT license: http://opensource.org/licenses/MIT
//

#import "JSQMessagesViewController.h"

#import "JSQMessagesKeyboardController.h"

#import "JSQMessagesCollectionViewFlowLayoutInvalidationContext.h"

#import "JSQMessageData.h"
#import "JSQMessage.h"

#import "JSQMessagesCollectionViewCellIncoming.h"
#import "JSQMessagesCollectionViewCellIncomingPhoto.h"
#import "JSQMessagesCollectionViewCellIncomingVideo.h"
#import "JSQMessagesCollectionViewCellIncomingAudio.h"

#import "JSQMessagesCollectionViewCellOutgoing.h"
#import "JSQMessagesCollectionViewCellOutgoingPhoto.h"
#import "JSQMessagesCollectionViewCellOutgoingVideo.h"
#import "JSQMessagesCollectionViewCellOutgoingAudio.h"

#import "JSQMessagesTypingIndicatorFooterView.h"
#import "JSQMessagesLoadEarlierHeaderView.h"

#import "JSQMessagesToolbarContentView.h"
#import "JSQMessagesInputToolbar.h"
#import "JSQMessagesComposerTextView.h"

#import "JSQMessagesTimestampFormatter.h"

#import "NSString+JSQMessages.h"
#import "UIColor+JSQMessages.h"



static inline void JSQMessagesCollectionViewCellAnimateDisplayBlock(UIImageView *mediaImageView, UIImage *thumbnail, NSTimeInterval duration) {
    if (duration > 0.f) {
        [UIView transitionWithView:mediaImageView.superview
                          duration:duration
                           options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction
                        animations:^{
                            mediaImageView.image = thumbnail;
                        } completion:nil];
    }
    else {
        mediaImageView.image = thumbnail;
    }
}


static void * kJSQMessagesKeyValueObservingContext = &kJSQMessagesKeyValueObservingContext;



@interface JSQMessagesViewController () <JSQMessagesInputToolbarDelegate,
                                         JSQMessagesCollectionViewCellDelegate,
                                         JSQMessagesKeyboardControllerDelegate,
                                         UITextViewDelegate>

@property (weak, nonatomic) IBOutlet JSQMessagesCollectionView *collectionView;
@property (weak, nonatomic) IBOutlet JSQMessagesInputToolbar *inputToolbar;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *toolbarHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *toolbarBottomLayoutGuide;

@property (strong, nonatomic) JSQMessagesKeyboardController *keyboardController;

@property (assign, nonatomic) CGFloat statusBarChangeInHeight;

- (void)jsq_configureMessagesViewController;

- (void)jsq_finishSendingOrReceivingMessage;

- (NSString *)jsq_currentlyComposedMessageText;

- (void)jsq_updateKeyboardTriggerPoint;
- (void)jsq_setToolbarBottomLayoutGuideConstant:(CGFloat)constant;

- (void)jsq_handleInteractivePopGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer;

- (BOOL)jsq_inputToolbarHasReachedMaximumHeight;
- (void)jsq_adjustInputToolbarForComposerTextViewContentSizeChange:(CGFloat)dy;
- (void)jsq_adjustInputToolbarHeightConstraintByDelta:(CGFloat)dy;
- (void)jsq_scrollComposerTextViewToBottomAnimated:(BOOL)animated;

- (void)jsq_updateCollectionViewInsets;
- (void)jsq_setCollectionViewInsetsTopValue:(CGFloat)top bottomValue:(CGFloat)bottom;

- (void)jsq_addObservers;
- (void)jsq_removeObservers;

- (void)jsq_registerForNotifications:(BOOL)registerForNotifications;

- (void)jsq_addActionToInteractivePopGestureRecognizer:(BOOL)addAction;

@end



@implementation JSQMessagesViewController

#pragma mark - Class methods

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([JSQMessagesViewController class])
                          bundle:[NSBundle mainBundle]];
}

+ (instancetype)messagesViewController
{
    return [[[self class] alloc] initWithNibName:NSStringFromClass([JSQMessagesViewController class])
                                          bundle:[NSBundle mainBundle]];
}

#pragma mark - Initialization

- (void)jsq_configureMessagesViewController
{
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.toolbarHeightConstraint.constant = kJSQMessagesInputToolbarHeightDefault;
    
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    
    self.inputToolbar.delegate = self;
    self.inputToolbar.contentView.textView.placeHolder = NSLocalizedString(@"New Message", @"Placeholder text for the message input text view");
    self.inputToolbar.contentView.textView.delegate = self;
    
    self.sender = @"JSQDefaultSender";
    
    self.automaticallyScrollsToMostRecentMessage = YES;
    
    self.outgoingCellIdentifier = [JSQMessagesCollectionViewCellOutgoing cellReuseIdentifier];
    self.outgoingPhotoCellIdentifier = [JSQMessagesCollectionViewCellOutgoingPhoto cellReuseIdentifier];
    self.outgoingVideoCellIdentifier = [JSQMessagesCollectionViewCellOutgoingVideo cellReuseIdentifier];
    self.outgoingAudioCellIdentifier = [JSQMessagesCollectionViewCellOutgoingAudio cellReuseIdentifier];
    
    self.incomingCellIdentifier = [JSQMessagesCollectionViewCellIncoming cellReuseIdentifier];
    self.incomingPhotoCellIdentifier = [JSQMessagesCollectionViewCellIncomingPhoto cellReuseIdentifier];
    self.incomingVideoCellIdentifier = [JSQMessagesCollectionViewCellIncomingVideo cellReuseIdentifier];
    self.incomingAudioCellIdentifier = [JSQMessagesCollectionViewCellIncomingAudio cellReuseIdentifier];
    
    self.typingIndicatorColor = [UIColor jsq_messageBubbleLightGrayColor];
    self.showTypingIndicator = NO;
    
    self.showLoadEarlierMessagesHeader = NO;
    
    [self jsq_updateCollectionViewInsets];
    
    self.keyboardController = [[JSQMessagesKeyboardController alloc] initWithTextView:self.inputToolbar.contentView.textView
                                                                          contextView:self.view
                                                                 panGestureRecognizer:self.collectionView.panGestureRecognizer
                                                                             delegate:self];
}

- (void)dealloc
{
    [self jsq_registerForNotifications:NO];
    [self jsq_removeObservers];
    
    _collectionView.dataSource = nil;
    _collectionView.delegate = nil;
    _collectionView = nil;
    _inputToolbar = nil;
    
    _toolbarHeightConstraint = nil;
    _toolbarBottomLayoutGuide = nil;
    
    _sender = nil;
    _outgoingCellIdentifier = nil;
    _outgoingPhotoCellIdentifier = nil;
    _outgoingVideoCellIdentifier = nil;
    _outgoingAudioCellIdentifier = nil;
    _incomingCellIdentifier = nil;
    _incomingPhotoCellIdentifier = nil;
    _incomingVideoCellIdentifier = nil;
    _incomingAudioCellIdentifier = nil;
    
    [_keyboardController endListeningForKeyboard];
    _keyboardController = nil;
}

#pragma mark - Setters

- (void)setShowTypingIndicator:(BOOL)showTypingIndicator
{
    if (_showTypingIndicator == showTypingIndicator) {
        return;
    }
    
    _showTypingIndicator = showTypingIndicator;
    
    [self.collectionView.collectionViewLayout invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
    [self scrollToBottomAnimated:YES];
}

- (void)setShowLoadEarlierMessagesHeader:(BOOL)showLoadEarlierMessagesHeader
{
    if (_showLoadEarlierMessagesHeader == showLoadEarlierMessagesHeader) {
        return;
    }
    
    _showLoadEarlierMessagesHeader = showLoadEarlierMessagesHeader;
    
    [self.collectionView.collectionViewLayout invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[NSBundle mainBundle] loadNibNamed:NSStringFromClass([JSQMessagesViewController class])
                                  owner:self
                                options:nil];
    [self jsq_configureMessagesViewController];
    [self jsq_registerForNotifications:YES];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.view layoutIfNeeded];
    [self.collectionView.collectionViewLayout invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
    
    if (self.automaticallyScrollsToMostRecentMessage) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self scrollToBottomAnimated:NO];
            [self.collectionView.collectionViewLayout invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
        });
    }
    
    [self jsq_updateKeyboardTriggerPoint];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self jsq_addObservers];
    [self jsq_addActionToInteractivePopGestureRecognizer:YES];
    [self.keyboardController beginListeningForKeyboard];
    
    self.collectionView.collectionViewLayout.springinessEnabled = YES;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self jsq_addActionToInteractivePopGestureRecognizer:NO];
    self.collectionView.collectionViewLayout.springinessEnabled = NO;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self jsq_removeObservers];
    [self.keyboardController endListeningForKeyboard];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    NSLog(@"MEMORY WARNING: %s", __PRETTY_FUNCTION__);
}

#pragma mark - View rotation

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskAllButUpsideDown;
    }
    return UIInterfaceOrientationMaskAll;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self.collectionView.collectionViewLayout invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
}

#pragma mark - Messages view controller

- (void)didPressSendButton:(UIButton *)button
           withMessageText:(NSString *)text
                    sender:(NSString *)sender
                      date:(NSDate *)date { }

- (void)didPressAccessoryButton:(UIButton *)sender { }

- (void)finishSendingMessage
{
    UITextView *textView = self.inputToolbar.contentView.textView;
    textView.text = nil;
    
    [self.inputToolbar toggleSendButtonEnabled];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:UITextViewTextDidChangeNotification object:textView];
    
    [self jsq_finishSendingOrReceivingMessage];
}

- (void)finishReceivingMessage
{
    [self jsq_finishSendingOrReceivingMessage];
}

- (void)jsq_finishSendingOrReceivingMessage
{
    self.showTypingIndicator = NO;
    
    [self.collectionView reloadData];
    
    if (self.automaticallyScrollsToMostRecentMessage) {
        [self scrollToBottomAnimated:YES];
    }
}

- (void)scrollToBottomAnimated:(BOOL)animated
{
    if ([self.collectionView numberOfSections] == 0) {
        return;
    }
    
    NSInteger items = [self.collectionView numberOfItemsInSection:0];
    
    if (items > 0) {
        [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:items - 1 inSection:0]
                                    atScrollPosition:UICollectionViewScrollPositionTop
                                            animated:animated];
    }
}

#pragma mark - JSQMessages collection view data source

- (id<JSQMessageData>)collectionView:(JSQMessagesCollectionView *)collectionView messageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSAssert(NO, @"ERROR: required method not implemented: %s", __PRETTY_FUNCTION__);
    return nil;
}

- (UIImageView *)collectionView:(JSQMessagesCollectionView *)collectionView bubbleImageViewForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSAssert(NO, @"ERROR: required method not implemented: %s", __PRETTY_FUNCTION__);
    return nil;
}

- (UIImageView *)collectionView:(JSQMessagesCollectionView *)collectionView avatarImageViewForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSAssert(NO, @"ERROR: required method not implemented: %s", __PRETTY_FUNCTION__);
    return nil;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
  wantsThumbnailForURL:(NSURL *)url
mediaImageViewForItemAtIndexPath:(NSIndexPath *)indexPath
       completionBlock:(JSQMessagesCollectionViewDataSourceCompletionBlock)completionBlock {};


#pragma mark - CollectionView Message Configure Helper

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
handlePhotoMessageWithMessageData:(id<JSQMessageData>)messageData
    collectionViewCell:(JSQMessagesCollectionViewCell *)cell
         cellIndexPath:(NSIndexPath *)indexPath isOutgoingMessage:(BOOL)isOutgoingMessage
{
    UIImageView *mediaImageView = nil;
    
    if (isOutgoingMessage) {
        JSQMessagesCollectionViewCellOutgoingPhoto *outgoingPhotoCell = (JSQMessagesCollectionViewCellOutgoingPhoto *)cell;
        mediaImageView = outgoingPhotoCell.mediaImageView;
    }
    else {
        JSQMessagesCollectionViewCellIncomingPhoto *incomingPhotoCell = (JSQMessagesCollectionViewCellIncomingPhoto *)cell;
        mediaImageView = incomingPhotoCell.mediaImageView;
    }
    
    switch ([messageData type]) {
        case JSQMessagePhoto:
        {
            NSParameterAssert([messageData data] != nil);
            UIImage *image = [UIImage imageWithData:[messageData data]];
            mediaImageView.image = image;
        }
            break;
            
        case JSQMessageRemotePhoto:
        {
            if ([messageData data]) {
                UIImage *thumbnail = [UIImage imageWithData:[messageData data]];
                JSQMessagesCollectionViewCellAnimateDisplayBlock(mediaImageView, thumbnail, 0);
            }
            else {
                NSParameterAssert([messageData url] != nil);
                
                if ([messageData thumbnail]) {
                    UIImage *placeholde = [messageData thumbnail];
                    mediaImageView.image = placeholde;
                }
                
                [collectionView.dataSource collectionView:collectionView
                                     wantsThumbnailForURL:[messageData url]
                         mediaImageViewForItemAtIndexPath:indexPath completionBlock:^(UIImage *thumbnail) {
                             JSQMessagesCollectionViewCellAnimateDisplayBlock(mediaImageView, thumbnail, .3f);
                         }];
            }
        }
            break;
        case JSQMessageText:
        case JSQMessageVideo:
        case JSQMessageAudio:
        case JSQMessageRemoteVideo:
        case JSQMessageRemoteAudio:
            NSAssert(NO, @"ERROR: Pass in invalid message type [%d] to method: %s", [messageData type], __PRETTY_FUNCTION__);
            break;
            
    }
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
handleVideoMessageWithMessageData:(id<JSQMessageData>)messageData
    collectionViewCell:(JSQMessagesCollectionViewCell *)cell
         cellIndexPath:(NSIndexPath *)indexPath isOutgoingMessage:(BOOL)isOutgoingMessage
{
    UIImageView *mediaImageView = nil;
    
    if (isOutgoingMessage) {
        JSQMessagesCollectionViewCellOutgoingVideo *outgoingVideoCell = (JSQMessagesCollectionViewCellOutgoingVideo *)cell;
        mediaImageView = outgoingVideoCell.mediaImageView;
    }
    else {
        JSQMessagesCollectionViewCellIncomingVideo *incomingVideoCell = (JSQMessagesCollectionViewCellIncomingVideo *)cell;
        mediaImageView = incomingVideoCell.mediaImageView;
    }
    
    switch ([messageData type]) {
    case JSQMessageVideo:
        {
            NSParameterAssert([messageData thumbnail] != nil);
            mediaImageView.image = [messageData thumbnail];
        }
        break;
            
    case JSQMessageRemoteVideo:
        {
            NSParameterAssert([messageData videoThumbnailPlaceholder] != nil || [messageData thumbnail] != nil);
            
            if ([messageData thumbnail]) {
                mediaImageView.image = [messageData thumbnail];
            }
            else {
                NSParameterAssert([messageData url] != nil);
                
                mediaImageView.image = [messageData videoThumbnailPlaceholder];
                
                [collectionView.dataSource collectionView:collectionView
                                     wantsThumbnailForURL:[messageData url]
                         mediaImageViewForItemAtIndexPath:indexPath completionBlock:^(UIImage *thumbnail) {
                             JSQMessagesCollectionViewCellAnimateDisplayBlock(mediaImageView, thumbnail, .3f);
                         }];
            }
        }
        break;
            
    case JSQMessageText:
    case JSQMessageAudio:
    case JSQMessagePhoto:
    case JSQMessageRemoteAudio:
    case JSQMessageRemotePhoto:
            NSAssert(NO, @"ERROR: Pass in invalid message type [%d] to method: %s", [messageData type], __PRETTY_FUNCTION__);
            break;
    }
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
handleAudioMessageWithMessageData:(id<JSQMessageData>)messageData
    collectionViewCell:(JSQMessagesCollectionViewCell *)cell
         cellIndexPath:(NSIndexPath *)indexPath isOutgoingMessage:(BOOL)isOutgoingMessage
{
    
    switch ([messageData type]) {
        case JSQMessageAudio:
            
            break;
        
        case JSQMessageRemoteAudio:
            
            break;
            
        case JSQMessageText:
        case JSQMessagePhoto:
        case JSQMessageVideo:
        case JSQMessageRemotePhoto:
        case JSQMessageRemoteVideo:
            NSAssert(NO, @"ERROR: Pass in invalid message type [%d] to method: %s", [messageData type], __PRETTY_FUNCTION__);
            break;
    }
}

#pragma mark - Collection view data source

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return 0;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (UICollectionViewCell *)collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    id<JSQMessageData> messageData = [collectionView.dataSource collectionView:collectionView messageDataForItemAtIndexPath:indexPath];
    NSParameterAssert(messageData != nil);
    
    NSString *messageSender = [messageData sender];
    NSParameterAssert(messageSender != nil);
    
    BOOL isOutgoingMessage = [messageSender isEqualToString:self.sender];
    NSString *cellIdentifier = nil;
    JSQMessageType messageType = [messageData type];

    switch (messageType) {
        case JSQMessageText:
            cellIdentifier = isOutgoingMessage ? self.outgoingCellIdentifier : self.incomingCellIdentifier;
            break;
        case JSQMessagePhoto:
        case JSQMessageRemotePhoto:
            cellIdentifier = isOutgoingMessage ? self.outgoingPhotoCellIdentifier : self.incomingPhotoCellIdentifier;
            break;
        case JSQMessageVideo:
        case JSQMessageRemoteVideo:
            cellIdentifier = isOutgoingMessage ? self.outgoingVideoCellIdentifier : self.incomingVideoCellIdentifier;
            break;
        case JSQMessageAudio:
        case JSQMessageRemoteAudio:
            cellIdentifier = isOutgoingMessage ? self.outgoingAudioCellIdentifier : self.incomingAudioCellIdentifier;
            break;
    }
    
    JSQMessagesCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:cellIdentifier forIndexPath:indexPath];
    cell.backgroundColor = [UIColor clearColor];
    cell.delegate = self;
    cell.messageBubbleImageView = [collectionView.dataSource collectionView:collectionView bubbleImageViewForItemAtIndexPath:indexPath];
    cell.avatarImageView = [collectionView.dataSource collectionView:collectionView avatarImageViewForItemAtIndexPath:indexPath];
    cell.cellTopLabel.attributedText = [collectionView.dataSource collectionView:collectionView attributedTextForCellTopLabelAtIndexPath:indexPath];
    cell.messageBubbleTopLabel.attributedText = [collectionView.dataSource collectionView:collectionView attributedTextForMessageBubbleTopLabelAtIndexPath:indexPath];
    cell.cellBottomLabel.attributedText = [collectionView.dataSource collectionView:collectionView attributedTextForCellBottomLabelAtIndexPath:indexPath];
    
    CGFloat bubbleTopLabelInset = 60.0f;
    
    if (isOutgoingMessage) {
        cell.messageBubbleTopLabel.textInsets = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, bubbleTopLabelInset);
        cell.avatarImageView.bounds = CGRectMake(CGRectGetMinX(cell.avatarImageView.bounds),
                                                 CGRectGetMinY(cell.avatarImageView.bounds),
                                                 collectionView.collectionViewLayout.outgoingAvatarViewSize.width,
                                                 collectionView.collectionViewLayout.outgoingAvatarViewSize.height);

    }
    else {
        cell.messageBubbleTopLabel.textInsets = UIEdgeInsetsMake(0.0f, bubbleTopLabelInset, 0.0f, 0.0f);
        cell.avatarImageView.bounds = CGRectMake(CGRectGetMinX(cell.avatarImageView.bounds),
                                                 CGRectGetMinY(cell.avatarImageView.bounds),
                                                 collectionView.collectionViewLayout.incomingAvatarViewSize.width,
                                                 collectionView.collectionViewLayout.incomingAvatarViewSize.height);
    }
    
    switch (messageType) {
        case JSQMessageText:
        {
            NSString *messageText = [messageData text];
            NSParameterAssert(messageText != nil);
            
            cell.textView.text = messageText;
            cell.textView.dataDetectorTypes = UIDataDetectorTypeAll;
        }
            break;
            
        case JSQMessagePhoto:
        case JSQMessageRemotePhoto:
            [self collectionView:collectionView handlePhotoMessageWithMessageData:messageData collectionViewCell:cell cellIndexPath:indexPath isOutgoingMessage:isOutgoingMessage];
            break;
            
        case JSQMessageVideo:
        case JSQMessageRemoteVideo:
            [self collectionView:collectionView handleVideoMessageWithMessageData:messageData collectionViewCell:cell cellIndexPath:indexPath isOutgoingMessage:isOutgoingMessage];
            break;
            
        case JSQMessageAudio:
        case JSQMessageRemoteAudio:
            [self collectionView:collectionView handleAudioMessageWithMessageData:messageData collectionViewCell:cell cellIndexPath:indexPath isOutgoingMessage:isOutgoingMessage];
            break;
    }
    
    return cell;
}

- (UICollectionReusableView *)collectionView:(JSQMessagesCollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath
{
    if (self.showTypingIndicator && [kind isEqualToString:UICollectionElementKindSectionFooter]) {
        return [collectionView dequeueTypingIndicatorFooterViewIncoming:YES
                                                     withIndicatorColor:[self.typingIndicatorColor jsq_colorByDarkeningColorWithValue:0.3f]
                                                            bubbleColor:self.typingIndicatorColor
                                                           forIndexPath:indexPath];
    }
    else if (self.showLoadEarlierMessagesHeader && [kind isEqualToString:UICollectionElementKindSectionHeader]) {
        return [collectionView dequeueLoadEarlierMessagesViewHeaderForIndexPath:indexPath];
    }
    
    return nil;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section
{
    if (!self.showTypingIndicator) {
        return CGSizeZero;
    }
    
    return CGSizeMake([collectionViewLayout itemWidth], kJSQMessagesTypingIndicatorFooterViewHeight);
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
    if (!self.showLoadEarlierMessagesHeader) {
        return CGSizeZero;
    }
    
    return CGSizeMake([collectionViewLayout itemWidth], kJSQMessagesLoadEarlierHeaderViewHeight);
}

#pragma mark - Collection view delegate

- (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

#pragma mark - Collection view delegate flow layout

- (CGSize)collectionView:(JSQMessagesCollectionView *)collectionView
                  layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGSize bubbleSize = [collectionViewLayout messageBubbleSizeForItemAtIndexPath:indexPath];
    
    CGFloat cellHeight = bubbleSize.height;
    cellHeight += [self collectionView:collectionView layout:collectionViewLayout heightForCellTopLabelAtIndexPath:indexPath];
    cellHeight += [self collectionView:collectionView layout:collectionViewLayout heightForMessageBubbleTopLabelAtIndexPath:indexPath];
    cellHeight += [self collectionView:collectionView layout:collectionViewLayout heightForCellBottomLabelAtIndexPath:indexPath];
    
    return CGSizeMake(collectionViewLayout.itemWidth, cellHeight);
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return 0.0f;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return 0.0f;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return 0.0f;
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
 didTapAvatarImageView:(UIImageView *)avatarImageView
           atIndexPath:(NSIndexPath *)indexPath { }

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
      didTapMediaPhoto:(UIImageView *)imageView
           atIndexPath:(NSIndexPath *)indexPath {}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
didTapMediaVideoForURL:(NSURL *)videoURL
           atIndexPath:(NSIndexPath *)indexPath {}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
      didTapMediaAudio:(NSData *)audioData
           atIndexPath:(NSIndexPath *)indexPath {}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
didTapMediaAudioForURL:(NSURL *)audioURL
           atIndexPath:(NSIndexPath *)indexPath {}

#pragma mark - Messages collection view cell delegate

- (void)messagesCollectionViewCellDidTapAvatar:(JSQMessagesCollectionViewCell *)cell
{
    [self.collectionView.delegate collectionView:self.collectionView
                           didTapAvatarImageView:cell.avatarImageView
                                     atIndexPath:[self.collectionView indexPathForCell:cell]];
}

- (void)messagesCollectionViewCellDidTapMediaPhoto:(JSQMessagesCollectionViewCell *)cell
{
    UIImageView *imageView = nil;
    if ([cell isMemberOfClass:[JSQMessagesCollectionViewCellOutgoingPhoto class]]) {
        imageView = [(JSQMessagesCollectionViewCellOutgoingPhoto *)cell mediaImageView];
    }
    else {
        imageView = [(JSQMessagesCollectionViewCellIncomingPhoto *)cell mediaImageView];
    }
    
    [self.collectionView.delegate collectionView:self.collectionView
                                didTapMediaPhoto:imageView
                                     atIndexPath:[self.collectionView indexPathForCell:cell]];
}

- (void)messagesCollectionViewCellDidTapMediaVideo:(JSQMessagesCollectionViewCell *)cell
{
    id<JSQMessageData> messageData = [self.collectionView.dataSource collectionView:self.collectionView
                                                      messageDataForItemAtIndexPath:[self.collectionView indexPathForCell:cell]];
    [self.collectionView.delegate collectionView:self.collectionView
                          didTapMediaVideoForURL:[messageData url]
                                     atIndexPath:[self.collectionView indexPathForCell:cell]];
}

- (void)messagesCollectionViewCellDidTapMediaAudio:(JSQMessagesCollectionViewCell *)cell
{
    id<JSQMessageData> messageData = [self.collectionView.dataSource collectionView:self.collectionView
                                                      messageDataForItemAtIndexPath:[self.collectionView indexPathForCell:cell]];
    if ([messageData data]) {
        [self.collectionView.delegate collectionView:self.collectionView
                                    didTapMediaAudio:[messageData data]
                                         atIndexPath:[self.collectionView indexPathForCell:cell]];
    }
    else {
        [self.collectionView.delegate collectionView:self.collectionView
                              didTapMediaAudioForURL:[messageData url]
                                         atIndexPath:[self.collectionView indexPathForCell:cell]];
    }
}


#pragma mark - Input toolbar delegate

- (void)messagesInputToolbar:(JSQMessagesInputToolbar *)toolbar didPressLeftBarButton:(UIButton *)sender
{
    if (toolbar.sendButtonOnRight) {
        [self didPressAccessoryButton:sender];
    }
    else {
        [self didPressSendButton:sender
                 withMessageText:[self jsq_currentlyComposedMessageText]
                          sender:self.sender
                            date:[NSDate date]];
    }
}

- (void)messagesInputToolbar:(JSQMessagesInputToolbar *)toolbar didPressRightBarButton:(UIButton *)sender
{
    if (toolbar.sendButtonOnRight) {
        [self didPressSendButton:sender
                 withMessageText:[self jsq_currentlyComposedMessageText]
                          sender:self.sender
                            date:[NSDate date]];
    }
    else {
        [self didPressAccessoryButton:sender];
    }
}

- (NSString *)jsq_currentlyComposedMessageText
{
    //  add a space to accept any auto-correct suggestions
    NSString *text = self.inputToolbar.contentView.textView.text;
    self.inputToolbar.contentView.textView.text = [text stringByAppendingString:@" "];
    return [self.inputToolbar.contentView.textView.text jsq_stringByTrimingWhitespace];
}

#pragma mark - Text view delegate

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    [textView becomeFirstResponder];
    
    if (self.automaticallyScrollsToMostRecentMessage) {
        [self scrollToBottomAnimated:YES];
    }
}

- (void)textViewDidChange:(UITextView *)textView
{
    [self.inputToolbar toggleSendButtonEnabled];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    [textView resignFirstResponder];
}

#pragma mark - Notifications

- (void)jsq_handleDidChangeStatusBarFrameNotification:(NSNotification *)notification
{
    CGRect previousStatusBarFrame = [[[notification userInfo] objectForKey:UIApplicationStatusBarFrameUserInfoKey] CGRectValue];
    CGRect currentStatusBarFrame = [UIApplication sharedApplication].statusBarFrame;
    CGFloat statusBarHeightDelta = CGRectGetHeight(currentStatusBarFrame) - CGRectGetHeight(previousStatusBarFrame);
    self.statusBarChangeInHeight = MAX(statusBarHeightDelta, 0.0f);
    
    if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
        self.statusBarChangeInHeight = 0.0f;
    }
}

#pragma mark - Key-value observing

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == kJSQMessagesKeyValueObservingContext) {
        
        if (object == self.inputToolbar.contentView.textView
            && [keyPath isEqualToString:NSStringFromSelector(@selector(contentSize))]) {
            
            CGSize oldContentSize = [[change objectForKey:NSKeyValueChangeOldKey] CGSizeValue];
            CGSize newContentSize = [[change objectForKey:NSKeyValueChangeNewKey] CGSizeValue];
            
            CGFloat dy = newContentSize.height - oldContentSize.height;
        
            [self jsq_adjustInputToolbarForComposerTextViewContentSizeChange:dy];
            [self jsq_updateCollectionViewInsets];
            if (self.automaticallyScrollsToMostRecentMessage) {
                [self scrollToBottomAnimated:NO];
            }
        }
    }
}

#pragma mark - Keyboard controller delegate

- (void)keyboardDidChangeFrame:(CGRect)keyboardFrame
{
    CGFloat heightFromBottom = CGRectGetHeight(self.collectionView.frame) - CGRectGetMinY(keyboardFrame);
    
    heightFromBottom = MAX(0.0f, heightFromBottom + self.statusBarChangeInHeight);
    
    [self jsq_setToolbarBottomLayoutGuideConstant:heightFromBottom];
}

- (void)jsq_setToolbarBottomLayoutGuideConstant:(CGFloat)constant
{
    self.toolbarBottomLayoutGuide.constant = constant;
    [self.view setNeedsUpdateConstraints];
    [self.view layoutIfNeeded];
    
    [self jsq_updateCollectionViewInsets];
}

- (void)jsq_updateKeyboardTriggerPoint
{
    self.keyboardController.keyboardTriggerPoint = CGPointMake(0.0f, CGRectGetHeight(self.inputToolbar.bounds));
}

#pragma mark - Gesture recognizers

- (void)jsq_handleInteractivePopGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state) {
        case UIGestureRecognizerStateBegan:
        {
            [self.keyboardController endListeningForKeyboard];
            [self.inputToolbar.contentView.textView resignFirstResponder];
            [UIView animateWithDuration:0.0
                             animations:^{
                                 [self jsq_setToolbarBottomLayoutGuideConstant:0.0f];
                             }];
        }
            break;
        case UIGestureRecognizerStateChanged:
            //  TODO: handle this animation better
            break;
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateFailed:
            [self.keyboardController beginListeningForKeyboard];
            break;
        default:
            break;
    }
}

#pragma mark - Input toolbar utilities

- (BOOL)jsq_inputToolbarHasReachedMaximumHeight
{
    return (CGRectGetMinY(self.inputToolbar.frame) == self.topLayoutGuide.length);
}

- (void)jsq_adjustInputToolbarForComposerTextViewContentSizeChange:(CGFloat)dy
{
    BOOL contentSizeIsIncreasing = (dy > 0);
    
    if ([self jsq_inputToolbarHasReachedMaximumHeight]) {
        BOOL contentOffsetIsPositive = (self.inputToolbar.contentView.textView.contentOffset.y > 0);
        
        if (contentSizeIsIncreasing || contentOffsetIsPositive) {
            [self jsq_scrollComposerTextViewToBottomAnimated:YES];
            return;
        }
    }
    
    CGFloat toolbarOriginY = CGRectGetMinY(self.inputToolbar.frame);
    CGFloat newToolbarOriginY = toolbarOriginY - dy;
    
    //  attempted to increase origin.Y above topLayoutGuide
    if (newToolbarOriginY <= self.topLayoutGuide.length) {
        dy = toolbarOriginY - self.topLayoutGuide.length;
        [self jsq_scrollComposerTextViewToBottomAnimated:YES];
    }
    
    [self jsq_adjustInputToolbarHeightConstraintByDelta:dy];
    
    [self jsq_updateKeyboardTriggerPoint];
    
    if (dy < 0) {
        [self jsq_scrollComposerTextViewToBottomAnimated:NO];
    }
}

- (void)jsq_adjustInputToolbarHeightConstraintByDelta:(CGFloat)dy
{
    self.toolbarHeightConstraint.constant += dy;
    
    if (self.toolbarHeightConstraint.constant < kJSQMessagesInputToolbarHeightDefault) {
        self.toolbarHeightConstraint.constant = kJSQMessagesInputToolbarHeightDefault;
    }
    
    [self.view setNeedsUpdateConstraints];
    [self.view layoutIfNeeded];
}

- (void)jsq_scrollComposerTextViewToBottomAnimated:(BOOL)animated
{
    UITextView *textView = self.inputToolbar.contentView.textView;
    CGPoint contentOffsetToShowLastLine = CGPointMake(0.0f, textView.contentSize.height - CGRectGetHeight(textView.bounds));
    
    if (!animated) {
        textView.contentOffset = contentOffsetToShowLastLine;
        return;
    }
    
    [UIView animateWithDuration:0.01
                          delay:0.01
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
                         textView.contentOffset = contentOffsetToShowLastLine;
                     }
                     completion:nil];
}

#pragma mark - Collection view utilities

- (void)jsq_updateCollectionViewInsets
{
    [self jsq_setCollectionViewInsetsTopValue:self.topLayoutGuide.length
                                  bottomValue:CGRectGetHeight(self.collectionView.frame) - CGRectGetMinY(self.inputToolbar.frame)];
}

- (void)jsq_setCollectionViewInsetsTopValue:(CGFloat)top bottomValue:(CGFloat)bottom
{
    UIEdgeInsets insets = UIEdgeInsetsMake(top, 0.0f, bottom, 0.0f);
    self.collectionView.contentInset = insets;
    self.collectionView.scrollIndicatorInsets = insets;
}

#pragma mark - Utilities

- (void)jsq_addObservers
{
    [self jsq_removeObservers];
    
    [self.inputToolbar.contentView.textView addObserver:self
                                             forKeyPath:NSStringFromSelector(@selector(contentSize))
                                                options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
                                                context:kJSQMessagesKeyValueObservingContext];
}

- (void)jsq_removeObservers
{
    @try {
        [self.inputToolbar.contentView.textView removeObserver:self
                                                    forKeyPath:NSStringFromSelector(@selector(contentSize))
                                                       context:kJSQMessagesKeyValueObservingContext];
    }
    @catch (NSException * __unused exception) { }
}

- (void)jsq_registerForNotifications:(BOOL)registerForNotifications
{
    if (registerForNotifications) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(jsq_handleDidChangeStatusBarFrameNotification:)
                                                     name:UIApplicationDidChangeStatusBarFrameNotification
                                                   object:nil];
    }
    else {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:UIApplicationDidChangeStatusBarFrameNotification
                                                      object:nil];
    }
}

- (void)jsq_addActionToInteractivePopGestureRecognizer:(BOOL)addAction
{
    if (self.navigationController.interactivePopGestureRecognizer) {
        [self.navigationController.interactivePopGestureRecognizer removeTarget:nil
                                                                         action:@selector(jsq_handleInteractivePopGestureRecognizer:)];
        
        if (addAction) {
            [self.navigationController.interactivePopGestureRecognizer addTarget:self
                                                                          action:@selector(jsq_handleInteractivePopGestureRecognizer:)];
        }
    }
}

@end
