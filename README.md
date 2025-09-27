# Names Manager

Native SwiftUI iOS app for managing curated name lists. Import names from CSV/XLSX, clean duplicates, edit metadata, and export updated lists while working fully offline.

## Requirements

- Xcode 15+
- iOS 16+
- SwiftUI + Swift Concurrency
- Core Data storage
- CoreXLSX + SwiftCSV dependencies (add via Swift Package Manager)

## Project structure

```
NamesManager.xcodeproj     // Xcode project configured for iOS 16+
NamesManager/
 ├─ App/                   // App entry point and main tab layout
 ├─ Models/                // Core Data managed object and domain models
 ├─ Services/              // Import/export utilities
 ├─ ViewModels/            // Observable stores for lists and import flow
 ├─ Views/                 // SwiftUI views for tabs and editing
 └─ Resources/             // Assets, Info.plist, preview content
```

## Features

- File importer supporting CSV and Excel via `UIDocumentPicker`
- Column + sheet selection with preview before committing
- Full CRUD list with search, first-letter filter, transliteration, and quick fixes
- Deduplication review + merge workflow
- Offline Core Data persistence
- Export to CSV/XLSX with share sheet integration

## Setup

1. Open `NamesManager.xcodeproj` in Xcode.
2. Add Swift Package Manager dependencies:
   - `https://github.com/CoreOffice/CoreXLSX.git`
   - `https://github.com/swiftcsv/SwiftCSV.git`
3. Build and run on an iOS 16+ device or simulator.

