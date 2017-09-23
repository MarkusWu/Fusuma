//
//  FusumaViewController.swift
//  Fusuma
//
//  Created by Yuta Akizuki on 2015/11/14.
//  Copyright © 2015年 ytakzk. All rights reserved.
//

import UIKit
import MobileCoreServices
import Photos

fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l > r
    default:
        return rhs < lhs
    }
}


@objc public protocol FusumaDelegate: class {
    // MARK: - Required
    func fusumaImageSelected(_ image: UIImage, source: FusumaMode)
    func fusumaVideoCompleted(withFileURL fileURL: URL)
    func fusumaCameraRollUnauthorized()
    
    // MARK: - Optional
    func fusumaDismissedWithImage(_ image: UIImage, source: FusumaMode)
    func fusumaWillPresentPhotosLib(_ fusumaVC: FusumaViewController)
    func fusumaDidDismissPhotosLib(_ fusumaVC: FusumaViewController)
    
    @objc optional func fusumaAddTextDidBegin()
    @objc optional func fusumaAddTextDidEnd()
    
    @objc optional func fusuma(_ fusumaVC: FusumaViewController, didTapClose button: UIButton)
}

public extension FusumaDelegate {
    func fusumaImageSelected(_ image: UIImage, source: FusumaMode, metaData: ImageMetadata) {}
    func fusumaDismissedWithImage(_ image: UIImage, source: FusumaMode) {}
}

public var fusumaBaseTintColor   = UIColor.hex("#FFFFFF", alpha: 1.0)
public var fusumaTintColor       = UIColor.hex("#F38181", alpha: 1.0)
public var fusumaBackgroundColor = UIColor.hex("#3B3D45", alpha: 1.0)
public var fusumaTextColors: [UIColor] = []

public var fusumaLongPressPhotoLibCellEnabled = false

public var markusAccessPhotosType: MarkusAccessPhotosType = .image

public var fusumaAlbumImage : UIImage? = nil
public var fusumaCameraImage : UIImage? = nil
public var fusumaVideoImage : UIImage? = nil
public var fusumaCheckImage : UIImage? = nil
public var fusumaCloseImage : UIImage? = nil
public var fusumaFlashOnImage : UIImage? = nil
public var fusumaFlashOffImage : UIImage? = nil
public var fusumaFlipImage : UIImage? = nil
public var fusumaShotImage : UIImage? = nil
public var fusumaAutoDismiss = true

public var fusumaStartingMode: FusumaMode = .library

public var fusumaImageOverlayBrightness: Float = 0.45

public var fusumaMinFontSize: Float = 18
public var fusumaMaxFontSize: Float = 28
public var fusumaInitialFontSize: Float = 20

public var fusumaVideoStartImage : UIImage? = nil
public var fusumaVideoStopImage : UIImage? = nil

public var fusumaCropImage: Bool = true

public var fusumaSavesImage: Bool = false

public var fusumaCameraRollTitle = "CAMERA ROLL"
public var fusumaCameraTitle = "PHOTO"
public var fusumaVideoTitle = "VIDEO"
public var fusumaTitleFont = UIFont(name: "AvenirNext-DemiBold", size: 15)

public var fusumaTintIcons : Bool = true

@objc public enum FusumaModeOrder: Int {
    case cameraFirst
    case libraryFirst
}

@objc public enum FusumaMode: Int {
    case camera
    case library
    case video
}

public struct ImageMetadata {
    public let mediaType: PHAssetMediaType
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let creationDate: Date?
    public let modificationDate: Date?
    public let location: CLLocation?
    public let duration: TimeInterval
    public let isFavourite: Bool
    public let isHidden: Bool
}

//@objc public class FusumaViewController: UIViewController, FSCameraViewDelegate, FSAlbumViewDelegate {
public class FusumaViewController: UIViewController, UIGestureRecognizerDelegate {
    
    // Determine whether or not to reposition ImageCropContainer for better UI
    var shouldRepositionImageCropContainerOnViewDisapper = true
    
    private var neverUpdateHighlightButtonOnViewAppear = true
    
    /// a singleton shared instance
    private static var instance: FusumaViewController?
    
    // used to ensure viewWillDisappear and viewDidDisappear is not being call when
    // viewDidDisappear is never called.
    private var didDisappear = true
    
    public static var shared: FusumaViewController {
        if self.instance == nil {
           self.instance = FusumaViewController()
        }
        
        return self.instance!
    }
    
    public var imageOveralyBrightness: Float {
        return self.albumView.brightnessSlider.value
    }
    
    public var imageTextFontSize: CGFloat? {
        return self.albumView.textView.font?.pointSize
    }
    
    public static func disposeShared() {
        self.instance = nil
    }
    
    public static var isSharedInstanceInitiated: Bool {
        return self.instance != nil
    }
    
    public var photoEditable: Bool = false {
        didSet {
            self.albumView.hidePhotoEditor(!self.photoEditable)
            if self.previewButton != nil {
                self.previewButton.isHidden = !self.photoEditable
                
                if self.photoEditable {
                    if let image = UIImage(named: "icon_preview", in: Bundle(for: type(of: self)), compatibleWith: nil){
                        self.previewButton.setImage(image, for: .normal)
                    }
                }
            }
        }
    }
    
    public var animatedOnDismiss = true
    
    public var hasVideo = false
    public var cropHeightRatio: CGFloat = 1
    
    var mode: FusumaMode!
    public var modeOrder: FusumaModeOrder = .libraryFirst
    var willFilter = true
    
    @IBOutlet weak var floatingDoneButtonContainer: UIView!
    @IBOutlet weak var floatingDoneButton: RoundedButton!
    
    private var albumCollectionViewLongPressRecog: UILongPressGestureRecognizer?
    
    @IBOutlet weak var photoLibraryViewerContainer: UIView!
    @IBOutlet weak var cameraShotContainer: UIView!
    @IBOutlet weak var videoShotContainer: UIView!
    
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var statusBarView: UIView!
    @IBOutlet weak var statusBarHeightConstr: NSLayoutConstraint!
    
    @IBOutlet weak var menuView: UIView!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var libraryButton: UIButton!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var videoButton: UIButton!
    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var expandArrowButton: UIButton!
    
    @IBOutlet weak var previewButton: UIButton!
    
    @IBOutlet var libraryFirstConstraints: [NSLayoutConstraint]!
    @IBOutlet var cameraFirstConstraints: [NSLayoutConstraint]!
    
    lazy var albumView  = FSAlbumView.instance()
    lazy var cameraView = FSCameraView.instance()
    lazy var videoView = FSVideoCameraView.instance()
    var textColorSelectorView: ColorSelectorView! {
        return self.albumView.textColorSelectorView
    }
    var textAlphaContainer: UIView! {
        return self.albumView.textAlphaContainer
    }
    
    public var initialSelectedColorIndex: Int = 0
    
    public var preferredModeOnWillAppear: FusumaMode?
    
    fileprivate var hasGalleryPermission: Bool {
        return PHPhotoLibrary.authorizationStatus() == .authorized
    }
    
    public weak var delegate: FusumaDelegate? = nil
    
    deinit {
        let nc = NotificationCenter.default
        
        nc.removeObserver(self)
    }
    
    override public func loadView() {
        
        if let view = UINib(nibName: "FusumaViewController", bundle: Bundle(for: self.classForCoder)).instantiate(withOwner: self, options: nil).first as? UIView {
            
            self.view = view
        }
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.statusBarHeightConstr.constant = UIApplication.shared.statusBarFrame.height
        
        let nc = NotificationCenter.default
        
        nc.addObserver(self, selector: #selector(self.keyboardWillShow(_:)), name: .UIKeyboardWillShow, object: nil)
        
        nc.addObserver(self, selector: #selector(self.keyboardWillHide(_:)), name: .UIKeyboardWillHide, object: nil)
        
        self.previewButton.isHidden = !self.photoEditable
        
        self.view.backgroundColor = fusumaBackgroundColor
        
        cameraView.delegate = self
        albumView.delegate  = self
        videoView.delegate = self
        
        menuView.backgroundColor = fusumaBackgroundColor
        menuView.addBottomBorder(UIColor.black, width: 1.0)
        
        let bundle = Bundle(for: self.classForCoder)
        
        // Get the custom button images if they're set
        let albumImage = fusumaAlbumImage != nil ? fusumaAlbumImage : UIImage(named: "ic_insert_photo", in: bundle, compatibleWith: nil)
        let cameraImage = fusumaCameraImage != nil ? fusumaCameraImage : UIImage(named: "ic_photo_camera", in: bundle, compatibleWith: nil)
        
        let videoImage = fusumaVideoImage != nil ? fusumaVideoImage : UIImage(named: "ic_videocam", in: bundle, compatibleWith: nil)
        
        
        let checkImage = fusumaCheckImage != nil ? fusumaCheckImage : UIImage(named: "ic_check", in: bundle, compatibleWith: nil)
        let closeImage = fusumaCloseImage != nil ? fusumaCloseImage : UIImage(named: "ic_close", in: bundle, compatibleWith: nil)
        
        if fusumaTintIcons {
            
            libraryButton.setImage(albumImage?.withRenderingMode(.alwaysTemplate), for: UIControlState())
            libraryButton.setImage(albumImage?.withRenderingMode(.alwaysTemplate), for: .highlighted)
            libraryButton.setImage(albumImage?.withRenderingMode(.alwaysTemplate), for: .selected)
            libraryButton.tintColor = fusumaTintColor
            libraryButton.adjustsImageWhenHighlighted = false
            
            cameraButton.setImage(cameraImage?.withRenderingMode(.alwaysTemplate), for: UIControlState())
            cameraButton.setImage(cameraImage?.withRenderingMode(.alwaysTemplate), for: .highlighted)
            cameraButton.setImage(cameraImage?.withRenderingMode(.alwaysTemplate), for: .selected)
            cameraButton.tintColor  = fusumaTintColor
            cameraButton.adjustsImageWhenHighlighted  = false
            
            closeButton.setImage(closeImage?.withRenderingMode(.alwaysTemplate), for: UIControlState())
            closeButton.setImage(closeImage?.withRenderingMode(.alwaysTemplate), for: .highlighted)
            closeButton.setImage(closeImage?.withRenderingMode(.alwaysTemplate), for: .selected)
            closeButton.tintColor = fusumaBaseTintColor
            
            videoButton.setImage(videoImage, for: UIControlState())
            videoButton.setImage(videoImage, for: .highlighted)
            videoButton.setImage(videoImage, for: .selected)
            videoButton.tintColor  = fusumaTintColor
            videoButton.adjustsImageWhenHighlighted = false
            
            doneButton.setImage(checkImage?.withRenderingMode(.alwaysTemplate), for: UIControlState())
            doneButton.tintColor = fusumaBaseTintColor
            
        } else {
            
            libraryButton.setImage(albumImage, for: UIControlState())
            libraryButton.setImage(albumImage, for: .highlighted)
            libraryButton.setImage(albumImage, for: .selected)
            libraryButton.tintColor = nil
            
            cameraButton.setImage(cameraImage, for: UIControlState())
            cameraButton.setImage(cameraImage, for: .highlighted)
            cameraButton.setImage(cameraImage, for: .selected)
            cameraButton.tintColor = nil
            
            videoButton.setImage(videoImage, for: UIControlState())
            videoButton.setImage(videoImage, for: .highlighted)
            videoButton.setImage(videoImage, for: .selected)
            videoButton.tintColor = nil
            
            closeButton.setImage(closeImage, for: UIControlState())
            doneButton.setImage(checkImage, for: UIControlState())
        }
        
        cameraButton.clipsToBounds  = true
        libraryButton.clipsToBounds = true
        videoButton.clipsToBounds = true
        
        changeMode(fusumaStartingMode)
        
        self.preferredModeOnWillAppear = fusumaStartingMode
        
        photoLibraryViewerContainer.addSubview(albumView)
        cameraShotContainer.addSubview(cameraView)
        videoShotContainer.addSubview(videoView)
        
        titleLabel.textColor = fusumaBaseTintColor
        titleLabel.font = fusumaTitleFont
        
        let singleTapTitleLabel = UITapGestureRecognizer(target: self, action: #selector(self.titleLabelTapped(_:)))
        
        self.titleLabel.isUserInteractionEnabled = true
        self.titleLabel.addGestureRecognizer(singleTapTitleLabel)
        
        //        if modeOrder != .LibraryFirst {
        //            libraryFirstConstraints.forEach { $0.priority = 250 }
        //            cameraFirstConstraints.forEach { $0.priority = 1000 }
        //        }
        
        if !hasVideo {
            
            videoButton.removeFromSuperview()
            
            self.view.addConstraint(NSLayoutConstraint(
                item:       self.view,
                attribute:  .trailing,
                relatedBy:  .equal,
                toItem:     cameraButton,
                attribute:  .trailing,
                multiplier: 1.0,
                constant:   0
                )
            )
            
            self.view.layoutIfNeeded()
        }
        
        if fusumaCropImage {
            let heightRatio = getCropHeightRatio()
            cameraView.croppedAspectRatioConstraint = NSLayoutConstraint(item: cameraView.previewViewContainer, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: cameraView.previewViewContainer, attribute: NSLayoutAttribute.width, multiplier: heightRatio, constant: 0)
            
            cameraView.fullAspectRatioConstraint.isActive = false
            cameraView.croppedAspectRatioConstraint?.isActive = true
        } else {
            cameraView.fullAspectRatioConstraint.isActive = true
            cameraView.croppedAspectRatioConstraint?.isActive = false
        }
        
        if fusumaLongPressPhotoLibCellEnabled {
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(self.photoLibContainerLongPressed(_:)))
            longPress.delegate = self
            self.photoLibraryViewerContainer.addGestureRecognizer(longPress)
            
            self.albumCollectionViewLongPressRecog = longPress
            
            self.floatingDoneButton.backgroundColor = fusumaTintColor
        }
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard self.didDisappear else {
            return
        }
        
        if self.preferredModeOnWillAppear != nil {
            self.changeMode(self.preferredModeOnWillAppear!)
        }
        
        if self.mode == .camera {
            self.cameraView.startCamera()
        } else if self.mode == .video {
            self.videoView.startCamera()
        }
        
        // high light button again for better UI
        if neverUpdateHighlightButtonOnViewAppear {
            if self.mode != nil {
                
                self.neverUpdateHighlightButtonOnViewAppear = false
                
                switch self.mode! {
                case .library:
                    highlightButton(libraryButton)
                case .camera:
                    highlightButton(cameraButton)
                case .video:
                    highlightButton(videoButton)
                }
            }
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard self.didDisappear else {
            return
        }
        
        self.setUpAllViews()
        
        self.didDisappear = false
    }
    
    public func setUpAllViews() {
        albumView.frame  = CGRect(origin: CGPoint.zero, size: photoLibraryViewerContainer.frame.size)
        albumView.layoutIfNeeded()
        cameraView.frame = CGRect(origin: CGPoint.zero, size: cameraShotContainer.frame.size)
        cameraView.layoutIfNeeded()
        
        albumView.initialize()
        cameraView.initialize()
        
        if hasVideo {
            
            videoView.frame = CGRect(origin: CGPoint.zero, size: videoShotContainer.frame.size)
            videoView.layoutIfNeeded()
            videoView.initialize()
        }
    }
    
    public func selectLibImage(at indexNumber: Int) {
        self.albumView.selectImage(at: indexNumber)
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
//        if self.shouldRepositionImageCropContainerOnViewDisapper {
//            // reposition imageCropContainer for better UI purpose.
//            self.albumView.imageCropViewConstraintTop.constant = self.albumView.imageCropViewOriginalConstraintTop
//        }
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.stopAll()
        self.didDisappear = true
    }
    
    override public var prefersStatusBarHidden : Bool {
        
        return true
    }
    
    // MARK: - Observers:
    
    func keyboardWillShow(_ notification: Notification) {
        guard self.isViewLoaded && self.view.window != nil else {
            return
        }
        
        guard let keyboardRect = ((notification as NSNotification).userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            return
        }
        
        self.textColorSelectorView.alpha = 0.0
        
        let y = self.view.frame.height - (keyboardRect.height + 2 + self.textColorSelectorView.frame.height)
        
        var rect = self.textAlphaContainer.frame
        rect.origin.y = y - rect.height - 10
        
        UIView.animate(
            withDuration: 0.30,
            delay: 0.0,
            options: .curveEaseIn,
            animations: {
                self.textColorSelectorView.alpha = 1.0
                self.textColorSelectorView.frame.origin.y = y
                self.textAlphaContainer.frame = rect
        },
            completion: nil)
    }
    
    func keyboardWillHide(_ notification: Notification) {
        guard self.isViewLoaded && self.view.window != nil else {
            return
        }
        
        
        UIView.animate(
            withDuration: 0.30,
            delay: 0.0,
            options: .curveEaseIn,
            animations: {
                self.textColorSelectorView.alpha = 0.0
                self.textAlphaContainer.alpha = 0.0
        },
            completion: nil)
    }
    
    // MARK: - Gesture delegate
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        
        if gestureRecognizer === self.albumCollectionViewLongPressRecog {
            let p = touch.location(in: self.photoLibraryViewerContainer)
            if self.albumView.collectionView.frame.contains(p) {
                return true
            } else {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - User interactions
    
    func photoLibContainerLongPressed(_ gr: UILongPressGestureRecognizer) {
        if gr.state == .began {
            let p = gr.location(in: self.albumView.collectionView)
            
            if let indexPath = self.albumView.collectionView.indexPathForItem(at: p) {
                if let cell = self.albumView.collectionView.cellForItem(at: indexPath) {
                    if cell.isSelected {
                        var p = gr.location(in: self.photoLibraryViewerContainer)
                        
                        let xOffset = self.floatingDoneButton.bounds.midX + 5
                        
                        p.x = min(p.x, self.photoLibraryViewerContainer.bounds.maxX - xOffset)
                        p.x = max(p.x, 0 + xOffset)
                        
                        p.y -= 40
                        
                        self.floatingDoneButtonContainer.center = p
                        
                        self.photoLibraryViewerContainer.bringSubview(toFront: self.floatingDoneButtonContainer)
                        UIUtil.hide(false, view: self.floatingDoneButtonContainer)
                    }
                }
            } else {
            }
        }
    }
    
    @IBAction func previewButtonTapped(_ sender: UIButton) {
        if self.albumView.brightnessSlider.isHidden {
            self.albumView.hideEditOptions(false)
            if let image = UIImage(named: "icon_preview", in: Bundle(for: type(of: self)), compatibleWith: nil){
                self.previewButton.setImage(image, for: .normal)
            }
        } else {
            self.albumView.hideEditOptions(true)
            if let image = UIImage(named: "icon_no_preview", in: Bundle(for: type(of: self)), compatibleWith: nil){
                self.previewButton.setImage(image, for: .normal)
            }
        }
    }
    
    @IBAction func closeButtonPressed(_ sender: UIButton) {
        
        if self.delegate == nil {
            self.dismiss(animated: self.animatedOnDismiss, completion: nil)
        } else {
            
            if self.delegate?.fusuma?(self, didTapClose: sender) == nil {
                self.dismiss(animated: self.animatedOnDismiss, completion: nil)
            }
        }
    }
    
    @IBAction public func libraryButtonPressed(_ sender: UIButton?) {
        
        if sender != nil {
            self.preferredModeOnWillAppear = .library
        }
        
        changeMode(FusumaMode.library)
    }
    
    @IBAction func photoButtonPressed(_ sender: UIButton) {
        self.preferredModeOnWillAppear = .camera
        changeMode(FusumaMode.camera)
    }
    
    @IBAction func videoButtonPressed(_ sender: UIButton) {
        self.preferredModeOnWillAppear = .video
        changeMode(FusumaMode.video)
    }
    
    public func clearEditText() {
        self.albumView.textView.text = ""
        self.albumView.textViewOrigin = nil
        self.albumView.updateTextViewLayoutIfNeeded()
    }
    
    @IBAction func doneButtonPressed(_ sender: UIButton) {
        let view = albumView.imageCropView
        
        var image:UIImage? = nil
        
        if self.photoEditable {
            self.albumView.imageCropView.backgroundColor = UIColor.white
            image = self.albumView.convertEditImage()
            self.albumView.imageCropView.backgroundColor = fusumaBackgroundColor
        }
        
        if image != nil || !fusumaCropImage {
            
            let selectedImage = image ?? (view?.image)!
            
            delegate?.fusumaImageSelected(selectedImage, source: mode)
            
            if fusumaAutoDismiss {
                self.dismiss(animated: self.animatedOnDismiss, completion: {
                    self.delegate?.fusumaDismissedWithImage((view?.image)!, source: self.mode)
                })
            }
        } else {
            let normalizedX = (view?.contentOffset.x)! / (view?.contentSize.width)!
            let normalizedY = (view?.contentOffset.y)! / (view?.contentSize.height)!
            
            let normalizedWidth = (view?.frame.width)! / (view?.contentSize.width)!
            let normalizedHeight = (view?.frame.height)! / (view?.contentSize.height)!
            
            let cropRect = CGRect(x: normalizedX, y: normalizedY, width: normalizedWidth, height: normalizedHeight)
            
            DispatchQueue.global(qos: .default).async(execute: {
                
                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.isNetworkAccessAllowed = true
                options.normalizedCropRect = cropRect
                options.resizeMode = .exact
                
                let targetWidth = floor(CGFloat(self.albumView.phAsset.pixelWidth) * cropRect.width)
                let targetHeight = floor(CGFloat(self.albumView.phAsset.pixelHeight) * cropRect.height)
                let dimensionW = max(min(targetHeight, targetWidth), 1024 * UIScreen.main.scale)
                let dimensionH = dimensionW * self.getCropHeightRatio()
                
                let targetSize = CGSize(width: dimensionW, height: dimensionH)
                
                PHImageManager.default().requestImage(for: self.albumView.phAsset, targetSize: targetSize,
                                                      contentMode: .aspectFill, options: options) {
                                                        result, info in
                                                        
                                                        DispatchQueue.main.async(execute: {
                                                            self.delegate?.fusumaImageSelected(result!, source: self.mode)
                                                            
                                                            if fusumaAutoDismiss {
                                                                self.dismiss(animated: self.animatedOnDismiss, completion: {
                                                                    self.delegate?.fusumaDismissedWithImage(result!, source: self.mode)
                                                                })
                                                            }
                                                            
                                                            let metaData = ImageMetadata(
                                                                mediaType: self.albumView.phAsset.mediaType,
                                                                pixelWidth: self.albumView.phAsset.pixelWidth,
                                                                pixelHeight: self.albumView.phAsset.pixelHeight,
                                                                creationDate: self.albumView.phAsset.creationDate,
                                                                modificationDate: self.albumView.phAsset.modificationDate,
                                                                location: self.albumView.phAsset.location,
                                                                duration: self.albumView.phAsset.duration,
                                                                isFavourite: self.albumView.phAsset.isFavorite,
                                                                isHidden: self.albumView.phAsset.isHidden)
                                                            
                                                            self.delegate?.fusumaImageSelected(result!, source: self.mode, metaData: metaData)
                                                            
                                                        })
                }
            })
        }
    }
    
    @IBAction func expandArrowButtonTapped(_ sender: UIButton) {
        self.accessPhotosLib()
    }
    
    func titleLabelTapped(_ gr: UITapGestureRecognizer) {
        
        if gr.state == .ended && self.mode == .library {
            self.accessPhotosLib()
        }
    }
}

extension FusumaViewController: FSAlbumViewDelegate, FSCameraViewDelegate, FSVideoCameraViewDelegate {
    public func getCropHeightRatio() -> CGFloat {
        return cropHeightRatio
    }
    
    // MARK: FSCameraViewDelegate
    func cameraShotFinished(_ image: UIImage) {
        
        delegate?.fusumaImageSelected(image, source: mode)
        
        if fusumaAutoDismiss {
            self.dismiss(animated: self.animatedOnDismiss, completion: {
                
                self.delegate?.fusumaDismissedWithImage(image, source: self.mode)
            })
        }
    }
    
    public func albumViewCameraRollAuthorized() {
        // in the case that we're just coming back from granting photo gallery permissions
        // ensure the done button is visible if it should be
        self.updateDoneButtonVisibility()
    }
    
    // MARK: - FSAlbumViewDelegate
    
    public func ablumCollectionView(didSelectItemAt indexPath: IndexPath) {
        UIUtil.hide(true, view: self.floatingDoneButtonContainer)
    }
    
    public func albumViewCameraRollUnauthorized() {
        delegate?.fusumaCameraRollUnauthorized()
    }
    
    func videoFinished(withFileURL fileURL: URL) {
        delegate?.fusumaVideoCompleted(withFileURL: fileURL)
        self.dismiss(animated: self.animatedOnDismiss, completion: nil)
    }
    
    public func albumViewAddingText(_ flag: Bool) {
        self.closeButton.isEnabled = !flag
        self.doneButton.isEnabled = !flag
        self.expandArrowButton.isEnabled = !flag
        self.previewButton.isEnabled = !flag
        
        if flag {
            if let image = UIImage(named: "icon_preview", in: Bundle(for: type(of: self)), compatibleWith: nil){
                self.previewButton.setImage(image, for: .normal)
            }
            
            self.delegate?.fusumaAddTextDidBegin?()
        } else {
            self.delegate?.fusumaAddTextDidEnd?()
        }
        
        // this is only for making the text color dim
        self.titleLabel.isEnabled = !flag
        self.titleLabel.isUserInteractionEnabled = !flag
    }
    
}

private extension FusumaViewController {
    
    func stopAll() {
        
        if hasVideo {
            
            self.videoView.stopCamera()
        }
        
        self.cameraView.stopCamera()
    }
    
    func changeMode(_ mode: FusumaMode) {
        
        if self.mode == mode {
            return
        }
        
        if self.mode != nil {
            //operate this switch before changing mode to stop cameras
            switch self.mode! {
            case .library:
                break
            case .camera:
                self.cameraView.stopCamera()
            case .video:
                self.videoView.stopCamera()
            }
        }
        
        self.mode = mode
        
        self.expandArrowButton.isHidden = self.mode != .library
        
        dishighlightButtons()
        updateDoneButtonVisibility()
        
        switch mode {
        case .library:
            titleLabel.text = NSLocalizedString(fusumaCameraRollTitle, comment: fusumaCameraRollTitle)
            
            highlightButton(libraryButton)
            self.view.bringSubview(toFront: photoLibraryViewerContainer)
        case .camera:
            titleLabel.text = NSLocalizedString(fusumaCameraTitle, comment: fusumaCameraTitle)
            
            highlightButton(cameraButton)
            self.view.bringSubview(toFront: cameraShotContainer)
            cameraView.startCamera()
        case .video:
            titleLabel.text = fusumaVideoTitle
            
            highlightButton(videoButton)
            self.view.bringSubview(toFront: videoShotContainer)
            videoView.startCamera()
        }
        doneButton.isHidden = !hasGalleryPermission
        self.view.bringSubview(toFront: menuView)
    }
    
    
    func updateDoneButtonVisibility() {
        // don't show the done button without gallery permission
        if !hasGalleryPermission {
            self.doneButton.isHidden = true
            return
        }
        
        if let mode = self.mode {
            switch mode {
            case .library:
                self.doneButton.isHidden = false
            default:
                self.doneButton.isHidden = true
            }
        }
    }
    
    func dishighlightButtons() {
        cameraButton.tintColor  = fusumaBaseTintColor
        libraryButton.tintColor = fusumaBaseTintColor
        
        if cameraButton.layer.sublayers?.count > 1 {
            
            for layer in cameraButton.layer.sublayers! {
                
                if let borderColor = layer.borderColor , UIColor(cgColor: borderColor) == fusumaTintColor {
                    
                    layer.removeFromSuperlayer()
                }
                
            }
        }
        
        if libraryButton.layer.sublayers?.count > 1 {
            
            for layer in libraryButton.layer.sublayers! {
                
                if let borderColor = layer.borderColor , UIColor(cgColor: borderColor) == fusumaTintColor {
                    
                    layer.removeFromSuperlayer()
                }
                
            }
        }
        
        if let videoButton = videoButton {
            
            videoButton.tintColor = fusumaBaseTintColor
            
            if videoButton.layer.sublayers?.count > 1 {
                
                for layer in videoButton.layer.sublayers! {
                    
                    if let borderColor = layer.borderColor , UIColor(cgColor: borderColor) == fusumaTintColor {
                        
                        layer.removeFromSuperlayer()
                    }
                    
                }
            }
        }
        
    }
    
    func highlightButton(_ button: UIButton) {
        
        button.tintColor = fusumaTintColor
        
        button.addBottomBorder(fusumaTintColor, width: 3)
    }
}

extension FusumaViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func accessPhotosLib() {
        
        let status = PHPhotoLibrary.authorizationStatus()
        
        if status == .authorized {
        } else {
            return
        }
        
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        
        var types = [String]()
        
        let forImage = kUTTypeImage as String
        let forVideo = kUTTypeVideo as String
        
        if markusAccessPhotosType == .image {
            types.append(forImage)
        } else if markusAccessPhotosType == .video {
            types.append(forVideo)
        } else {
            types.append(forImage)
            types.append(forVideo)
        }
        
        self.delegate?.fusumaWillPresentPhotosLib(self)
        
        self.shouldRepositionImageCropContainerOnViewDisapper = false
        
        imagePicker.mediaTypes = types
        self.present(imagePicker, animated: true, completion: nil)
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        self.shouldRepositionImageCropContainerOnViewDisapper = true
        
        if let assertURL = info[UIImagePickerControllerReferenceURL] as? URL {
            let fetchResult = PHAsset.fetchAssets(withALAssetURLs: [assertURL], options: nil)
            if let asset = fetchResult.firstObject {
                self.albumView.changeImage(asset)
                
                for indexPath in self.albumView.collectionView.indexPathsForSelectedItems ?? [] {
                    self.albumView.collectionView.deselectItem(at: indexPath, animated: false)
                }
            }
        }
        picker.dismiss(animated: true, completion: {
            self.delegate?.fusumaDidDismissPhotosLib(self)
        })
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.shouldRepositionImageCropContainerOnViewDisapper = true
        picker.dismiss(animated: true, completion: {
            self.delegate?.fusumaDidDismissPhotosLib(self)
        })
    }
}

public enum MarkusAccessPhotosType {
    case image, video, imageAndVideo
}
