import Foundation

struct ClassificationLabels {
    // MARK: - Main Topics
    static let mainTopics = [
        "Mathematics",
        "Science",
        "History",
        "Literature",
        "Technology",
        "Business",
        "Arts",
        "Language",
        "Philosophy",
        "Health",
        "Religion"
    ]
    
    // MARK: - Science Subtopics
    static let scienceSubtopics = [
        "Physics",
        "Chemistry",
        "Biology",
        "Astronomy",
        "Geology",
        "Computer Science"
    ]
    
    // MARK: - Mathematics Subtopics
    static let mathematicsSubtopics = [
        "Algebra",
        "Calculus",
        "Geometry",
        "Statistics",
        "Number Theory"
    ]
    
    // MARK: - History Subtopics
    static let historySubtopics = [
        "Ancient History",
        "Modern History",
        "World History",
        "Cultural History",
        "Political History"
    ]
    
    // MARK: - Literature Subtopics
    static let literatureSubtopics = [
        "Poetry",
        "Fiction",
        "Non-Fiction",
        "Drama",
        "Literary Analysis"
    ]
    
    // MARK: - Technology Subtopics
    static let technologySubtopics = [
        "Programming",
        "Artificial Intelligence",
        "Web Development",
        "Mobile Development",
        "Data Science"
    ]
    
    // MARK: - Business Subtopics
    static let businessSubtopics = [
        "Economics",
        "Marketing",
        "Finance",
        "Management",
        "Entrepreneurship"
    ]
    
    // MARK: - Arts Subtopics
    static let artsSubtopics = [
        "Visual Arts",
        "Music",
        "Dance",
        "Film",
        "Architecture"
    ]
    
    // MARK: - Language Subtopics
    static let languageSubtopics = [
        "Grammar",
        "Vocabulary",
        "Writing",
        "Speaking",
        "Translation"
    ]
    
    // MARK: - Philosophy Subtopics
    static let philosophySubtopics = [
        "Ethics",
        "Logic",
        "Metaphysics",
        "Epistemology",
        "Political Philosophy"
    ]
    
    // MARK: - Health Subtopics
    static let healthSubtopics = [
        "Medicine",
        "Nutrition",
        "Psychology",
        "Exercise",
        "Mental Health"
    ]
    
    // MARK: - Religion Subtopics
    static let religionSubtopics = [
        "Christianity",
        "Islam",
        "Judaism",
        "Buddhism",
        "Hinduism",
        "Taoism",
        "Religious History",
        "Religious Philosophy",
        "Religious Texts",
        "Religious Practices",
        "Comparative Religion",
        "Religious Ethics",
        "Religious Art",
        "Religious Music",
        "Religious Architecture"
    ]
    
    // MARK: - All Labels
    static var allLabels: [String] {
        return mainTopics +
            scienceSubtopics +
            mathematicsSubtopics +
            historySubtopics +
            literatureSubtopics +
            technologySubtopics +
            businessSubtopics +
            artsSubtopics +
            languageSubtopics +
            philosophySubtopics +
            healthSubtopics +
            religionSubtopics
    }
} 