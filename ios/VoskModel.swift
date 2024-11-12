//
//  Vosk.swift
//  VoskApiTest
//
//  Created by Niсkolay Shmyrev on 01.03.20.
//  Copyright © 2020-2021 Alpha Cephei. All rights reserved.
//

import Foundation

public final class VoskModel {

    var model : OpaquePointer!
    var spkModel : OpaquePointer!

    init(name: String) throws {

        // Set to -1 to disable logs
        vosk_set_log_level(0);

        let appBundle = Bundle(for: Self.self)

        let name = name.replacingOccurrences(of: "file://", with: "")
        if let loadedModel = vosk_model_new(name) {
            print("Model successfully loaded from path.")
            model = loadedModel
        } else {
            print("Model directory does not exist at path: \(name). Attempt to load model from main app bundle.")
            // Load model from main app bundle
            if let resourcePath = Bundle.main.resourcePath {
                let modelPath = resourcePath + "/" + name
                model = vosk_model_new(modelPath)
            }
        }

        // Get the URL to the spk model inside this pod
        if let spkModelPath = appBundle.path(forResource: "vosk-model-spk-0.4", ofType: nil) {
            spkModel = vosk_spk_model_new(spkModelPath)
        }
    }

    deinit {
        vosk_model_free(model)
        vosk_spk_model_free(spkModel)
    }

}
