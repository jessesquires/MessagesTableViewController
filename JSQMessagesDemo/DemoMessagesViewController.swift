//
//  DemoMessagesViewController.swift
//  JSQMessages
//
//  Created by Raphaël Bellec on 11/08/2015.
//  Copyright (c) 2015 Hexed Bits. All rights reserved.
//

import Foundation
import UIKit



protocol JSQDemoViewControllerDelegate {
    func didDismissJSQDemoViewController( vc : DemoMessagesViewController )
}


class DemoMessagesViewController : JSQMessagesViewController, UIActionSheetDelegate {
    
    var  delegateModal  : JSQDemoViewControllerDelegate?
    var  demoData       : DemoModelData!
    
    
    // ----------------------------------------------------------------------
    // MARK: - View lifecycle
    // ----------------------------------------------------------------------
    
    override func viewDidLoad() {
    
        super.viewDidLoad()
        
        self.title = "JSQMessages"
        
        
        // Load up our fake data for the demo
        self.demoData           = DemoModelData()
        
        // You MUST set your senderId and display name
        self.senderId           = demoData.kJSQDemoAvatarIdSquires
        self.senderDisplayName  = demoData.kJSQDemoAvatarDisplayNameSquires
        
        
        // You can set custom avatar sizes
        if ( !NSUserDefaults.incomingAvatarSetting() ) {
            self.collectionView.collectionViewLayout.incomingAvatarViewSize = CGSizeZero
        }
        
        if ( !NSUserDefaults.outgoingAvatarSetting() ) {
            self.collectionView.collectionViewLayout.outgoingAvatarViewSize = CGSizeZero
        }
        
        self.showLoadEarlierMessagesHeader     = true
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage.jsq_defaultTypingIndicatorImage(),
                                                                 style: UIBarButtonItemStyle.Bordered,
                                                                target: self,
                                                                action: Selector("receiveMessagePressed:") )
        
        /**
        *  Register custom menu actions for cells.
        */
        JSQMessagesCollectionViewCell.registerMenuAction( Selector("customAction:") )
        UIMenuController.sharedMenuController().menuItems = [  UIMenuItem( title: "Custom Action", action: Selector( "customAction:" ) ) ]
        
        
        /**
        *  Customize your toolbar buttons
        *
        *  self.inputToolbar.contentView.leftBarButtonItem = custom button or nil to remove
        *  self.inputToolbar.contentView.rightBarButtonItem = custom button or nil to remove
        */
        
        /**
        *  Set a maximum height for the input toolbar
        *
        *  self.inputToolbar.maximumHeight = 150;
        */
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // Delegate not use here. TODO: see swift 2.0 ways as soon as available.
        if let delegate = self.delegateModal {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Stop, target: self, action: Selector("closePressed:"))
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        /**
        *  Enable/disable springy bubbles, default is NO.
        *  You must set this from `viewDidAppear:`
        *  Note: this feature is mostly stable, but still experimental
        */
        self.collectionView.collectionViewLayout.springinessEnabled = NSUserDefaults.springinessSetting()
    }
    
    // ----------------------------------------------------------------------
    // MARK: - Testing
    // ----------------------------------------------------------------------

    func pushMainViewController() {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let nc = sb.instantiateInitialViewController() as! UINavigationController
        self.navigationController?.pushViewController(nc.topViewController, animated: true)
    }

    // ----------------------------------------------------------------------
    // MARK: - Actions
    // ----------------------------------------------------------------------
    
    func receiveMessagePressed(sender: UIBarButtonItem) {
        
        /**
        *  DEMO ONLY
        *
        *  The following is simply to simulate received messages for the demo.
        *  Do not actually do this.
        */
        
        
        /**
        *  Show the typing indicator to be shown
        */
        self.showTypingIndicator = !self.showTypingIndicator
        
        /**
        *  Scroll to actually view the indicator
        */
        self.scrollToBottomAnimated(true)
        
        /**
        *  Copy last sent message, this will be the new "received" message
        */
//        let msgArray                   = self.demoData.messages
        let lastMessage  : JSQMessage? = self.demoData.messages.last
        var copyMessage  : JSQMessage

        if let lastMessageOk  =  lastMessage {
            copyMessage = lastMessageOk.copy() as! JSQMessage
        } else {
            copyMessage = JSQMessage(senderId: demoData?.kJSQDemoAvatarIdJobs,
                                  displayName: demoData?.kJSQDemoAvatarDisplayNameJobs,
                                         text: "First received!")
        }
        
        /**
        *  Allow typing indicator to show
        */
        let delayInSeconds = 1.5
        
        dispatch_after( dispatch_time( DISPATCH_TIME_NOW, Int64( delayInSeconds * Double(NSEC_PER_SEC) )  )   ,
                        dispatch_get_main_queue() )
            {
                
                // Remove the current user from Array of possible recipients of the message.
                var otherUserIds            = self.demoData.users.keys.array.filter( {$0 != self.senderId;} )
                let randomUserIndex         = Int(arc4random_uniform(UInt32(otherUserIds.count)))
                let randomUserId            = otherUserIds[ randomUserIndex ]
                let userDisplayedName       = self.demoData.users[randomUserId]
                
                
                var newMessage              : JSQMessage?
                var newMediaData            : JSQMessageMediaData?
                var newMediaAttachmentCopy  : AnyObject?
                
                // TODO: use a switch case to match class here.
                if ( copyMessage.isMediaMessage ) {
                    /**
                    *  Last message was a media message
                    */
                    let copyMediaData : JSQMessageMediaData = copyMessage.media;
                    
                    if (       copyMediaData is JSQPhotoMediaItem ) {
                        // TODO: clean these casts !
                        let photoItemCopy : JSQPhotoMediaItem           = (copyMediaData as! JSQPhotoMediaItem).copy()    as! JSQPhotoMediaItem
                        photoItemCopy.appliesMediaViewMaskAsOutgoing    = false
                        newMediaAttachmentCopy                          = UIImage( CGImage: photoItemCopy.image.CGImage )
                        
                        /**
                        *  Set image to nil to simulate "downloading" the image
                        *  and show the placeholder view
                        */
                        photoItemCopy.image = nil
                        
                        newMediaData = photoItemCopy
                    }
                    else if ( copyMediaData is JSQLocationMediaItem ) {
                        let locationItemCopy : JSQLocationMediaItem     = (copyMediaData as! JSQLocationMediaItem).copy() as! JSQLocationMediaItem
                        locationItemCopy.appliesMediaViewMaskAsOutgoing = false
                        newMediaAttachmentCopy                          = locationItemCopy.location.copy()
                        
                        /**
                        *  Set location to nil to simulate "downloading" the location data
                        */
                        locationItemCopy.location                       = nil
                        newMediaData                                    = locationItemCopy
                    }
                    else if ( copyMediaData is JSQVideoMediaItem    ) {
                        let videoItemCopy : JSQVideoMediaItem           = (copyMediaData as! JSQVideoMediaItem).copy()    as! JSQVideoMediaItem
                        videoItemCopy.appliesMediaViewMaskAsOutgoing    = false
                        newMediaAttachmentCopy                          = videoItemCopy.fileURL.copy()
                        
                        /**
                        *  Reset video item to simulate "downloading" the video
                        */
                        videoItemCopy.fileURL                           = nil
                        videoItemCopy.isReadyToPlay                     = false
                        
                        newMediaData                                    = videoItemCopy
                    }
                    else {
                        NSLog("%s error: unrecognized media item, line :%s", __FUNCTION__, __LINE__)
                    }
                    
                    newMessage = JSQMessage( senderId: randomUserId,   displayName: userDisplayedName,    media: newMediaData)
                    
                }
                else {
                    /**
                    *  Last message was a text message
                    */
                    newMessage = JSQMessage( senderId: randomUserId,   displayName:userDisplayedName,      text: copyMessage.text)
                }
                
                
                
                /**
                *  Upon receiving a message, you should:
                *
                *  1. Play sound (optional)
                *  2. Add new id<JSQMessageData> object to your data source
                *  3. Call `finishReceivingMessage`
                */
                JSQSystemSoundPlayer.jsq_playMessageReceivedSound()
                self.demoData.messages.append(newMessage!)              // Error if newMessage is nil.
                self.finishReceivingMessageAnimated(true)
                
                //-------- Use swift 2. Note : nil chek here is useless if the case is not handled for above "newMessage!"
                if let msg = newMessage where msg.isMediaMessage {
                    /**
                    *  Simulate "downloading" media
                    */
                    let fake_downloading_delay = 2.0
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64( fake_downloading_delay * Double(NSEC_PER_SEC) )), dispatch_get_main_queue()) {
                        /**
                        *  Media is "finished downloading", re-display visible cells
                        *
                        *  If media cell is not visible, the next time it is dequeued the view controller will display its new attachment data
                        *
                        *  Reload the specific item, or simply call `reloadData`
                        */
                        
                        if        newMediaData is JSQPhotoMediaItem     {
                            let photoMediaItem           = newMediaData as! JSQPhotoMediaItem
                            photoMediaItem.image         = newMediaAttachmentCopy  as! UIImage
                            self.collectionView.reloadData()
                        }
                        else if   newMediaData is JSQLocationMediaItem  {
                            let locationMediatItem       = newMediaData as! JSQLocationMediaItem
                            locationMediatItem.setLocation( newMediaAttachmentCopy as! CLLocation , withCompletionHandler:{ self.collectionView.reloadData() } )
                        }
                        else if   newMediaData is JSQVideoMediaItem     {
                            let videoMediaItem           = newMediaData as! JSQVideoMediaItem
                            videoMediaItem.fileURL       = newMediaAttachmentCopy  as! NSURL
                            videoMediaItem.isReadyToPlay = true
                            self.collectionView.reloadData()
                        }
                        else {
                            NSLog("%s error: unrecognized media item, line :%s", __FUNCTION__, __LINE__)
                        }
                        
                    }
                }
                
        }
    }
    
    func closePressed(sender : UIBarButtonItem ){
        self.delegateModal?.didDismissJSQDemoViewController(self)
    }

    
    
    // ----------------------------------------------------------------------
    // MARK: - JSQMessagesViewController method overrides
    // ----------------------------------------------------------------------
    
    override func didPressSendButton(button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: NSDate!) {
    
        /**
        *  Sending a message. Your implementation of this method should do *at least* the following:
        *
        *  1. Play sound (optional)
        *  2. Add new id<JSQMessageData> object to your data source
        *  3. Call `finishSendingMessage`
        */
        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        
        let message : JSQMessage = JSQMessage(    senderId: senderId         ,
                                        senderDisplayName: senderDisplayName,
                                                     date: date             ,
                                                     text: text)
        self.demoData.messages.append(message)
        
        self.finishSendingMessageAnimated(true)
    }
    
    override func didPressAccessoryButton( sender : UIButton ) {
        let  sheet : UIActionSheet = UIActionSheet(title: "Media messages"  ,
                                                delegate: self              ,
                                       cancelButtonTitle: "Cancel"          ,
                                  destructiveButtonTitle: nil               ,
                                       otherButtonTitles: "Send photo", "Send location", "Send video")
        
        
        sheet.showFromToolbar(self.inputToolbar)
    }

    
    
    
    
    
    
    
}