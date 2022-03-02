//
//  ViewController.swift
//  ble_Camera
//
//  Created by Peter Rogers on 26/02/2022.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    
    var captureSession = AVCaptureSession()
    var backCamera: AVCaptureDevice?
    var frontCamera: AVCaptureDevice?
    var currentCamera: AVCaptureDevice?
    var photoOutput: AVCapturePhotoOutput?
    var orientation: AVCaptureVideoOrientation = .portrait
    let context = CIContext()
    var incomingData:Float?
    var sliderVal:Float = 0.0
    
   // @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var labelArduinoData: UILabel!
    @IBOutlet weak var stateLabel: UILabel!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var labelSlider: UILabel!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var filteredImage: UIImageView!
    var ble = BLEController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        stateLabel.isHidden = true
        labelSlider.isHidden = true
        slider.isHidden = true
        labelArduinoData.isHidden = true
        setupDevice()
        setupInputOutput()
        // Do any additional setup after loading the view.
        
        
    }
    
    override func viewDidLayoutSubviews() {
       /// orientation = AVCaptureVideoOrientation(rawValue: UIApplication.shared.statusBarOrientation.rawValue)!
    }
    
    func setupDevice() {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.unspecified)
        let devices = deviceDiscoverySession.devices
        
        for device in devices {
            if device.position == AVCaptureDevice.Position.back {
                backCamera = device
            }
            else if device.position == AVCaptureDevice.Position.front {
                frontCamera = device
            }
        }
        
        currentCamera = backCamera
    }
    
    func launchBLE(){
        print("launch ble")
        ble.connect()
        ble.connectionChanged = { [unowned self] value in
            let v = value as connectionStatus
            if(v == .disconnected){
                //self.quitCamera()
                stateLabel.isHidden = true
                labelSlider.isHidden = true
                slider.isHidden = true
                labelArduinoData.isHidden = true
                print("disconnected")
            }
            if(v == .connected){
                stateLabel.isHidden = false
                //labelSlider.isHidden = false
                //slider.isHidden = false
                labelArduinoData.isHidden = false
            }
            //self.stateManager(state: value)
            // stateView?.setStatus(con: v)
            
        }
        ble.arduinoData = {[unowned self] value in
            let v = value as Float
            //let out = map(Float(v), 80, 400, 0, 32.4)
            //let out = map(value: v, minRange: 80, maxRange: 400, minDomain: 0, maxDomain: 32)
           // print(out)
            labelArduinoData.text = "\(v)"
            self.incomingData = v
      
        }
    }
    
    func map(value:Int, minRange:Int, maxRange:Int, minDomain:Int, maxDomain:Int) -> Int {
        return minDomain + (maxDomain - minDomain) * (value - minRange) / (maxRange - minRange)
    }

    func map(value:Float, minRange:Float, maxRange:Float, minDomain:Float, maxDomain:Float) -> Float{
        return minDomain + (maxDomain - minDomain) * (value - minRange) / (maxRange - minRange)
    }

    
  
      
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            labelSlider.text = "\(slider.value)"
            if AVCaptureDevice.authorizationStatus(for: AVMediaType.video) != .authorized
            {
                AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler:
                { (authorized) in
                    DispatchQueue.main.async
                    {
                        if authorized
                        {
                            self.setupInputOutput()
                        }
                    }
                })
            }
        }
    
    func setupInputOutput() {
        do {
            setupCorrectFramerate(currentCamera: currentCamera!)
            let captureDeviceInput = try AVCaptureDeviceInput(device: currentCamera!)
            captureSession.sessionPreset = AVCaptureSession.Preset.hd1280x720
            if captureSession.canAddInput(captureDeviceInput) {
                captureSession.addInput(captureDeviceInput)
            }
            let videoOutput = AVCaptureVideoDataOutput()
            
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer delegate", attributes: []))
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }
            captureSession.startRunning()
        } catch {
            print(error)
        }
    }
    
    func setupCorrectFramerate(currentCamera: AVCaptureDevice) {
        for vFormat in currentCamera.formats {
            let ranges = vFormat.videoSupportedFrameRateRanges as [AVFrameRateRange]
            let frameRates = ranges[0]
            
            do {
                //set to 240fps - available types are: 30, 60, 120 and 240 and custom
                // lower framerates cause major stuttering
                if frameRates.maxFrameRate == 240 {
                    try currentCamera.lockForConfiguration()
                    currentCamera.activeFormat = vFormat as AVCaptureDevice.Format
                    //for custom framerate set min max activeVideoFrameDuration to whatever you like, e.g. 1 and 180
                    currentCamera.activeVideoMinFrameDuration = frameRates.minFrameDuration
                    currentCamera.activeVideoMaxFrameDuration = frameRates.maxFrameDuration
                }
            }
            catch {
                print("Could not set active format")
                print(error)
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        connection.videoOrientation = orientation
        
        
       // let comicEffect = CIFilter(name: "CIComicEffect")
       
                
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let cameraImage = CIImage(cvImageBuffer: pixelBuffer!)
       // let x = map
        let bloomIntensity = map(value:self.incomingData ?? 0 * 10, minRange: 0.0, maxRange: 100, minDomain: 0.0, maxDomain: 10)
        let x = map(value: self.incomingData ?? 0, minRange: 0.0, maxRange: 100, minDomain: 0.0, maxDomain: Float(cameraImage.extent.width))
        let v = CIVector(x: CGFloat(x), y: cameraImage.extent.height/2)
        let filter = CIFilter(name: "CIZoomBlur", parameters: ["inputImage": cameraImage,
                                                               "inputAmount": self.incomingData ?? 0 * 10,
                                                               "inputCenter":v])!
       // comicEffect!.setValue(cameraImage, forKey: kCIInputImageKey)
        let  bloom = CIFilter(name: "CIBloom", parameters: ["inputImage":filter.outputImage!,
                                                            "inputIntensity": bloomIntensity])
        
        
        let cgImage = self.context.createCGImage(bloom!.outputImage!, from: cameraImage.extent)!
        
        DispatchQueue.main.async {
            let filteredImage = UIImage(cgImage: cgImage)
            self.filteredImage.image = filteredImage
        }
    }
    
  
    
    //    @IBAction func didTakePhoto(_ sender: Any) {
    //
    //            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
    //            stillImageOutput.capturePhoto(with: settings, delegate: self)
    //        }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        guard let imageData = photo.fileDataRepresentation()
        else { return }
        
        let image = UIImage(data: imageData)
        //captureImageView.image = image
        UIImageWriteToSavedPhotosAlbum(image!, self, #selector(saveCompleted), nil)
    }
    
    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        print("Save finished!")
    }
    
    
    @IBAction func connectAction(_ sender: Any) {
        launchBLE()
        
    }
    
    
    @IBAction func sliderAction(_ sender: UISlider) {
        labelSlider.text = "\(Int(sender.value))"
        sliderVal = sender.value
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.captureSession.stopRunning()
    }
    
    
    
}

