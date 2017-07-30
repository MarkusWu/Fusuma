//
//  FSAlbumView.swift
//  Fusuma
//
//  Created by Yuta Akizuki on 2015/11/14.
//  Copyright © 2015年 ytakzk. All rights reserved.
//

import UIKit
import Photos

@objc public protocol FSAlbumViewDelegate: class {
    // Returns height ratio of crop image. e.g) 4:3 -> 7.5
    func getCropHeightRatio() -> CGFloat
    
    func albumViewCameraRollUnauthorized()
    func albumViewCameraRollAuthorized()
    
    func albumViewAddingText(_ flag: Bool)
}

final class FSAlbumView: UIView, UICollectionViewDataSource, UICollectionViewDelegate, PHPhotoLibraryChangeObserver, UIGestureRecognizerDelegate, UITextViewDelegate {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var imageCropOverlay: UIView!
    @IBOutlet weak var imageCropView: FSImageCropView!
    @IBOutlet weak var imageCropViewContainer: UIView!
    
    @IBOutlet weak var brightnessSlider: UISlider!
    @IBOutlet weak var brightnessLessButton: UIButton!
    @IBOutlet weak var brightnessMoreButton: UIButton!
    
    @IBOutlet weak var fontSizeSlider: UISlider!
    @IBOutlet weak var fontSizeLessButton: UIButton!
    @IBOutlet weak var fontSizeMoreButton: UIButton!
    
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var clearTextButton: UIButton!
    @IBOutlet weak var addTextButton: UIButton!
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var textViewOverlay: UIView!
    
    @IBOutlet weak var textAlphaContainer: UIView!
    @IBOutlet weak var textAlphaSlider: UISlider!
    
    lazy var textColorSelectorView = ColorSelectorView.instance()
    
    var textAlpha: CGFloat {
        return CGFloat(self.textAlphaSlider.value * 0.5) + 0.5
    }
    
    @IBOutlet var iPadInactiveConstraints: [NSLayoutConstraint]!
    
    var textViewOrigin: CGPoint?
    
    @IBOutlet weak var collectionViewConstraintHeight: NSLayoutConstraint!
    @IBOutlet weak var imageCropViewConstraintTop: NSLayoutConstraint!
    
    weak var delegate: FSAlbumViewDelegate? = nil
    
    var images: PHFetchResult<PHAsset>!
    var imageManager: PHCachingImageManager?
    var previousPreheatRect: CGRect = .zero
    let cellSize = CGSize(width: 100, height: 100)
    var phAsset: PHAsset!
    
    var canPanDuringThisTouch = true
    
    var addingText: Bool = false {
        didSet {
            
            var origin = CGPoint.zero
            origin.x = (self.imageCropViewContainer.frame.width - self.textView.frame.width) / 2
            origin.y = self.imageCropViewContainer.frame.height * 0.20
            
            if self.addingText {
                
                self.textViewOverlay.isHidden = false
                self.textView.isHidden = false
                
                self.panOnTextView.isEnabled = false
                
                UIView.animate(withDuration: 0.3, animations: {
                    self.textView.frame.origin = origin
                }, completion: {
                    finished in
                    self.updateTextViewLayoutIfNeeded()
                })
                
                self.cropImageContainerNormalPosition()
                
            } else {
                
                self.textView.text = (self.textView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                
                self.updateTextViewLayoutIfNeeded(false)
                
                self.textViewOverlay.isHidden = true
                
                if self.textView.text == nil || self.textView.text.isEmpty {
                    self.textView.isHidden = true
                } else {
                    self.textView.isHidden = false
                }
                
                self.panOnTextView.isEnabled = true
                
                if let pos = self.textViewOrigin {
                    
                    UIView.animate(withDuration: 0.3, animations: {
                        finished in
                        self.textView.frame.origin = pos
                    })
                } else {
                    self.textView.frame.origin = origin
                }
            }
            
            self.hideEditOptions(self.addingText)
            self.imageCropOverlay.isHidden = self.addingText
            self.delegate?.albumViewAddingText(self.addingText)
        }
    }
    
    // Variables for calculating the position
    enum Direction {
        case scroll
        case stop
        case up
        case down
    }
    let imageCropViewOriginalConstraintTop: CGFloat = 60
    let imageCropViewMinimalVisibleHeight: CGFloat  = 100
    var dragDirection = Direction.up
    var imaginaryCollectionViewOffsetStartPosY: CGFloat = 0.0
    
    var cropBottomY: CGFloat  = 0.0
    var dragStartPos: CGPoint = CGPoint.zero
    let dragDiff: CGFloat     = 20.0
    
    private(set) var tapOnImageCropContainer: UITapGestureRecognizer!
    private(set) var doubleTappedOnImageCropContainer: UITapGestureRecognizer!
    
    private(set) var panOnTextView: UIPanGestureRecognizer!
    
    static func instance() -> FSAlbumView {
        
        return UINib(nibName: "FSAlbumView", bundle: Bundle(for: self.classForCoder())).instantiate(withOwner: self, options: nil)[0] as! FSAlbumView
    }
    
    func initialize() {
        
        if images != nil {
            
            return
        }
        
        self.isHidden = false
        
        // Set Image Crop Ratio
        if let heightRatio = delegate?.getCropHeightRatio() {
            imageCropViewContainer.addConstraint(NSLayoutConstraint(item: imageCropViewContainer, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: imageCropViewContainer, attribute: NSLayoutAttribute.width, multiplier: heightRatio, constant: 0)
            )
            layoutSubviews()
        }
        
        let panGesture      = UIPanGestureRecognizer(target: self, action: #selector(FSAlbumView.panned(_:)))
        panGesture.delegate = self
        self.addGestureRecognizer(panGesture)
        
        tapOnImageCropContainer = UITapGestureRecognizer(target: self, action: #selector(self.imageCropContainerTapped(_:)))
        self.imageCropViewContainer.addGestureRecognizer(tapOnImageCropContainer)
        
        doubleTappedOnImageCropContainer = UITapGestureRecognizer(target: self, action: #selector(self.doubleTappedImageCropContainer(_:)))
        doubleTappedOnImageCropContainer.numberOfTapsRequired = 2
        self.imageCropViewContainer.addGestureRecognizer(doubleTappedOnImageCropContainer)
        
        if self.imageCropOverlay.isHidden {
            tapOnImageCropContainer.isEnabled = false
            doubleTappedOnImageCropContainer.isEnabled = true
        } else {
            tapOnImageCropContainer.isEnabled = true
            doubleTappedOnImageCropContainer.isEnabled = false
        }
        
        panOnTextView = UIPanGestureRecognizer(target: self, action: #selector(self.textViewPanned(_:)))
        self.textView.addGestureRecognizer(panOnTextView)
        
        collectionViewConstraintHeight.constant = self.frame.height - imageCropViewContainer.frame.height - imageCropViewOriginalConstraintTop
        imageCropViewConstraintTop.constant = 60
        dragDirection = Direction.up
        
        imageCropViewContainer.layer.shadowColor   = UIColor.black.cgColor
        imageCropViewContainer.layer.shadowRadius  = 30.0
        imageCropViewContainer.layer.shadowOpacity = 0.9
        imageCropViewContainer.layer.shadowOffset  = CGSize.zero
        
        collectionView.register(UINib(nibName: "FSAlbumViewCell", bundle: Bundle(for: self.classForCoder)), forCellWithReuseIdentifier: "FSAlbumViewCell")
        collectionView.backgroundColor = fusumaBackgroundColor
        
        // Never load photos Unless the user allows to access to photo album
        checkPhotoAuth()
        
        // Sorting condition
        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        
        images = PHAsset.fetchAssets(with: .image, options: options)
        
        self.selectImage(at: 0)
        
        PHPhotoLibrary.shared().register(self)
        
        self.textView.text = ""
        self.updateTextViewLayoutIfNeeded()
        
        self.brightnessSlider.tintColor = fusumaTintColor
        self.brightnessSlider.value = fusumaImageOverlayBrightness
        
        
        // make sure min, initial and max font size are valid
        if fusumaMinFontSize > fusumaMaxFontSize {
            swap(&fusumaMinFontSize, &fusumaMaxFontSize)
        } else if fusumaMinFontSize == fusumaMaxFontSize {
            fusumaMaxFontSize = fusumaMinFontSize + 10
        }
        
        if fusumaInitialFontSize < fusumaMinFontSize || fusumaInitialFontSize > fusumaMaxFontSize {
            fusumaInitialFontSize = fusumaMinFontSize
        }
        
        let interval = fusumaMaxFontSize - fusumaMinFontSize
        
        let per = min((fusumaInitialFontSize - fusumaMinFontSize) / interval, 1.0)
        self.fontSizeSlider.value = per
        
        self.fontSizeSlider.tintColor = fusumaTintColor
        self.textView.font = self.textView.font?.withSize(CGFloat(fusumaInitialFontSize))
        
        
        self.imageCropOverlay.backgroundColor = UIColor.black.withAlphaComponent(CGFloat(1 - fusumaImageOverlayBrightness))
        
        self.textView.delegate = self
        
        if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad {
            for c in self.iPadInactiveConstraints {
                c.isActive = false
            }
        }
        
        let y = UIScreen.main.bounds.height - 35
        let width = UIScreen.main.bounds.width
        
        self.textColorSelectorView.alpha = 0.0
        
        self.textColorSelectorView.delegate = self
        
        self.addSubview(textColorSelectorView)
        
        let rect = CGRect(x: 0, y: y, width: width, height: 35)
        self.textColorSelectorView.initialize(frame: rect, colors: fusumaTextColors, selectedIndex: 0, colorButtonWidth: 25)
    }
    
    deinit {
        
        if PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.authorized {
            
            PHPhotoLibrary.shared().unregisterChangeObserver(self)
        }
    }
    
    func hidePhotoEditor(_ hide: Bool) {
        
        self.hideEditOptions(hide)
        self.imageCropOverlay.isHidden = hide
        self.textView.isHidden = hide
        
        // make sure the gesture is initiated
        if self.tapOnImageCropContainer != nil {
            if hide {
                self.tapOnImageCropContainer.isEnabled = false
                self.doubleTappedOnImageCropContainer.isEnabled = true
            } else {
                self.tapOnImageCropContainer.isEnabled = true
                self.doubleTappedOnImageCropContainer.isEnabled = false
            }
        }
    }
    
    func updateTextViewLayoutIfNeeded(_ updateXCoord: Bool = true) {
        
        self.textView.frame.size.width = min(self.textView.attributedText.size().width + 20, self.frame.width - 32)
        
        if updateXCoord {
            self.textView.frame.origin.x = (self.imageCropViewContainer.frame.width - self.textView.frame.width) / 2
        }
        
        var verticalPadding: CGFloat = 0
        
        if self.addingText {
            verticalPadding = 30
        }
        
        var height = max(self.textView.contentSize.height + verticalPadding, 30)
        
        if self.addingText {
            height = min(160, height)
        }
        
        self.textView.frame.size.height = height
        
        // centeralize text vertically, but work when textview in editmode only
//        if height < 160 {
//            let topCorrection = (self.textView.bounds.height - self.textView.contentSize.height * self.textView.zoomScale) / 2.0
//            self.textView.contentOffset = CGPoint(x: 0, y: -topCorrection)
//        }
    }
    
    func selectImage(at indexNumber: Int) {
        if images.count > indexNumber {
            
            for indexPath in collectionView.indexPathsForSelectedItems ?? [] {
                collectionView.deselectItem(at: indexPath, animated: false)
            }
            
            changeImage(images[indexNumber])
            collectionView.reloadData()
            
            self.cropImageContainerNormalPosition()
            
            collectionView.selectItem(at: IndexPath(row: indexNumber, section: 0), animated: false, scrollPosition: .top)
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        return true
    }
    
    func doubleTappedImageCropContainer(_ gr: UITapGestureRecognizer) {
        if gr.state == .ended {
            if let asset = self.phAsset {
                self.changeImage(asset)
            }
        }
    }
    
    func panned(_ sender: UITapGestureRecognizer) {
        
        if sender.state == UIGestureRecognizerState.began {
            
            let view    = sender.view
            let loc     = sender.location(in: view)
            let subview = view?.hitTest(loc, with: nil)
            
            dragStartPos = sender.location(in: self)
            
            cropBottomY = self.imageCropViewContainer.frame.origin.y + self.imageCropViewContainer.frame.height
            
            if subview == imageCropView && imageCropViewConstraintTop.constant == imageCropViewOriginalConstraintTop {
                // if the pan starts in the image field, don't let this touch start dragging the album, since it's a crop gesture
                
                if abs(dragStartPos.y - cropBottomY) < 20 {
                    canPanDuringThisTouch = true
                } else {
                    canPanDuringThisTouch = false
                }
                
                
                return
            }
            
            // Move
            if dragDirection == Direction.stop {
                
                dragDirection = (imageCropViewConstraintTop.constant == imageCropViewOriginalConstraintTop) ? Direction.up : Direction.down
            }
            
            // Scroll event of CollectionView is preferred.
            if (dragDirection == Direction.up   && dragStartPos.y < cropBottomY + dragDiff) ||
                (dragDirection == Direction.down && dragStartPos.y > cropBottomY) {
                
                dragDirection = Direction.stop
                
                imageCropView.changeScrollable(false)
                
            } else {
                
                imageCropView.changeScrollable(true)
            }
            
        } else if sender.state == UIGestureRecognizerState.changed {
            
            if !canPanDuringThisTouch {
                return
            }
            
            let currentPos = sender.location(in: self)
            
            if dragDirection == Direction.up && currentPos.y < cropBottomY - dragDiff {
                
                imageCropViewConstraintTop.constant = max(imageCropViewMinimalVisibleHeight - self.imageCropViewContainer.frame.height, currentPos.y + dragDiff - imageCropViewContainer.frame.height)
                
                collectionViewConstraintHeight.constant = min(self.frame.height - imageCropViewMinimalVisibleHeight, self.frame.height - imageCropViewConstraintTop.constant - imageCropViewContainer.frame.height)
                
            } else if dragDirection == Direction.down && currentPos.y > cropBottomY {
                
                imageCropViewConstraintTop.constant = min(imageCropViewOriginalConstraintTop, currentPos.y - imageCropViewContainer.frame.height)
                
                collectionViewConstraintHeight.constant = max(self.frame.height - imageCropViewOriginalConstraintTop - imageCropViewContainer.frame.height, self.frame.height - imageCropViewConstraintTop.constant - imageCropViewContainer.frame.height)
                
            } else if dragDirection == Direction.stop && collectionView.contentOffset.y < 0 {
                
                dragDirection = Direction.scroll
                imaginaryCollectionViewOffsetStartPosY = currentPos.y
                
            } else if dragDirection == Direction.scroll {
                
                imageCropViewConstraintTop.constant = imageCropViewMinimalVisibleHeight - self.imageCropViewContainer.frame.height + currentPos.y - imaginaryCollectionViewOffsetStartPosY
                
                collectionViewConstraintHeight.constant = max(self.frame.height - imageCropViewOriginalConstraintTop - imageCropViewContainer.frame.height, self.frame.height - imageCropViewConstraintTop.constant - imageCropViewContainer.frame.height)
                
            }
            
        } else {
            
            canPanDuringThisTouch = true // reset this value for the next interaction
            
            imaginaryCollectionViewOffsetStartPosY = 0.0
            
            if sender.state == UIGestureRecognizerState.ended && dragDirection == Direction.stop {
                
                imageCropView.changeScrollable(true)
                return
            }
            
            let currentPos = sender.location(in: self)
            
            if currentPos.y < cropBottomY - dragDiff && imageCropViewConstraintTop.constant != imageCropViewOriginalConstraintTop {
                
                // The largest movement
                imageCropView.changeScrollable(false)
                
                imageCropViewConstraintTop.constant = imageCropViewMinimalVisibleHeight - self.imageCropViewContainer.frame.height
                
                collectionViewConstraintHeight.constant = self.frame.height - imageCropViewMinimalVisibleHeight
                
                UIView.animate(withDuration: 0.3, delay: 0.0, options: UIViewAnimationOptions.curveEaseOut, animations: {
                    
                    self.layoutIfNeeded()
                    
                }, completion: nil)
                
                dragDirection = Direction.down
                
            } else {
                
                // Get back to the original position
                imageCropView.changeScrollable(true)
                
                imageCropViewConstraintTop.constant = imageCropViewOriginalConstraintTop
                collectionViewConstraintHeight.constant = self.frame.height - imageCropViewOriginalConstraintTop - imageCropViewContainer.frame.height
                
                UIView.animate(withDuration: 0.3, delay: 0.0, options: UIViewAnimationOptions.curveEaseOut, animations: {
                    
                    self.layoutIfNeeded()
                    
                }, completion: nil)
                
                dragDirection = Direction.up
                
            }
        }
        
        
    }
    
    // MARK: - Utilities
    
    func cropImageContainerNormalPosition() {
        imageCropView.changeScrollable(true)
        
        imageCropViewConstraintTop.constant = imageCropViewOriginalConstraintTop
        collectionViewConstraintHeight.constant = self.frame.height - imageCropViewOriginalConstraintTop - imageCropViewContainer.frame.height
        
        UIView.animate(withDuration: 0.2, delay: 0.0, options: UIViewAnimationOptions.curveEaseOut, animations: {
            
            self.layoutIfNeeded()
            
        }, completion: nil)
        
        dragDirection = Direction.up
    }
    
    func saveImageToCameraRoll(image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
            
        }, completionHandler: nil)
    }
    
    func convertEditImage() -> UIImage? {
        
        let myView = self.imageCropViewContainer!
        
        UIGraphicsBeginImageContextWithOptions(myView.bounds.size, myView.isOpaque, 0.0)
        myView.drawHierarchy(in: myView.bounds, afterScreenUpdates: false)
        let snapshotImageFromMyView = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return snapshotImageFromMyView
    }
    
    func hideEditOptions(_ flag: Bool) {
        self.brightnessSlider.isHidden = flag
        self.brightnessLessButton.isHidden = flag
        self.brightnessMoreButton.isHidden = flag
        
        self.fontSizeSlider.isHidden = flag
        self.fontSizeLessButton.isHidden = flag
        self.fontSizeMoreButton.isHidden = flag
        
        self.saveButton.isHidden = flag
        self.clearTextButton.isHidden = flag
        self.addTextButton.isHidden = flag
    }
    
    // MARK: - User interactions
    
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        if let image = self.convertEditImage() {
            self.saveImageToCameraRoll(image: image)
        }
    }
    
    @IBAction func clearTextButtonTapped(_ sender: UIButton) {
        self.textView.text = ""
        self.updateTextViewLayoutIfNeeded()
    }
    
    func textViewPanned(_ gr: UIPanGestureRecognizer) {
        let translation = gr.translation(in: self.imageCropViewContainer)
        
        if gr.state == .began {
            self.textViewOrigin = self.textView.frame.origin
        } else if gr.state == .changed {
            
            guard let startPos = self.textViewOrigin else {
                return
            }
            
            let x = startPos.x + translation.x
            let y = startPos.y + translation.y
            
           //x = min(max(0, x), self.imageCropViewContainer.frame.width)
           //y = min(max(0, y), self.imageCropViewContainer.frame.height)
            
            self.textView.frame.origin.x = x
            self.textView.frame.origin.y = y
        } else if gr.state == .ended || gr.state == .cancelled {
            self.textViewOrigin = self.textView.frame.origin
        }
    }
    
    @IBAction func addingTextDoneButtonTapped(_ sender: UIButton) {
        self.textView.resignFirstResponder()
    }
    
    @IBAction func addTextButtonTapped(_ sender: UIButton) {
        self.textView.becomeFirstResponder()
    }
    
    func imageCropContainerTapped(_ gr: UITapGestureRecognizer) {
        if gr.state == .ended {
            if self.addingText {
                self.textView.resignFirstResponder()
            } else {
                self.textView.becomeFirstResponder()
            }
        }
    }
    
    @IBAction func textAlphaSliderValueDidChange(_ sender: UISlider) {
        if let color = self.textView.textColor {
            self.textView.textColor = color.withAlphaComponent(self.textAlpha)
            self.textColorSelectorView.colorAlpha = self.textAlpha
        }
    }
    
    @IBAction func brightnessSliderValueDidChange(_ sender: UISlider) {
        
        let value = CGFloat(1 - sender.value)
        
        self.imageCropOverlay.backgroundColor = UIColor.black.withAlphaComponent(value)
    }
    
    @IBAction func fontSizeSliderValueDidChange(_ sender: UISlider) {
        let fontSize = fusumaMinFontSize + abs(fusumaMaxFontSize - fusumaMinFontSize) * sender.value
        
        self.textView.font = self.textView.font?.withSize(CGFloat(fontSize))
        self.updateTextViewLayoutIfNeeded(false)
    }
    
    // MARK: - UICollectionViewDelegate Protocol
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FSAlbumViewCell", for: indexPath) as! FSAlbumViewCell
        
        let currentTag = cell.tag + 1
        cell.tag = currentTag
        
        let asset = self.images[(indexPath as NSIndexPath).item]
        self.imageManager?.requestImage(for: asset,
                                        targetSize: cellSize,
                                        contentMode: .aspectFill,
                                        options: nil) {
                                            result, info in
                                            
                                            if cell.tag == currentTag {
                                                cell.image = result
                                            }
                                            
        }
        
        return cell
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return images == nil ? 0 : images.count
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: IndexPath) -> CGSize {
        
        let width = (collectionView.frame.width - 3) / 4
        return CGSize(width: width, height: width)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        changeImage(images[(indexPath as NSIndexPath).row])
        
        self.cropImageContainerNormalPosition()
        collectionView.scrollToItem(at: indexPath, at: .top, animated: true)
    }
    
    
    // MARK: - ScrollViewDelegate
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        if scrollView == collectionView {
            self.updateCachedAssets()
        }
    }
    
    // MARK: - Text view delegate
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        self.addingText = true
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        self.addingText = false
    }
    
    func textViewDidChange(_ textView: UITextView) {
        if textView == self.textView {
            self.updateTextViewLayoutIfNeeded()
        }
    }
    
    //MARK: - PHPhotoLibraryChangeObserver
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        
        DispatchQueue.main.async {
            
            let collectionChanges = changeInstance.changeDetails(for: self.images)
            if collectionChanges != nil {
                
                self.images = collectionChanges!.fetchResultAfterChanges
                
                let collectionView = self.collectionView!
                
                if !collectionChanges!.hasIncrementalChanges || collectionChanges!.hasMoves || (collectionChanges!.removedIndexes != nil) {
                    
                    collectionView.reloadData()
                    
                } else {
                    
                    collectionView.performBatchUpdates({
                        let removedIndexes = collectionChanges!.removedIndexes
                        if (removedIndexes?.count ?? 0) != 0 {
                            collectionView.deleteItems(at: removedIndexes!.aapl_indexPathsFromIndexesWithSection(0))
                        }
                        let insertedIndexes = collectionChanges!.insertedIndexes
                        if (insertedIndexes?.count ?? 0) != 0 {
                            collectionView.insertItems(at: insertedIndexes!.aapl_indexPathsFromIndexesWithSection(0))
                        }
                        let changedIndexes = collectionChanges!.changedIndexes
                        if (changedIndexes?.count ?? 0) != 0 {
                            collectionView.reloadItems(at: changedIndexes!.aapl_indexPathsFromIndexesWithSection(0))
                        }
                    }, completion: nil)
                }
                
                self.resetCachedAssets()
            }
        }
    }
}

internal extension UICollectionView {
    
    func aapl_indexPathsForElementsInRect(_ rect: CGRect) -> [IndexPath] {
        let allLayoutAttributes = self.collectionViewLayout.layoutAttributesForElements(in: rect)
        if (allLayoutAttributes?.count ?? 0) == 0 {return []}
        var indexPaths: [IndexPath] = []
        indexPaths.reserveCapacity(allLayoutAttributes!.count)
        for layoutAttributes in allLayoutAttributes! {
            let indexPath = layoutAttributes.indexPath
            indexPaths.append(indexPath)
        }
        return indexPaths
    }
}

internal extension IndexSet {
    
    func aapl_indexPathsFromIndexesWithSection(_ section: Int) -> [IndexPath] {
        var indexPaths: [IndexPath] = []
        indexPaths.reserveCapacity(self.count)
        (self as NSIndexSet).enumerate({idx, stop in
            indexPaths.append(IndexPath(item: idx, section: section))
        })
        return indexPaths
    }
}

extension FSAlbumView {
    
    func changeImage(_ asset: PHAsset) {
        
        self.imageCropView.image = nil
        self.phAsset = asset
        
        DispatchQueue.global(qos: .default).async(execute: {
            
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            
            self.imageManager?.requestImage(for: asset,
                                            targetSize: CGSize(width: asset.pixelWidth, height: asset.pixelHeight),
                                            contentMode: .aspectFill,
                                            options: options) {
                                                result, info in
                                                
                                                DispatchQueue.main.async(execute: {
                                                    
                                                    self.imageCropView.imageSize = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
                                                    self.imageCropView.image = result
                                                })
            }
        })
    }
    
    // Check the status of authorization for PHPhotoLibrary
    func checkPhotoAuth() {
        
        PHPhotoLibrary.requestAuthorization { (status) -> Void in
            switch status {
            case .authorized:
                self.imageManager = PHCachingImageManager()
                if self.images != nil && self.images.count > 0 {
                    
                    self.changeImage(self.images[0])
                }
                
                DispatchQueue.main.async {
                    self.delegate?.albumViewCameraRollAuthorized()
                }
                
            case .restricted, .denied:
                DispatchQueue.main.async(execute: { () -> Void in
                    
                    self.delegate?.albumViewCameraRollUnauthorized()
                    
                })
            default:
                break
            }
        }
    }
    
    // MARK: - Asset Caching
    
    func resetCachedAssets() {
        
        imageManager?.stopCachingImagesForAllAssets()
        previousPreheatRect = CGRect.zero
    }
    
    func updateCachedAssets() {
        
        var preheatRect = self.collectionView!.bounds
        preheatRect = preheatRect.insetBy(dx: 0.0, dy: -0.5 * preheatRect.height)
        
        let delta = abs(preheatRect.midY - self.previousPreheatRect.midY)
        if delta > self.collectionView!.bounds.height / 3.0 {
            
            var addedIndexPaths: [IndexPath] = []
            var removedIndexPaths: [IndexPath] = []
            
            self.computeDifferenceBetweenRect(self.previousPreheatRect, andRect: preheatRect, removedHandler: {removedRect in
                let indexPaths = self.collectionView.aapl_indexPathsForElementsInRect(removedRect)
                removedIndexPaths += indexPaths
            }, addedHandler: {addedRect in
                let indexPaths = self.collectionView.aapl_indexPathsForElementsInRect(addedRect)
                addedIndexPaths += indexPaths
            })
            
            let assetsToStartCaching = self.assetsAtIndexPaths(addedIndexPaths)
            let assetsToStopCaching = self.assetsAtIndexPaths(removedIndexPaths)
            
            self.imageManager?.startCachingImages(for: assetsToStartCaching,
                                                  targetSize: cellSize,
                                                  contentMode: .aspectFill,
                                                  options: nil)
            self.imageManager?.stopCachingImages(for: assetsToStopCaching,
                                                 targetSize: cellSize,
                                                 contentMode: .aspectFill,
                                                 options: nil)
            
            self.previousPreheatRect = preheatRect
        }
    }
    
    func computeDifferenceBetweenRect(_ oldRect: CGRect, andRect newRect: CGRect, removedHandler: (CGRect)->Void, addedHandler: (CGRect)->Void) {
        if newRect.intersects(oldRect) {
            let oldMaxY = oldRect.maxY
            let oldMinY = oldRect.minY
            let newMaxY = newRect.maxY
            let newMinY = newRect.minY
            if newMaxY > oldMaxY {
                let rectToAdd = CGRect(x: newRect.origin.x, y: oldMaxY, width: newRect.size.width, height: (newMaxY - oldMaxY))
                addedHandler(rectToAdd)
            }
            if oldMinY > newMinY {
                let rectToAdd = CGRect(x: newRect.origin.x, y: newMinY, width: newRect.size.width, height: (oldMinY - newMinY))
                addedHandler(rectToAdd)
            }
            if newMaxY < oldMaxY {
                let rectToRemove = CGRect(x: newRect.origin.x, y: newMaxY, width: newRect.size.width, height: (oldMaxY - newMaxY))
                removedHandler(rectToRemove)
            }
            if oldMinY < newMinY {
                let rectToRemove = CGRect(x: newRect.origin.x, y: oldMinY, width: newRect.size.width, height: (newMinY - oldMinY))
                removedHandler(rectToRemove)
            }
        } else {
            addedHandler(newRect)
            removedHandler(oldRect)
        }
    }
    
    func assetsAtIndexPaths(_ indexPaths: [IndexPath]) -> [PHAsset] {
        if indexPaths.count == 0 { return [] }
        
        var assets: [PHAsset] = []
        assets.reserveCapacity(indexPaths.count)
        for indexPath in indexPaths {
            let asset = self.images[(indexPath as NSIndexPath).item]
            assets.append(asset)
        }
        return assets
    }
}


extension FSAlbumView: ColorSelectorViewDelegate {
    
    func hide(_ hide: Bool, view: UIView) {
        if hide {
            if view.alpha == 0.0 {
                return
            }
            
            UIView.animate(withDuration: 0.3, animations: {
                view.alpha = 0.0
            })
            
        } else {
            if view.alpha == 1.0 {
                return
            }
            
            UIView.animate(withDuration: 0.3, animations: {
                view.alpha = 1.0
            })
        }
    }
    
    func colorSelectorView(_ v: ColorSelectorView, didSelectColor color: UIColor) {
        self.textView.textColor = color.withAlphaComponent(self.textAlpha)
        
        self.hide(true, view: textAlphaContainer)
    }
    
    func colorSelectorView(_ v: ColorSelectorView, diSelectAtIndex index: Int) {
        // no-ops
    }
    
    func colorSelectorView(_ v: ColorSelectorView, didLongPressSelectedColor gr: UILongPressGestureRecognizer) {
        if gr.state == .began {
            
            var centerX = self.frame.midX
                        
            if let button = v.selectedColorButton {
                let p = v.scrollView.convert(button.center, to: self)
                centerX = p.x
                centerX = min(max(centerX, textAlphaContainer.bounds.midX + 5), self.frame.width - textAlphaContainer.bounds.midX - 5)
            }
            
            textAlphaContainer.center.x = centerX
            
            self.hide(false, view: textAlphaContainer)
        }
    }
}
