//
//  ViewController.swift
//  GazeCalculatorTest
//
//  Created by David on 1/5/24.
//

import UIKit
import AVKit
import SeeSo
import GazeCalculator

class ViewController: UIViewController, InitializationDelegate, GazeDelegate {

  let textView : UITextView = UITextView()
  let btnStackView : UIStackView = UIStackView()
  let startBtn : UIButton = UIButton(type: .system)
  let endBtn : UIButton = UIButton()
  let licenseKey : String = "input your license key"

  var tracker : GazeTracker? = nil

  let pointView : UIView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 20, height: 20)))

  var isCalculated = false

  let gazeCalculator = SeeSoMetric.shared
  let filter = SeeSoFilter.shared

  let sentence : String = "그녀가 떠난 길목에서, 밤의 고요함이 나의 외로운 마음에 스며들었다. 별들이 총총한 밤하늘 아래, 시간은 잠시 멈춰 서 있었고, 그녀에 대한 그리움이 내 마음속에서 소리 없이 춤추었다. 깊은 밤, 나의 생각은 그녀와 함께했던 추억 속을 떠돌며, 그녀의 목소리가 내 귓가에 부드럽게 메아리쳤다."
  lazy var words : [String] = sentence.split(separator: " ").map(String.init)

  var gazeList: [GazeInfo] = []

  var wordAoiList: [WordAoi] = []

  override func viewDidLoad() {
    super.viewDidLoad()

    initViews()
    if checkAccessCamera() {
      initGazeTracker()
    } else {
      requestAccess()
    }
    // Do any additional setup after loading the view.
  }

  private func makeWordAoi() {
    for word in words {
      if let rect = rectForSubstring(word) {
        let convertRect = textView.convert(rect, to: self.view)
        //print("\(word) : \(convertRect.debugDescription)")
        wordAoiList.append(WordAoi(x: convertRect.minX, y:convertRect.minY, width: convertRect.width, height: convertRect.height, word: word))
      }
    }
  }

  private func rectForSubstring(_ substring: String) -> CGRect? {
    guard let textRange = textView.text.range(of: substring) else {
      return nil
    }

    let layoutManager = textView.layoutManager
    let characterRange = NSRange(textRange, in: textView.text)
    let glyphRange = layoutManager.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)

    return layoutManager.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer)
  }

  private func requestAccess(){
    AVCaptureDevice.requestAccess(for: AVMediaType.video) { response in
      if response {
        self.initGazeTracker()
      } else {
        //If you are denied access, you cannot use any function.
        DispatchQueue.main.async {
          self.textView.text = "카메라 권한을 얻지 못했습니다."
        }
      }
    }
  }

  private func initGazeTracker() {
    GazeTracker.initGazeTracker(license: licenseKey, delegate: self)
  }

  private func checkAccessCamera() -> Bool {
    return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
  }

  func initViews() {
    self.view.addSubview(textView)
    textView.translatesAutoresizingMaskIntoConstraints = false
    textView.backgroundColor = .white
    textView.textColor = .black
    textView.font = UIFont.preferredFont(forTextStyle: .body)
    textView.adjustsFontForContentSizeCategory = true
    textView.text = sentence


    self.view.addSubview(btnStackView)
    btnStackView.axis = .horizontal
    btnStackView.translatesAutoresizingMaskIntoConstraints = false
    btnStackView.alignment = .fill // 내부 뷰들의 정렬 방식
    btnStackView.distribution = .fillEqually // 내부 뷰들의 분포 방식
    btnStackView.spacing = 40 // 뷰 사이의 간격

    self.btnStackView.addArrangedSubview(startBtn)
    startBtn.setTitle("START", for: .normal)
    startBtn.setTitleColor(.black, for: .normal)
    startBtn.setTitleColor(.darkGray, for: .disabled)
    startBtn.backgroundColor = .systemGray3
    startBtn.frame.size.width = 120
    startBtn.frame.size.height = 50
    startBtn.isEnabled = false
    startBtn.addTarget(self, action: #selector(clickStart(sender:)), for: .touchUpInside)

    self.btnStackView.addArrangedSubview(endBtn)
    endBtn.setTitle("END", for: .normal)
    endBtn.setTitleColor(.black, for: .normal)
    endBtn.setTitleColor(.darkGray, for: .disabled)
    endBtn.backgroundColor = .systemGray3
    endBtn.frame.size.width = 120
    endBtn.frame.size.height = 50
    endBtn.isEnabled = false
    endBtn.addTarget(self, action: #selector(clickEnd(sender:)), for: .touchUpInside)

    self.view.addSubview(pointView)
    pointView.backgroundColor = .red
    pointView.layer.cornerRadius = 10
    pointView.isHidden = true

    NSLayoutConstraint.activate([
      textView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 60),
      textView.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 20),
      textView.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: -20),
      textView.heightAnchor.constraint(equalTo: self.view.heightAnchor, multiplier: 0.5),
      btnStackView.topAnchor.constraint(equalTo: self.textView.bottomAnchor, constant: 40),
      btnStackView.leftAnchor.constraint(equalTo: self.textView.leftAnchor),
      btnStackView.rightAnchor.constraint(equalTo: self.textView.rightAnchor),
      btnStackView.heightAnchor.constraint(equalToConstant: 50)
    ])
  }

  func onInitialized(tracker: GazeTracker?, error: InitializationError) {
    makeWordAoi()
    if tracker != nil {
      self.tracker = tracker
      tracker?.gazeDelegate = self
      DispatchQueue.main.async {
        self.startBtn.isEnabled = true
        self.pointView.isHidden = false
      }
      tracker?.startTracking()
    } else {
      DispatchQueue.main.async {
        self.textView.text = "인증 실패 : \(error.description)"
      }
    }
  }


  @objc func clickStart(sender : UIButton) {
    gazeList = []
    isCalculated = true
    DispatchQueue.main.async {
      self.endBtn.isEnabled = true
      self.startBtn.isEnabled = false
    }
  }

  @objc func clickEnd(sender : UIButton) {
    tracker?.stopTracking()
    isCalculated = false

    let filterList = filter.filter(gazeInfoList: gazeList)
    let metric = gazeCalculator.calculateMetric(fixationList: filterList.fixations, saccadeList: filterList.saccades, wordAoiList: wordAoiList)
    DispatchQueue.global(qos: .background).async {
      self.printFixations(fixations: filterList.fixations)
      self.printSaccades(saccades: filterList.saccades)
    }

    showResultDialog(withResult: "fixationMeanDuration: \(metric.fixationMeanDuration), readingSpeed: \(metric.readingSpeed), regressionRatio: \(metric.regressionRatio), saccadeLength: \(metric.saccadeLength)")

  }

  func showResultDialog(withResult result: String) {
    // 경고창 생성
    let alertController = UIAlertController(title: "결과", message: result, preferredStyle: .alert)

    // 확인 버튼 추가
    let confirmAction = UIAlertAction(title: "확인", style: .default, handler: {_ in
      DispatchQueue.main.async {
        self.endBtn.isEnabled = false
        self.startBtn.isEnabled = true
        self.tracker?.startTracking()
      }
    })
    alertController.addAction(confirmAction)

    // 경고창 표시
    present(alertController, animated: true, completion: nil)
  }

  func printFixations(fixations: [Fixation]) {
    for fixation in fixations {
      print("fixation: (\(fixation.x), \(fixation.y)), timestmap: \(fixation.timestamp) duration: \(fixation.duration) ")
    }
  }

  func printSaccades(saccades: [Saccade]) {
    for saccade in saccades {
      print("saccade: start(\(saccade.sx), \(saccade.sy)) end(\(saccade.ex), \(saccade.ey)), timestmap: \(saccade.timestamp) duration: \(saccade.duration) ")
    }
  }

  func onGaze(gazeInfo: GazeInfo) {
    if gazeInfo.trackingState == .SUCCESS {
      self.pointView.frame.origin.x = gazeInfo.x - 10
      self.pointView.frame.origin.y = gazeInfo.y - 10
    }

    if isCalculated {
      gazeList.append(gazeInfo)
    }
  }

}

