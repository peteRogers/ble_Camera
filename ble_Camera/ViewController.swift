//
//  ViewController.swift
//  ble_Camera
//
//  Created by Peter Rogers on 26/02/2022.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    
    @IBOutlet weak var previewView: UIView!
    var captureSession: AVCaptureSession!
    var stillImageOutput: AVCapturePhotoOutput!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    @IBOutlet weak var labelArduinoData: UILabel!
    @IBOutlet weak var stateLabel: UILabel!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var labelSlider: UILabel!
    @IBOutlet weak var slider: UISlider!
    var ble = BLEController()
    var picTaken = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        stateLabel.isHidden = true
        labelSlider.isHidden = true
        slider.isHidden = true
        labelArduinoData.isHidden = true
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        guard let backCamera = AVCaptureDevice.default(for: AVMediaType.video)
        else {
            print("Unable to access back camera!")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            stillImageOutput = AVCapturePhotoOutput()
            if captureSession.canAddInput(input) && captureSession.canAddOutput(stillImageOutput) {
                captureSession.addInput(input)
                captureSession.addOutput(stillImageOutput)
                setupLivePreview()
            }
        }
        catch let error  {
            print("Error Unable to initialize back camera:  \(error.localizedDescription)")
        }
        // Do any additional setup after loading the view.
        
        
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
                labelSlider.isHidden = false
                slider.isHidden = false
                labelArduinoData.isHidden = false
            }
            //self.stateManager(state: value)
            // stateView?.setStatus(con: v)
            
        }
        ble.arduinoData = {[unowned self] value in
            let v = value as Int
            //let out = map(Float(v), 80, 400, 0, 32.4)
            let out = map(value: v, minRange: 80, maxRange: 400, minDomain: 0, maxDomain: 32)
            print(out)
            labelArduinoData.text = "\(out)"
            if (out > Int(self.slider.value)){
                if(self.picTaken == false){
                    self.takePicture()
                    self.picTaken = true
                }
            }else{
                self.picTaken = false
            }
        }
    }
    
    func map(value:Int, minRange:Int, maxRange:Int, minDomain:Int, maxDomain:Int) -> Int {
        return minDomain + (maxDomain - minDomain) * (value - minRange) / (maxRange - minRange)
    }

    
    func setupLivePreview() {
        
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        videoPreviewLayer.videoGravity = .resizeAspect
        videoPreviewLayer.connection?.videoOrientation = .portrait
        previewView.layer.addSublayer(videoPreviewLayer)
        DispatchQueue.global(qos: .userInitiated).async { //[weak self] in
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.videoPreviewLayer.frame = self.previewView.bounds
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        labelSlider.text = "\(slider.value)"
    }
    
    func takePicture(){
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        print("photo taken")
        stillImageOutput.capturePhoto(with: settings, delegate: self)
        
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
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.captureSession.stopRunning()
    }
    
    
    
}

