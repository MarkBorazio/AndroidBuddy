//
//  EnableUSBDebuggingInstructionsView.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 12/5/2024.
//

import SwiftUI

struct EnableUSBDebuggingInstructionsView: View {
    
    private static let instructionsText: LocalizedStringKey = """
    In order have your device appear in the Android Buddy app, you must have USB debugging enabled and your device must be connected to your computer via USB.
    
    To enable USB debugging on your device, follow these steps:
      1. Open the Settings app.
      2. Scroll down and select "About phone".
      3. Find an entry labeled "Build Number". Depending on your device, this could be on the "About phone" screen, deeper in the "Software information" screen, or somewhere else.
      4. Once you find the "Build Number" entry, keep tapping it until you see a message appear at the bottom telling you that developer options are now available.
      5. Go back to the main Settings screen, scroll down to the bottom, and select "Developer Options".
      6. Scroll down until you see the "USB debugging" item and select it.
      7. You should see a dialog appear asking for confirmation to allow USB debugging. Select "OK".
    
    USB debugging should now be enabled and your device should appear in the Android Buddy app.
    If you are still having issues, you can try unplugging and plugging in the USB cable, restarting your Android device, and/or restarting Android Buddy.
    
    [Video Instructions](https://www.youtube.com/watch?v=Ucs34BkfPB0)
    """
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Can't find your device:")
                    .font(.largeTitle)
                
                Text(Self.instructionsText)
            }
            .padding(ViewConstants.commonSpacing)
        }
    }
}

#Preview {
    EnableUSBDebuggingInstructionsView()
        .previewLayout(.sizeThatFits)
}
