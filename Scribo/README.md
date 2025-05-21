# Scribo

Scribo is an AI-powered study assistant app that helps you organize and manage your notes effectively. Built with SwiftUI and Supabase, it provides a modern and intuitive interface for creating, organizing, and searching through your study materials.

## Features

- 📝 Create and organize notes with topics and subtopics
- 🖼️ Add images to your notes
- 📄 Attach documents to your notes
- 🔍 Search through your notes
- 🌙 Dark mode support
- 🔐 User authentication
- 💾 Cloud synchronization with Supabase

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+
- Supabase account

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/Scribo.git
```

2. Open the project in Xcode:
```bash
cd Scribo
open Scribo.xcodeproj
```

3. Configure Supabase:
   - Create a new project in Supabase
   - Update the Supabase URL and key in `SupabaseConfig.swift`
   - Set up the following tables in your Supabase database:
     - users
     - topics
     - subtopics
     - notes

4. Build and run the project in Xcode

## Project Structure

```
Scribo/
├── App/
│   └── MainApp.swift
├── Resources/
│   └── Fonts/
├── Modules/
│   ├── Home/
│   │   ├── Components/
│   │   └── HomeView.swift
│   └── Auth/
│       ├── Components/
│       ├── ViewModels/
│       └── LoginView.swift
├── Common/
│   ├── Extensions/
│   ├── Utilities/
│   └── Components/
├── Networking/
│   ├── APIService.swift
│   └── SupabaseConfig.swift
├── Models/
│   ├── Note.swift
│   ├── Topic.swift
│   └── User.swift
├── Persistence/
│   └── DataManager.swift
└── Tests/
    ├── MyAppTests/
    └── MyAppUITests/
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- [Supabase](https://supabase.io/)
- [SF Symbols](https://developer.apple.com/sf-symbols/) 