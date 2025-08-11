//
//  ScriboWidgetLiveActivity.swift
//  ScriboWidget
//
//  Created by Santiago Paredes on 10/06/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ScriboWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct ScriboWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScriboWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension ScriboWidgetAttributes {
    fileprivate static var preview: ScriboWidgetAttributes {
        ScriboWidgetAttributes(name: "World")
    }
}

extension ScriboWidgetAttributes.ContentState {
    fileprivate static var smiley: ScriboWidgetAttributes.ContentState {
        ScriboWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: ScriboWidgetAttributes.ContentState {
         ScriboWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: ScriboWidgetAttributes.preview) {
   ScriboWidgetLiveActivity()
} contentStates: {
    ScriboWidgetAttributes.ContentState.smiley
    ScriboWidgetAttributes.ContentState.starEyes
}
