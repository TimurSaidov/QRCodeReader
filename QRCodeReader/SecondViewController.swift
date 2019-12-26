//
//  SecondViewController.swift
//  QRCodeReader
//
//  Created by Timur Saidov on 25/12/2019.
//  Copyright © 2019 Timur Saidov. All rights reserved.
//

import UIKit
import AVFoundation

class SecondViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    
    // MARK: Outlets

    @IBOutlet weak var torchButton: UIButton!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var readingAreaView: UIView!
    
    
    // MARK: Actions
    
    @IBAction func torchButtonTapped(_ sender: UIButton) {
        if captureDevice.hasTorch {
            do {
                try captureDevice.lockForConfiguration()
                captureDevice.torchMode = captureDevice.torchMode == .on ? .off : .on
                sender.backgroundColor = captureDevice.torchMode == .on ? .orange : .white
                captureDevice.unlockForConfiguration()
            } catch let error {
                fatalError(error.localizedDescription)
            }
        }
    }
    
    @IBAction func closeButtonTapped(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
    
    
    // MARK: Public Properties
    
    var video: AVCaptureVideoPreviewLayer!
    var session: AVCaptureSession!
    var captureDevice: AVCaptureDevice!
    var coverLayer: CAShapeLayer!
    
    
    // MARK: Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupVideo()
        startVideo()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let coverPath = UIBezierPath(rect: view.frame)
        let readingAreaPath = UIBezierPath(roundedRect: readingAreaView.frame,
                                           cornerRadius: 4)
        coverPath.append(readingAreaPath)
        coverPath.usesEvenOddFillRule = true
        coverLayer.path = coverPath.cgPath
        
//        print(#function, readingAreaView.frame, readingAreaView.bounds) // Начальная точка равна той, которая на работающем девайсе.
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    
    // MARK: Private
    
    private func setupVideo() {
        // 1. Настройка сессии.
        session = AVCaptureSession()
        // 2. Настройка устройства, чтобы записывать видео.
        captureDevice = AVCaptureDevice.default(for: .video)
        // 3. Настройка input'а - Сессия в качестве входного параметра получает то, что возвращается от устройства (то есть видео, картинку видео).
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            session.addInput(input)
        } catch let error {
            fatalError(error.localizedDescription)
        }
        // 4. Настройка output'a.
        let output =  AVCaptureMetadataOutput()
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
        // 5. Настройка видео - то, что приходит от устройства (картинка видео) записывается в сессию и получается видео.
        video = AVCaptureVideoPreviewLayer(session: session)
        video.frame = view.layer.bounds
    }
    
    private func startVideo() {
        video.videoGravity = .resizeAspectFill
        view.layer.addSublayer(video)
        view.bringSubviewToFront(torchButton)
        view.bringSubviewToFront(closeButton)
        view.bringSubviewToFront(readingAreaView)
        session.startRunning()
        
        view.backgroundColor = .black
        readingAreaView.backgroundColor = .clear
        
        coverLayer = CAShapeLayer()
        coverLayer.fillRule = CAShapeLayerFillRule.evenOdd
        coverLayer.fillColor = view.backgroundColor?.cgColor
        coverLayer.opacity = 0.5
        view.layer.addSublayer(coverLayer) // Прозрачный слой поверх картинки видео.
        
//        print(#function, readingAreaView.frame, readingAreaView.bounds) // Начальная точка readingAreaView равна той, что на xib (Storyboard).
    }
    
    
    // MARK: - AVCaptureMetadataOutputObjectsDelegate
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard metadataObjects.count > 0 else { return }
        if let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject {
            if object.type == AVMetadataObject.ObjectType.qr {
                let barcodeFrame = video.layerRectConverted(fromMetadataOutputRect: object.bounds)
                if readingAreaView.frame.contains(barcodeFrame) {
                    let alert = UIAlertController(title: "QR Code", message: object.stringValue, preferredStyle: .alert)
                    let go = UIAlertAction(title: "Перейти", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        if let string = object.stringValue, let url = URL(string: string), UIApplication.shared.canOpenURL(url) {
                            if #available(iOS 10.0, *) {
                                UIApplication.shared.open(url)
                            } else {
                                UIApplication.shared.openURL(url)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: { [weak self] in
                                self?.dismiss(animated: true, completion: nil)
                            })
                        } else {
                            let alert = UIAlertController(title: "Не удается открыть страницу", message: "Эта страница не может быть отображена, так как ссылка, считанная по QR, не является валидной", preferredStyle: .alert)
                            let ok = UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                                self?.startVideo()
                            }
                            alert.addAction(ok)
                            self.present(alert, animated: true, completion: nil)
                        }
                        print(object.stringValue ?? "")
                    }
                    let copy = UIAlertAction(title: "Копировать", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UIPasteboard.general.string = object.stringValue
                        self.dismiss(animated: true, completion: nil)
                        print(object.stringValue ?? "")
                    }
                    alert.addAction(go)
                    alert.addAction(copy)
                    present(alert, animated: true, completion: nil)
                    session?.stopRunning()
                    AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                }
            }
        }
    }
}
