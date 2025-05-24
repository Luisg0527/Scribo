# Scribo

Scribo is an intelligent note-taking application that combines traditional note organization with AI-powered features to enhance your learning and productivity experience.

## Features

### 📝 Smart Note Organization
- Hierarchical organization with Topics and Subtopics
- Rich text editing with image attachments
- Automatic categorization of notes
- Search functionality across all notes

### 🤖 AI Integration
- AI-powered text classification
- Smart content organization
- Automatic topic and subtopic suggestions
- Document analysis and categorization

### 📱 Modern UI/UX
- Clean, intuitive interface
- Dark/Light mode support
- Responsive design
- Smooth animations and transitions

### 🔄 Real-time Features
- Live chat with AI assistant
- Document and image processing
- Instant note categorization
- Real-time search results

## Technical Features

- SwiftUI-based modern interface
- MVVM architecture
- Local data persistence
- Camera integration for document scanning
- Photo library integration
- File system management
- Real-time OCR capabilities

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+

## Configuration

### Environment Variables

1. Create a `.env` file in the project root with the following variables:
```env
# Text Classification Service
CLASSIFICATION_SERVER_URL=Placeholder
CLASSIFICATION_API_KEY=Placeholder

# Supabase Configuration
SUPABASE_URL=Placeholder
SUPABASE_ANON_KEY=Placeholder
```

2. Update the following files with your configuration:

#### TextClassificationService.swift
```swift
static let serverURL = ProcessInfo.processInfo.environment["CLASSIFICATION_SERVER_URL"] ?? "Placeholder"
static let apiKey = ProcessInfo.processInfo.environment["CLASSIFICATION_API_KEY"] ?? "Placeholder"
```

#### SupabaseConfig.swift
```swift
let supabaseURL = URL(string: ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "Placeholder")!
let supabaseKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? "Placeholder"
```

### Environment Setup

1. Add the following to your Xcode project's scheme:
   - Edit Scheme > Run > Arguments > Environment Variables
   - Add all variables from your `.env` file

2. For development, you can use the default values:
   - Classification Server URL: `Placeholder`
   - Classification API Key: `Placeholder`
   - Supabase URL: `Placeholder`
   - Supabase Anon Key: `Placeholder`

### Security Notes

- Never commit the `.env` file to version control
- Add `.env` to your `.gitignore` file
- Keep your API keys and secrets secure
- Use different keys for development and production environments

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

3. Create and configure your `.env` file as described above

4. Configure your environment variables in Xcode

5. Build and run the project in Xcode

## Usage

1. **Creating Notes**
   - Tap the "+" button to create a new note
   - Add text, images, or documents
   - The AI will automatically categorize your content

2. **Organizing Content**
   - Create topics and subtopics
   - Drag and drop notes between categories
   - Use the search function to find content quickly

3. **AI Assistant**
   - Access the chat interface
   - Ask questions about your notes
   - Get suggestions for content organization

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- SwiftUI for the modern UI framework
- Vision framework for OCR capabilities
- Core ML for AI integration
