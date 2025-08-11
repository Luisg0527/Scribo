//
//  ScriboWidgetBundle.swift
//  ScriboWidget
//
//  Created by Santiago Paredes on 10/06/25.
//

import WidgetKit
import SwiftUI

@main
struct ScriboWidgetBundle: WidgetBundle {
    var body: some Widget {
        ScriboWidget()
        ScriboWidgetControl()
        ScriboWidgetLiveActivity()
    }
}
